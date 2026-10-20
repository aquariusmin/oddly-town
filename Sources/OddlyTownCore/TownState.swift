import Foundation

/// Everything that grows, plus the user's decorations. Persisted as JSON; decoding is
/// lenient so older (v1) or partially damaged files load with defaults instead of failing.
///
/// Schema history: v1 (0.1.0) — growth and activity. v2 (0.2.0) — adds `decor`.
public struct TownState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var createdAt: Date
    /// Town time accumulated while the app ran (after the daily cap).
    public var growthSeconds: TimeInterval
    /// Estimated frontmost-app seconds per category (only while tracking is enabled).
    public var activitySeconds: [ActivityCategory: TimeInterval]
    /// Day key ("yyyy-MM-dd") that `growthSecondsOnCapDay` belongs to.
    public var capDay: String?
    public var growthSecondsOnCapDay: TimeInterval
    /// Town Mode decorations. v1 files get `DecorLayout.standard`.
    public var decor: DecorLayout

    public init(
        createdAt: Date = Date(),
        growthSeconds: TimeInterval = 0,
        activitySeconds: [ActivityCategory: TimeInterval] = [:],
        capDay: String? = nil,
        growthSecondsOnCapDay: TimeInterval = 0,
        decor: DecorLayout = .standard
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.createdAt = createdAt
        self.growthSeconds = growthSeconds
        self.activitySeconds = activitySeconds
        self.capDay = capDay
        self.growthSecondsOnCapDay = growthSecondsOnCapDay
        self.decor = decor
    }

    public func activitySeconds(for category: ActivityCategory) -> TimeInterval {
        activitySeconds[category] ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, createdAt, growthSeconds, activitySeconds, capDay, growthSecondsOnCapDay, decor
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Older files are upgraded in memory and written back as the current version on next save.
        schemaVersion = Self.currentSchemaVersion
        createdAt = (try? c.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date()
        growthSeconds = Self.sanitize((try? c.decodeIfPresent(Double.self, forKey: .growthSeconds)) ?? 0)
        // Decode as [String: Double] so an unknown category key doesn't discard the rest.
        let raw = (try? c.decodeIfPresent([String: Double].self, forKey: .activitySeconds)) ?? [:]
        var activity: [ActivityCategory: TimeInterval] = [:]
        for (key, value) in raw {
            if let category = ActivityCategory(rawValue: key) { activity[category] = Self.sanitize(value) }
        }
        activitySeconds = activity
        capDay = try? c.decodeIfPresent(String.self, forKey: .capDay)
        growthSecondsOnCapDay = Self.sanitize((try? c.decodeIfPresent(Double.self, forKey: .growthSecondsOnCapDay)) ?? 0)
        decor = (try? c.decodeIfPresent(DecorLayout.self, forKey: .decor)) ?? .standard
    }

    static func sanitize(_ value: Double) -> Double {
        value.isFinite && value > 0 ? value : 0
    }
}
