import Foundation
import AVFoundation

final class SoundPlayer: NSObject {
    private let logger = Logger()
    private var player: AVAudioPlayer?
    private var accessURL: URL?

    func play(url: URL) {
        stopAccessIfNeeded()

        guard url.startAccessingSecurityScopedResource() || url.isFileURL else {
            logger.log("Failed to access sound file: \(url.path)")
            return
        }

        accessURL = url

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            if player?.play() == true {
                logger.log("Successfully started sound playback: \(url.path)")
            } else {
                logger.log("Failed to start sound playback: \(url.path)")
            }
        } catch {
            logger.log("Failed to load sound file \(url.path): \(error)")
            stopAccessIfNeeded()
        }
    }

    private func stopAccessIfNeeded() {
        if let accessURL {
            accessURL.stopAccessingSecurityScopedResource()
            self.accessURL = nil
        }
    }
}
