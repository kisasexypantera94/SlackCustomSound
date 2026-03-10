import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct SlackCustomSoundApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Slack Custom Sound", systemImage: "bell.badge") {
            MenuContentView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
