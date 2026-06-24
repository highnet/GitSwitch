import Foundation

/// One authenticated GitHub account, as reported by `gh auth status`.
struct GitAccount: Identifiable, Hashable, Sendable {
    let host: String           // e.g. "github.com"
    let login: String          // e.g. "highnet"
    var isActive: Bool         // the account `gh` currently operates as
    var gitProtocol: String    // "https" or "ssh"
    var scopes: [String]       // token scopes, e.g. ["repo", "workflow"]

    /// Stable identity: a login is unique per host.
    var id: String { "\(host)/\(login)" }
}
