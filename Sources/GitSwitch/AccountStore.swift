import Foundation
import SwiftUI

/// Observable model that polls `gh` for authenticated accounts and drives
/// switching plus commit-identity sync.
@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [GitAccount] = []
    @Published private(set) var identity = CommitIdentity()
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var ghMissing = false
    @Published private(set) var busy = false
    @Published var status: String?
    @Published var search: String = ""
    /// nil = the "All" tab; otherwise a host to narrow to.
    @Published var selectedHost: String? = nil

    /// Seconds between automatic refreshes.
    let interval: TimeInterval = 5

    private var timer: Timer?
    // Tracks the active login across refreshes so we re-match the commit
    // identity whenever the active account changes (and once at launch).
    private var lastActiveLogin: String?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    var activeLogin: String? { accounts.first(where: \.isActive)?.login }

    var filtered: [GitAccount] {
        var result = accounts
        if let host = selectedHost {
            result = result.filter { $0.host == host }
        }
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            result = result.filter {
                $0.login.lowercased().contains(query)
                    || $0.host.lowercased().contains(query)
                    || $0.scopes.joined(separator: " ").lowercased().contains(query)
            }
        }
        return result
    }

    /// Distinct hosts with their account counts, for the tab strip.
    var hostGroups: [(name: String, count: Int)] {
        Dictionary(grouping: accounts, by: \.host)
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
    }

    func refresh() {
        Task.detached(priority: .userInitiated) {
            let available = GitRunner.ghAvailable
            let scanned = GitRunner.accounts()
            let id = GitRunner.commitIdentity()
            await MainActor.run {
                self.ghMissing = !available
                self.accounts = scanned
                self.identity = id
                self.lastUpdated = Date()
                if let host = self.selectedHost,
                   !scanned.contains(where: { $0.host == host }) {
                    self.selectedHost = nil
                }

                // Always keep the commit identity matched to the active account:
                // sync once at launch and again whenever the active login changes.
                let newActive = scanned.first(where: \.isActive)?.login
                let changed = newActive != self.lastActiveLogin
                self.lastActiveLogin = newActive
                if changed, newActive != nil {
                    self.matchIdentityToActive()
                }
            }
        }
    }

    /// Make `account` the active gh account, then refresh.
    func switchTo(_ account: GitAccount) {
        guard !account.isActive, !busy else { return }
        busy = true
        status = nil
        Task.detached(priority: .userInitiated) {
            let result = GitRunner.switchTo(account)
            await MainActor.run {
                self.busy = false
                self.status = result.ok ? "Now using \(account.login)" : result.message
                self.refresh()
            }
        }
    }

    /// Reads the active account's commit identity from the GitHub API and writes
    /// it into the global git config, so commits are authored as the active
    /// account. Runs automatically at launch and on every account change.
    private func matchIdentityToActive() {
        Task.detached(priority: .userInitiated) {
            let set = GitRunner.syncCommitIdentityToActive()
            await MainActor.run {
                if let set {
                    self.identity = set
                    self.status = "Commit identity now \(set.email ?? "?")"
                } else {
                    self.status = "Could not read identity from the active account"
                }
            }
        }
    }
}
