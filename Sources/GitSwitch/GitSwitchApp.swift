import SwiftUI
import AppKit

@main
struct GitSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = AccountStore()

    var body: some Scene {
        // `Window` (not `WindowGroup`) is a single-instance scene: reopening
        // just focuses the existing window instead of spawning another.
        Window("GitSwitch", id: "main") {
            ContentView()
                .environmentObject(store)
        }
        .defaultSize(width: 420, height: 460)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {} // no "New Window"
        }

        MenuBarExtra {
            MenuBarView(store: store)
        } label: {
            // Tray: a swap glyph plus the active account login.
            Image(systemName: "arrow.left.arrow.right.circle")
            if let login = store.activeLogin {
                Text(login)
            }
        }
        .menuBarExtraStyle(.window)
    }
}

/// Keeps the app a normal foreground app and quits when the window closes.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in the menu bar even after the window closes.
        false
    }

    // Clicking the dock icon (or reopening) focuses the existing window
    // rather than creating a new one.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if let window = sender.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
        sender.activate(ignoringOtherApps: true)
        return true
    }
}
