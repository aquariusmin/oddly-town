import SwiftUI
import OddlyTownCore

struct TownStatus {
    var progress: GrowthProgress
    var remainingToday: TimeInterval?
    var activitySeconds: [ActivityCategory: TimeInterval]
    var features: Set<TownFeature>
    var isDemo: Bool
}

/// Observable state for the SwiftUI windows. Mutations go back to `AppController`
/// through the callbacks, so all side effects live in one place.
@MainActor
final class AppModel: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            if settings != oldValue { onSettingsChanged?(oldValue, settings) }
        }
    }
    @Published var status: TownStatus

    let rules: GrowthRules
    let dataDirectory: URL
    let isDeveloper: Bool

    var onSettingsChanged: ((AppSettings, AppSettings) -> Void)?
    var onRequestTracking: ((Bool) -> Void)?
    var onResetActivity: (() -> Void)?
    var onResetTown: (() -> Void)?
    var onResetPosition: (() -> Void)?

    init(settings: AppSettings, status: TownStatus, rules: GrowthRules, dataDirectory: URL, isDeveloper: Bool) {
        self.settings = settings
        self.status = status
        self.rules = rules
        self.dataDirectory = dataDirectory
        self.isDeveloper = isDeveloper
    }
}
