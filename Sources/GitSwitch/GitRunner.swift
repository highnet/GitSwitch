import Foundation

/// The result of running a CLI process.
struct RunResult: Sendable {
    let status: Int32
    let stdout: String
    let stderr: String
    var ok: Bool { status == 0 }
    /// stderr if present, else stdout, trimmed, for surfacing errors.
    var message: String {
        let e = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return e.isEmpty ? stdout.trimmingCharacters(in: .whitespacesAndNewlines) : e
    }
}

/// The git commit identity stored in the global git config.
struct CommitIdentity: Sendable, Equatable {
    var name: String?
    var email: String?
    var isEmpty: Bool { (name?.isEmpty ?? true) && (email?.isEmpty ?? true) }
}

/// Shells out to `gh` and `git`. All members are nonisolated and synchronous,
/// so callers run them off the main actor via `Task.detached`.
enum GitRunner {

    /// Whether the GitHub CLI could be located on this machine.
    static var ghAvailable: Bool { locate("gh") != nil }

    // MARK: - High-level operations

    /// Parses `gh auth status` into the list of authenticated accounts.
    static func accounts() -> [GitAccount] {
        guard locate("gh") != nil else { return [] }
        // `gh auth status` historically wrote to stderr; newer versions use
        // stdout. Parse both so we work regardless of version.
        let r = run("gh", ["auth", "status"])
        return parse(r.stdout + "\n" + r.stderr)
    }

    /// Reads the global git commit identity (`user.name` / `user.email`).
    static func commitIdentity() -> CommitIdentity {
        guard locate("git") != nil else { return CommitIdentity() }
        let name = run("git", ["config", "--global", "user.name"]).stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let email = run("git", ["config", "--global", "user.email"]).stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return CommitIdentity(name: name.isEmpty ? nil : name,
                              email: email.isEmpty ? nil : email)
    }

    /// Makes `account` the active `gh` account. Returns the raw run result.
    @discardableResult
    static func switchTo(_ account: GitAccount) -> RunResult {
        run("gh", ["auth", "switch", "--hostname", account.host, "--user", account.login])
    }

    /// Fetches the active account's preferred commit identity from the GitHub
    /// API (falling back to the privacy `noreply` address) and writes it into
    /// the global git config. Returns the identity that was set, or nil on error.
    @discardableResult
    static func syncCommitIdentityToActive() -> CommitIdentity? {
        guard locate("gh") != nil, locate("git") != nil else { return nil }

        let nameR = run("gh", ["api", "user", "--jq", ".name // .login"])
        guard nameR.ok else { return nil }
        let name = nameR.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        var email = run("gh", ["api", "user", "--jq", ".email // \"\""]).stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if email.isEmpty || email == "null" {
            // GitHub privacy address: <id>+<login>@users.noreply.github.com
            email = run("gh", ["api", "user", "--jq",
                               "\"\\(.id)+\\(.login)@users.noreply.github.com\""])
                .stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !name.isEmpty, !email.isEmpty else { return nil }

        let n = run("git", ["config", "--global", "user.name", name])
        let e = run("git", ["config", "--global", "user.email", email])
        guard n.ok, e.ok else { return nil }
        return CommitIdentity(name: name, email: email)
    }

    // MARK: - Parsing

    /// Parses `gh auth status` output. Each account block looks like:
    ///
    ///   github.com
    ///     ✓ Logged in to github.com account highnet (keyring)
    ///       - Active account: true
    ///       - Git operations protocol: https
    ///       - Token scopes: 'gist', 'repo', 'workflow'
    static func parse(_ text: String) -> [GitAccount] {
        var accounts: [GitAccount] = []

        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)

            if let g = firstMatch(#"Logged in to (\S+) account (\S+)"#, in: line) {
                let host = g[1]
                let login = g[2].trimmingCharacters(in: CharacterSet(charactersIn: "()"))
                // Skip a duplicate (gh can list the same account twice).
                if !accounts.contains(where: { $0.host == host && $0.login == login }) {
                    accounts.append(GitAccount(host: host, login: login, isActive: false,
                                               gitProtocol: "", scopes: []))
                }
            } else if let g = firstMatch(#"Active account:\s*(true|false)"#, in: line),
                      !accounts.isEmpty {
                accounts[accounts.count - 1].isActive = (g[1] == "true")
            } else if let g = firstMatch(#"Git operations protocol:\s*(\S+)"#, in: line),
                      !accounts.isEmpty {
                accounts[accounts.count - 1].gitProtocol = g[1]
            } else if let g = firstMatch(#"Token scopes:\s*(.+)"#, in: line),
                      !accounts.isEmpty {
                accounts[accounts.count - 1].scopes = g[1]
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " '\"")) }
                    .filter { !$0.isEmpty }
            }
        }

        // Stable order independent of which account is active, so switching
        // the active account never reorders the list (the row stays in place).
        return accounts.sorted {
            $0.host != $1.host ? $0.host < $1.host : $0.login.lowercased() < $1.login.lowercased()
        }
    }

    /// Returns the capture groups (group 0 = whole match) of the first match,
    /// or nil if the pattern doesn't match.
    private static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = re.firstMatch(in: text, range: range) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            guard let r = Range(m.range(at: i), in: text) else { return "" }
            return String(text[r])
        }
    }

    // MARK: - Process helpers

    private static let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]

    /// Resolves a CLI tool to an absolute path. A GUI app launched from Finder
    /// has a minimal PATH, so we probe known locations first, then fall back to
    /// a login shell's `command -v`.
    private static func locate(_ tool: String) -> String? {
        if let cached = pathCache[tool] { return cached.isEmpty ? nil : cached }
        let found = resolve(tool)
        pathCache[tool] = found ?? ""
        return found
    }

    nonisolated(unsafe) private static var pathCache: [String: String] = [:]

    private static func resolve(_ tool: String) -> String? {
        let fm = FileManager.default
        for dir in extraPaths {
            let candidate = "\(dir)/\(tool)"
            if fm.isExecutableFile(atPath: candidate) { return candidate }
        }
        // Fall back to a login shell so we pick up the user's real PATH.
        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: "/bin/zsh")
        probe.arguments = ["-lc", "command -v \(tool)"]
        let pipe = Pipe()
        probe.standardOutput = pipe
        probe.standardError = FileHandle.nullDevice
        do { try probe.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        probe.waitUntilExit()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return fm.isExecutableFile(atPath: path) ? path : nil
    }

    private static func run(_ tool: String, _ args: [String]) -> RunResult {
        guard let path = locate(tool) else {
            return RunResult(status: 127, stdout: "", stderr: "\(tool) not found")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args

        // Augment PATH so the tool can find its own helpers (gh shells to git).
        var env = ProcessInfo.processInfo.environment
        let path0 = env["PATH"] ?? ""
        env["PATH"] = (extraPaths + [path0]).joined(separator: ":")
        process.environment = env

        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do { try process.run() } catch {
            return RunResult(status: 126, stdout: "", stderr: error.localizedDescription)
        }
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return RunResult(
            status: process.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? ""
        )
    }
}
