import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var isMonitoringEnabled: Bool {
        didSet {
            defaults.set(isMonitoringEnabled, forKey: Keys.isMonitoringEnabled)
        }
    }

    @Published var soundBookmarkData: Data? {
        didSet {
            defaults.set(soundBookmarkData, forKey: Keys.soundBookmarkData)
        }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let isMonitoringEnabled = "isMonitoringEnabled"
        static let soundBookmarkData = "soundBookmarkData"
    }

    init() {
        self.isMonitoringEnabled = defaults.object(forKey: Keys.isMonitoringEnabled) as? Bool ?? true
        self.soundBookmarkData = defaults.data(forKey: Keys.soundBookmarkData)
    }

    var soundURL: URL? {
        guard let soundBookmarkData else { return nil }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: soundBookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                let newBookmark = try url.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                self.soundBookmarkData = newBookmark
            }

            return url
        } catch {
            return nil
        }
    }

    var soundPathDisplay: String {
        soundURL?.path ?? "No sound selected"
    }

    func setSoundURL(_ url: URL) {
        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            soundBookmarkData = bookmark
        } catch {
            print("Failed to create sound bookmark: \(error)")
            fflush(stdout)
        }
    }
}
