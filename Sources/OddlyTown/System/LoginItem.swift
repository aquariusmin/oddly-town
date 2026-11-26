import Foundation
import ServiceManagement

/// "Open at Login" through `SMAppService.mainApp`.
///
/// The system owns this state: nothing is written to settings.json, and the user can also
/// change it in System Settings → General → Login Items, so always read `state` fresh.
/// Only a bundled `.app` can be a login item; `swift run` reports `.unavailable`.
@MainActor
enum LoginItem {
    enum State: Equatable {
        case on
        case off
        /// Registered, but the user still has to allow it in System Settings → Login Items.
        case needsApproval
        /// Not running from an .app bundle.
        case unavailable
    }

    static var state: State {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return .unavailable }
        switch SMAppService.mainApp.status {
        case .enabled: return .on
        case .requiresApproval: return .needsApproval
        case .notRegistered, .notFound: return .off
        @unknown default: return .off
        }
    }

    static func set(_ on: Bool) throws {
        if on {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
