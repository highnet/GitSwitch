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

    /// When on, the global git commit identity is updated to match the active
    /// account whenever the active account changes (in-app or externally).
    @Published var autoMatchIdentity: Bool = UserDefaults.standard.object(forKey: "autoMatchIdentity") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoMatchIdentity, forKey: "autoMatchIdentity") }
    }

    /// Seconds between automatic refreshes.
    let interval: TimeInterval = 5

    private var timer: Timer?
    // Tracks the active login across refreshes so we can detect a change and
    // auto-match the commit identity. `hasBaseline` avoids firing on first load.
    private var lastActiveLogin: String?
    private var hasBaseline = false

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

                // Detect an active-account change and auto-match the identity.
                let newActive = scanned.first(where: \.isActive)?.login
                let changed = self.hasBaseline && newActive != self.lastActiveLogin
                self.lastActiveLogin = newActive
                self.hasBaseline = true
                if changed, self.autoMatchIdentity, newActive != nil {
                    self.matchIdentityToActive(announce: true)
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

    /// Manually set the global git commit identity to match the active account.
    func syncCommitIdentity() {
        matchIdentityToActive(announce: true)
    }

    /// Reads the active account's commit identity from the GitHub API and writes
    /// it into the global git config. Used by both the manual button and the
    /// automatic match-on-switch.
    private func matchIdentityToActive(announce: Bool) {
        Task.detached(priority: .userInitiated) {
            let set = GitRunner.syncCommitIdentityToActive()
            await MainActor.run {
                if let set {
                    self.identity = set
                    if announce { self.status = "Commit identity now \(set.email ?? "?")" }
                } else if announce {
                    self.status = "Could not read identity from the active account"
                }
            }
        }
    }
}
