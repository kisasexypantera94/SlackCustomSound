import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Enable monitoring", isOn: Binding(
                get: { appState.settings.isMonitoringEnabled },
                set: { appState.setMonitoringEnabled($0) }
            ))

            Toggle("Launch at login", isOn: Binding(
                get: { appState.launchAtLoginEnabled },
                set: { appState.setLaunchAtLogin($0) }
            ))

            Divider()

            Button("Choose Sound...") {
                appState.chooseSoundFile()
            }

            Button("Play Test Sound") {
                appState.playTestSound()
            }
            .disabled(appState.settings.soundURL == nil)

            Button("Request Accessibility Access") {
                appState.requestAccessibilityAccess()
            }

            Divider()

            Button("Open Settings") {
                SettingsWindowController.shared.show(appState: appState)
            }

            Divider()

            Text(appState.monitorStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(appState.soundStatusText)
                .font(.caption)
                .foregroundStyle(appState.settings.soundURL == nil ? .red : .secondary)

            Text("Launch at login: \(appState.launchAtLoginStatusText)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(10)
        .frame(width: 300)
        .onAppear {
            appState.refreshPermissionState()
            appState.refreshLaunchAtLoginStatus()
            appState.applyMonitoringState()
        }
    }
}
