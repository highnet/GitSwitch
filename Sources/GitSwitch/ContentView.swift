import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var store: AccountStore

    private var buildVersion: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "dev"
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                if store.hostGroups.count > 1 { tabBar }
                Divider().overlay(Theme.stroke)
                list
                footer
            }
        }
        .frame(minWidth: 380, minHeight: 360)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle().fill(Theme.accentDim).frame(width: 24, height: 24)
                Image(systemName: "arrow.left.arrow.right.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("GitSwitch").font(.system(size: 13, weight: .semibold))
                Text(verbatim: "\(store.accounts.count) account\(store.accounts.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            searchField

            Button(action: { store.refresh() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(IconButtonStyle())
            .help("Refresh now")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Tab strip (only shown when more than one host)

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                TabPill(label: "All", count: store.accounts.count,
                        selected: store.selectedHost == nil) { store.selectedHost = nil }
                ForEach(store.hostGroups, id: \.name) { group in
                    TabPill(label: group.name, count: group.count,
                            selected: store.selectedHost == group.name) {
                        store.selectedHost = group.name
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
        .frame(height: 30)
        .padding(.bottom, 3)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("Filter", text: $store.search)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .frame(width: 90)
            if !store.search.isEmpty {
                Button(action: { store.search = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Theme.rowFill, in: Capsule())
        .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                if store.ghMissing {
                    ghMissingState
                } else if store.filtered.isEmpty {
                    emptyState
                } else {
                    ForEach(store.filtered) { account in
                        AccountRow(account: account, busy: store.busy) {
                            store.switchTo(account)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: store.search.isEmpty ? "person.crop.circle.badge.questionmark" : "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(store.search.isEmpty ? "No GitHub accounts" : "No matches")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            if store.search.isEmpty {
                Text("Run `gh auth login` to add one")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
    }

    private var ghMissingState: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(Theme.accent)
            Text("GitHub CLI not found")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("Install it with `brew install gh`")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            if let status = store.status {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle").font(.system(size: 10))
                    Text(status).font(.system(size: 10)).lineLimit(1)
                    Spacer()
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Theme.accentDim)
            }

            HStack(spacing: 6) {
                Image(systemName: "signature").font(.system(size: 10))
                    .foregroundStyle(.secondary)
                if store.identity.isEmpty {
                    Text("no global commit identity")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                } else {
                    Text(verbatim: "\(store.identity.name ?? "?") <\(store.identity.email ?? "?")>")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Toggle("Auto", isOn: $store.autoMatchIdentity)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.system(size: 10))
                    .fixedSize()
                    .help("Automatically match the commit identity to the active account whenever it changes")
                Button(action: { store.syncCommitIdentity() }) {
                    Text("Match now")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(PillButtonStyle(tint: Theme.accent))
                .disabled(store.busy || store.activeLogin == nil)
                .help("Set the global git user.name/user.email from the active account now")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider().overlay(Theme.stroke)

            HStack(spacing: 5) {
                Circle().fill(Theme.accent).frame(width: 5, height: 5)
                Text("Live").font(.system(size: 10)).foregroundStyle(.secondary)
                Text(verbatim: "build \(buildVersion)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                if let updated = store.lastUpdated {
                    Text("Updated \(updated.formatted(date: .omitted, time: .standard))")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.black.opacity(0.2))
        }
    }
}

// MARK: - Row

private struct AccountRow: View {
    let account: GitAccount
    let busy: Bool
    let onSwitch: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 9) {
            // Login glyph chip
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Theme.tint(for: account.login).opacity(0.18))
                Text(initials)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.tint(for: account.login))
            }
            .frame(width: 28, height: 28)

            // Login + host/protocol
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(account.login)
                        .font(.system(size: 13, weight: .semibold))
                    if account.isActive {
                        Circle().fill(Theme.accent).frame(width: 5, height: 5)
                            .help("Active account")
                    }
                }
                Text(metaLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if account.isActive {
                Text("active")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.accentDim, in: Capsule())
                    .overlay(Capsule().stroke(Theme.accent.opacity(0.4), lineWidth: 1))
            } else if hovering {
                Button(action: onSwitch) {
                    Label("Switch", systemImage: "arrow.left.arrow.right")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(PillButtonStyle(tint: Theme.accent))
                .disabled(busy)
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(account.isActive ? Theme.accentDim : (hovering ? Theme.rowHover : Theme.rowFill),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(account.isActive ? Theme.accent.opacity(0.4) : Theme.stroke, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { if !account.isActive { onSwitch() } }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }

    private var initials: String {
        String(account.login.prefix(2)).uppercased()
    }

    private var metaLabel: String {
        var parts = [account.host]
        if !account.gitProtocol.isEmpty { parts.append(account.gitProtocol) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Tab pill

private struct TabPill: View {
    let label: String
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 11, weight: selected ? .semibold : .regular))
                Text(verbatim: "\(count)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(selected ? Theme.accent : .secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        (selected ? Theme.accent.opacity(0.18) : Color.white.opacity(0.08)),
                        in: Capsule()
                    )
            }
            .foregroundStyle(selected ? .primary : .secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(selected ? Theme.accentDim : Theme.rowFill, in: Capsule())
            .overlay(
                Capsule().stroke(selected ? Theme.accent.opacity(0.5) : Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}

// MARK: - Button styles

private struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .frame(width: 28, height: 28)
            .background(configuration.isPressed ? Theme.rowHover : Theme.rowFill,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
    }
}

private struct PillButtonStyle: ButtonStyle {
    let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(configuration.isPressed ? 0.28 : 0.16), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.4), lineWidth: 1))
    }
}
