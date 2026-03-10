import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Status") {
                LabeledContent("Accessibility") {
                    Text(appState.accessibilityTrusted ? "Granted" : "Not granted")
                }

                LabeledContent("Monitor") {
                    Text(appState.monitorStatusText)
                }

                LabeledContent("Launch at login") {
                    Text(appState.launchAtLoginStatusText)
                }
            }

            Section("Sound") {
                if appState.settings.soundURL == nil {
                    Text("No sound selected")
                        .foregroundStyle(.red)

                    Text("Choose a sound file to enable playback.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(appState.settings.soundPathDisplay)
                        .font(.caption)
                        .textSelection(.enabled)
                }

                HStack {
                    Button("Choose Sound...") {
                        appState.chooseSoundFile()
                    }

                    Button("Play Test Sound") {
                        appState.playTestSound()
                    }
                    .disabled(appState.settings.soundURL == nil)
                }
            }

            Section("Controls") {
                Toggle("Enable monitoring", isOn: Binding(
                    get: { appState.settings.isMonitoringEnabled },
                    set: { appState.setMonitoringEnabled($0) }
                ))

                Toggle("Launch at login", isOn: Binding(
                    get: { appState.launchAtLoginEnabled },
                    set: { appState.setLaunchAtLogin($0) }
                ))

                Button("Request Accessibility Access") {
                    appState.requestAccessibilityAccess()
                }
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(width: 540, height: 340)
    }
}
