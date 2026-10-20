import Foundation

public enum ScreenCorner: String, Codable, CaseIterable, Sendable {
    case bottomRight, bottomLeft, topRight, topLeft, custom

    public var displayName: String {
        switch self {
        case .bottomRight: return "Bottom Right"
        case .bottomLeft: return "Bottom Left"
        case .topRight: return "Top Right"
        case .topLeft: return "Top Left"
        case .custom: return "Custom (dragged)"
        }
    }
}

public struct SavedPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public static let aspectRatio = 180.0 / 420.0
    public static let minWidth = 280.0
    public static let maxWidth = 840.0
    public static let defaultWidth = 420.0

    public var windowWidth: Double = AppSettings.defaultWidth
    public var corner: ScreenCorner = .bottomRight
    public var customOrigin: SavedPoint?
    public var townVisible = true
    public var animationsEnabled = true
    public var clickThrough = false
    public var floatAboveWindows = true
    public var showOverFullScreenApps = false
    public var activityTrackingEnabled = false
    /// Bundle ID → category, takes priority over the built-in table.
    public var categoryOverrides: [String: ActivityCategory] = [:]

    public init() {}

    public var windowHeight: Double { (windowWidth * Self.aspectRatio).rounded() }

    public static func clampWidth(_ width: Double) -> Double {
        guard width.isFinite else { return defaultWidth }
        return min(max(width, minWidth), maxWidth)
    }

    private enum CodingKeys: String, CodingKey {
        case windowWidth, corner, customOrigin, townVisible, animationsEnabled, clickThrough
        case floatAboveWindows, showOverFullScreenApps, activityTrackingEnabled, categoryOverrides
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        windowWidth = Self.clampWidth((try? c.decodeIfPresent(Double.self, forKey: .windowWidth)) ?? d.windowWidth)
        corner = (try? c.decodeIfPresent(ScreenCorner.self, forKey: .corner)) ?? d.corner
        customOrigin = try? c.decodeIfPresent(SavedPoint.self, forKey: .customOrigin)
        townVisible = (try? c.decodeIfPresent(Bool.self, forKey: .townVisible)) ?? d.townVisible
        animationsEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .animationsEnabled)) ?? d.animationsEnabled
        clickThrough = (try? c.decodeIfPresent(Bool.self, forKey: .clickThrough)) ?? d.clickThrough
        floatAboveWindows = (try? c.decodeIfPresent(Bool.self, forKey: .floatAboveWindows)) ?? d.floatAboveWindows
        showOverFullScreenApps = (try? c.decodeIfPresent(Bool.self, forKey: .showOverFullScreenApps)) ?? d.showOverFullScreenApps
        activityTrackingEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .activityTrackingEnabled)) ?? d.activityTrackingEnabled
        let rawOverrides = (try? c.decodeIfPresent([String: String].self, forKey: .categoryOverrides)) ?? [:]
        categoryOverrides = rawOverrides.compactMapValues(ActivityCategory.init(rawValue:))
        if corner == .custom && customOrigin == nil { corner = .bottomRight }
    }
}
