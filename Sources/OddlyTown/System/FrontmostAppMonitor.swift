import AppKit
import CoreGraphics

/// Reports the bundle ID of the frontmost app, event-driven (no polling).
/// Uses only NSWorkspace activation notifications: no Accessibility or Screen Recording
/// permission, no window titles, no URLs.
@MainActor
final class FrontmostAppMonitor: NSObject {
    var onChange: ((String?) -> Void)?
    private var running = false

    func start() {
        guard !running else { return }
        running = true
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil
        )
        report(NSWorkspace.shared.frontmostApplication)
    }

    func stop() {
        guard running else { return }
        running = false
        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.didActivateApplicationNotification, object: nil)
    }

    /// Re-reports the current frontmost app (same own-process filtering as notifications).
    func reportCurrent() {
        report(NSWorkspace.shared.frontmostApplication)
    }

    @objc private func didActivate(_ notification: Notification) {
        report(notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
    }

    private func report(_ app: NSRunningApplication?) {
        // Time spent in Oddly Town's own windows isn't attributed to anything.
        guard let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            onChange?(nil)
            return
        }
        onChange?(app.bundleIdentifier)
    }
}

enum IdleTime {
    /// Seconds since the last keyboard/mouse event of any kind. Only the elapsed time
    /// is read — never which keys or where — and it needs no special permission.
    static func seconds() -> TimeInterval {
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }
}
