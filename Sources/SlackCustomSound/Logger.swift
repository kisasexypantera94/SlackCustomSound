import Foundation

final class Logger {
    private let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func log(_ message: String) {
        let timestamp = formatter.string(from: Date())
        print("[\(timestamp)] \(message)")
        fflush(stdout)
    }
}
