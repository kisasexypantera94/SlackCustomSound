import SwiftUI
import AppKit

final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(appState: AppState) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView()
            .environmentObject(appState)

        let hostingController = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Slack Custom Sound"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.isReleasedWhenClosed = false

        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
