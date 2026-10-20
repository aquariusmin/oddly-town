import SwiftUI
import OddlyTownCore

struct TownStatus {
    var progress: GrowthProgress
    var remainingToday: TimeInterval?
    var activitySeconds: [ActivityCategory: TimeInterval]
    /// What's shown (unlocked minus hidden).
    var features: Set<TownFeature>
    /// Everything unlocked, including features the user hid.
    var unlocked: Set<TownFeature> = []
    var isDemo: Bool
}

/// Text for Town Mode's "selected" panel.
struct SelectionInfo: Equatable {
    var title: String
    var detail: String
    var slot: Int?
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
    @Published var decor = DecorLayout.standard
    @Published var selection: SelectionInfo?
    @Published var isTownModeOpen = false

    let rules: GrowthRules
    let dataDirectory: URL
    let isDeveloper: Bool

    var onSettingsChanged: ((AppSettings, AppSettings) -> Void)?
    var onRequestTracking: ((Bool) -> Void)?
    var onResetActivity: (() -> Void)?
    var onResetTown: (() -> Void)?
    var onResetPosition: (() -> Void)?
    var onPlaceDecor: ((Int, DecorItem?) -> Void)?
    var onSetFeatureHidden: ((TownFeature, Bool) -> Void)?
    var onCloseTownMode: (() -> Void)?

    init(settings: AppSettings, status: TownStatus, rules: GrowthRules, dataDirectory: URL, isDeveloper: Bool) {
        self.settings = settings
        self.status = status
        self.rules = rules
        self.dataDirectory = dataDirectory
        self.isDeveloper = isDeveloper
    }
}
