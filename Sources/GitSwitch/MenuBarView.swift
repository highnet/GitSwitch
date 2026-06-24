import SwiftUI
import AppKit

/// The dropdown shown when clicking the menu bar (tray) icon.
struct MenuBarView: View {
    @ObservedObject var store: AccountStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(verbatim: "\(store.accounts.count) account\(store.accounts.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button(action: { store.refresh() }) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if store.ghMissing {
                Text("GitHub CLI not found")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else if store.accounts.isEmpty {
                Text("No accounts")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.accounts) { account in
                            MenuRow(account: account, busy: store.busy) {
                                store.switchTo(account)
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
            }

            Divider()

            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open GitSwitch", systemImage: "macwindow")
            }
            .buttonStyle(MenuItemStyle())

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(MenuItemStyle())
        }
        .frame(width: 280)
    }
}

private struct MenuRow: View {
    let account: GitAccount
    let busy: Bool
    let onSwitch: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: { if !account.isActive { onSwitch() } }) {
            HStack(spacing: 8) {
                Image(systemName: account.isActive ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11))
                    .foregroundStyle(account.isActive ? Theme.accent : Color.secondary)
                VStack(alignment: .leading, spacing: 0) {
                    Text(account.login)
                        .font(.system(size: 12, weight: account.isActive ? .semibold : .regular))
                    Text(account.host)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if account.isActive {
                    Text("active")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(hovering && !account.isActive ? Color.accentColor.opacity(0.18) : .clear)
        }
        .buttonStyle(.plain)
        .disabled(busy || account.isActive)
        .onHover { hovering = $0 }
    }
}

private struct MenuItemStyle: ButtonStyle {
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(hovering ? Color.accentColor.opacity(0.18) : .clear)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
    }
}
