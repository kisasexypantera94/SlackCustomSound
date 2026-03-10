import Foundation
import AppKit
import ApplicationServices

final class BannerMonitor {
    private let logger = Logger()

    private let slackBundleID = "com.tinyspeck.slackmacgap"
    private let notificationCenterBundleID = "com.apple.notificationcenterui"
    private let bannerSubroles = Set(["AXNotificationCenterBanner", "AXNotificationCenterAlert"])

    private let cooldown: TimeInterval = 1.5
    private let pollInterval: TimeInterval = 0.35
    private let recentPlaybackTTL: TimeInterval = 300.0

    private var observer: AXObserver?
    private var observedPID: pid_t?
    private var pollTimer: Timer?

    private var workspaceLaunchObserver: NSObjectProtocol?
    private var workspaceTerminateObserver: NSObjectProtocol?

    private var lastPlayDate: Date = .distantPast
    private var recentlyPlayedIDs: [String: Date] = [:]

    var onSlackNotification: (() -> Void)?

    func start() {
        stop()

        guard PermissionManager.isAccessibilityTrusted() else {
            logger.log("Accessibility permission is not granted")
            return
        }

        attachWorkspaceObservers()
        attachToNotificationCenterIfNeeded()
        startPolling()
        logger.log("Banner monitor started")
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        detachObserver()
        detachWorkspaceObservers()
        logger.log("Banner monitor stopped")
    }

    private func attachWorkspaceObservers() {
        detachWorkspaceObservers()

        let center = NSWorkspace.shared.notificationCenter

        workspaceLaunchObserver = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.attachToNotificationCenterIfNeeded()
        }

        workspaceTerminateObserver = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }

            if app.processIdentifier == self.observedPID {
                self.logger.log("Notification Center terminated, detaching observer")
                self.detachObserver()
            }
        }
    }

    private func detachWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter

        if let workspaceLaunchObserver {
            center.removeObserver(workspaceLaunchObserver)
            self.workspaceLaunchObserver = nil
        }

        if let workspaceTerminateObserver {
            center.removeObserver(workspaceTerminateObserver)
            self.workspaceTerminateObserver = nil
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.attachToNotificationCenterIfNeeded()
            self?.scanNotificationCenter(reason: "poll")
        }
    }

    private func attachToNotificationCenterIfNeeded() {
        guard let app = findNotificationCenterApp() else {
            return
        }

        if observedPID == app.processIdentifier, observer != nil {
            return
        }

        detachObserver()

        var createdObserver: AXObserver?
        let callback: AXObserverCallback = { _, _, notification, refcon in
            guard let refcon else { return }
            let monitor = Unmanaged<BannerMonitor>.fromOpaque(refcon).takeUnretainedValue()
            monitor.handleAXEvent(notification: notification as String)
        }

        let result = AXObserverCreate(app.processIdentifier, callback, &createdObserver)
        guard result == .success, let createdObserver else {
            logger.log("AXObserverCreate failed: \(result.rawValue)")
            return
        }

        observer = createdObserver
        observedPID = app.processIdentifier

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let notifications = [
            kAXCreatedNotification as String,
            kAXUIElementDestroyedNotification as String,
            kAXWindowCreatedNotification as String,
            kAXMainWindowChangedNotification as String,
            kAXFocusedWindowChangedNotification as String,
            kAXLayoutChangedNotification as String
        ]

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        for notification in notifications {
            _ = AXObserverAddNotification(createdObserver, axApp, notification as CFString, refcon)
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(createdObserver), .defaultMode)
        logger.log("Attached to Notification Center pid=\(app.processIdentifier)")
    }

    private func detachObserver() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }

        observer = nil
        observedPID = nil
    }

    private func handleAXEvent(notification: String) {
        logger.log("AX event: \(notification)")
        scanNotificationCenter(reason: "ax:\(notification)")
    }

    private func findNotificationCenterApp() -> NSRunningApplication? {
        let apps = NSWorkspace.shared.runningApplications

        if let exact = apps.first(where: { $0.bundleIdentifier == notificationCenterBundleID }) {
            return exact
        }

        if let byName = apps.first(where: { ($0.localizedName ?? "").contains("Notification Center") }) {
            return byName
        }

        return nil
    }

    private func findSlackApp() -> NSRunningApplication? {
        let apps = NSWorkspace.shared.runningApplications

        if let exact = apps.first(where: { $0.bundleIdentifier == slackBundleID }) {
            return exact
        }

        if let byName = apps.first(where: { ($0.localizedName ?? "").lowercased() == "slack" }) {
            return byName
        }

        return nil
    }

    private func scanNotificationCenter(reason: String) {
        guard let app = findNotificationCenterApp() else { return }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let roots = collectRootElements(axApp: axApp)

        for root in roots {
            inspectRecursively(root, depth: 0)
        }

        cleanupRecentlyPlayed()
        logger.log("Scanning Notification Center (\(reason)); roots=\(roots.count)")
    }

    private func collectRootElements(axApp: AXUIElement) -> [AXUIElement] {
        var roots: [AXUIElement] = [axApp]

        let attributes = [
            kAXWindowsAttribute as String,
            kAXChildrenAttribute as String,
            kAXMainWindowAttribute as String,
            kAXFocusedWindowAttribute as String
        ]

        for attribute in attributes {
            if let elements = copyAXElements(axApp, attribute: attribute) {
                roots.append(contentsOf: elements)
            } else if let single = copyAXElement(axApp, attribute: attribute) {
                roots.append(single)
            }
        }

        return roots
    }

    private func inspectRecursively(_ element: AXUIElement, depth: Int) {
        if depth > 8 { return }

        if let subrole = copyString(element, attribute: kAXSubroleAttribute as String),
           bannerSubroles.contains(subrole) {

            let text = collectText(element)

            if isProbablySlackBanner(text: text) {
                let identifier = copyString(element, attribute: kAXIdentifierAttribute as String) ?? makeStableSignature(text)
                maybeEmitNotification(id: identifier)
            }
        }

        if let children = copyAXElements(element, attribute: kAXChildrenAttribute as String) {
            for child in children {
                inspectRecursively(child, depth: depth + 1)
            }
        }
    }

    private func collectText(_ element: AXUIElement) -> String {
        var pieces: [String] = []

        if let title = copyString(element, attribute: kAXTitleAttribute as String), !title.isEmpty {
            pieces.append(title)
        }

        if let value = copyString(element, attribute: kAXValueAttribute as String), !value.isEmpty {
            pieces.append(value)
        }

        if let description = copyString(element, attribute: kAXDescriptionAttribute as String), !description.isEmpty {
            pieces.append(description)
        }

        if let help = copyString(element, attribute: kAXHelpAttribute as String), !help.isEmpty {
            pieces.append(help)
        }

        if let children = copyAXElements(element, attribute: kAXChildrenAttribute as String) {
            for child in children {
                pieces.append(collectText(child))
            }
        }

        return pieces
            .joined(separator: " | ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isProbablySlackBanner(text: String) -> Bool {
        let lower = text.lowercased()

        if lower.contains(slackBundleID.lowercased()) {
            return true
        }

        if let slackApp = findSlackApp() {
            let name = (slackApp.localizedName ?? "Slack").lowercased()
            if lower.contains(name) {
                return true
            }
        }

        if lower.contains("slack") {
            return true
        }

        return false
    }

    private func maybeEmitNotification(id: String) {
        let now = Date()

        if let playedAt = recentlyPlayedIDs[id],
           now.timeIntervalSince(playedAt) < recentPlaybackTTL {
            logger.log("Skipping recently played notification id=\(id)")
            return
        }

        if now.timeIntervalSince(lastPlayDate) < cooldown {
            logger.log("Skipping due to cooldown")
            return
        }

        recentlyPlayedIDs[id] = now
        lastPlayDate = now

        logger.log("Slack notification detected id=\(id)")
        onSlackNotification?()
    }

    private func cleanupRecentlyPlayed() {
        let now = Date()
        recentlyPlayedIDs = recentlyPlayedIDs.filter { _, playedAt in
            now.timeIntervalSince(playedAt) < recentPlaybackTTL
        }
    }

    private func makeStableSignature(_ text: String) -> String {
        let ignoredTokens = Set([
            "reply",
            "show details",
            "close",
            "options",
            "mark as read",
            "mute",
            "view",
            "open",
            "dismiss"
        ])

        let rawParts = text
            .components(separatedBy: "|")
            .map {
                $0
                    .lowercased()
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        let filteredParts = rawParts.filter { !ignoredTokens.contains($0) }
        return filteredParts.prefix(4).joined(separator: " | ")
    }

    private func copyString(_ element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard err == .success, let value else { return nil }
        return value as? String
    }

    private func copyAXElement(_ element: AXUIElement, attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard err == .success, let value else { return nil }
        return (value as! AXUIElement)
    }

    private func copyAXElements(_ element: AXUIElement, attribute: String) -> [AXUIElement]? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard err == .success, let value else { return nil }
        return value as? [AXUIElement]
    }
}
