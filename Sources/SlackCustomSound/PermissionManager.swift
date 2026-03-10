import Foundation
import ApplicationServices

enum PermissionManager {
    static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrustedWithOptions(nil)
    }

    static func requestAccessibilityPrompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
