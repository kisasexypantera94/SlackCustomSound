import Foundation
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published var accessibilityTrusted: Bool = PermissionManager.isAccessibilityTrusted()
    @Published var launchAtLoginEnabled: Bool = false
    @Published var launchAtLoginStatusText: String = "Unknown"

    let settings = SettingsStore()
    let soundPlayer = SoundPlayer()
    let bannerMonitor = BannerMonitor()

    private var accessibilityPollTimer: Timer?

    init() {
        bannerMonitor.onSlackNotification = { [weak self] in
            guard let self else { return }
            guard let soundURL = self.settings.soundURL else { return }
            self.soundPlayer.play(url: soundURL)
        }

        refreshLaunchAtLoginStatus()
        applyMonitoringState()
    }

    func refreshPermissionState() {
        accessibilityTrusted = PermissionManager.isAccessibilityTrusted()
        applyMonitoringState()
    }

    func requestAccessibilityAccess() {
        PermissionManager.requestAccessibilityPrompt()
        startAccessibilityPolling()
    }

    private func startAccessibilityPolling() {
        accessibilityPollTimer?.invalidate()

        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { return }

            let trusted = PermissionManager.isAccessibilityTrusted()
            self.accessibilityTrusted = trusted

            if trusted {
                timer.invalidate()
                self.accessibilityPollTimer = nil
                self.applyMonitoringState()
            }

            self.objectWillChange.send()
        }
    }

    func chooseSoundFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.prompt = "Choose Sound"

        if panel.runModal() == .OK, let url = panel.url {
            settings.setSoundURL(url)
            objectWillChange.send()
            playTestSound()
            applyMonitoringState()
        }
    }

    func playTestSound() {
        guard let soundURL = settings.soundURL else { return }
        soundPlayer.play(url: soundURL)
    }

    func setMonitoringEnabled(_ enabled: Bool) {
        settings.isMonitoringEnabled = enabled
        applyMonitoringState()
    }

    func applyMonitoringState() {
        let shouldRun = settings.isMonitoringEnabled && accessibilityTrusted && settings.soundURL != nil

        if shouldRun {
            bannerMonitor.start()
        } else {
            bannerMonitor.stop()
        }

        objectWillChange.send()
    }

    func refreshLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            let status = service.status

            launchAtLoginEnabled = (status == .enabled)
            launchAtLoginStatusText = statusText(status)
        } else {
            launchAtLoginEnabled = false
            launchAtLoginStatusText = "Requires macOS 13+"
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }

        let service = SMAppService.mainApp

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            print("Launch at login update failed: \(error)")
            fflush(stdout)
        }

        refreshLaunchAtLoginStatus()
    }

    var monitorStatusText: String {
        if !settings.isMonitoringEnabled {
            return "Monitoring is disabled"
        }
        if !accessibilityTrusted {
            return "Accessibility permission is required"
        }
        if settings.soundURL == nil {
            return "Choose a sound file to start monitoring"
        }
        return "Monitoring Slack notifications"
    }

    var soundStatusText: String {
        if settings.soundURL == nil {
            return "No sound selected"
        }
        return "Sound selected"
    }

    private func statusText(_ status: SMAppService.Status) -> String {
        switch status {
        case .notRegistered:
            return "Disabled"
        case .enabled:
            return "Enabled"
        case .requiresApproval:
            return "Requires approval in Login Items"
        case .notFound:
            return "Not found"
        @unknown default:
            return "Unknown"
        }
    }
}
