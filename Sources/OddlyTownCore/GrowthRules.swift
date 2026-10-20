import Foundation

/// Things in the town that can appear. Level-1 basics (cottage, two trees, path,
/// mailbox, one resident, clouds) are always present and not listed here.
public enum TownFeature: String, Codable, CaseIterable, Sendable {
    // Level 2
    case youngTree, picketFence, wildflowers, lamppost, secondResident
    // Level 3
    case secondHouse, well
    // Activity-driven
    case workshop, artGarden, readingNook, festivalBunting

    public var displayName: String {
        switch self {
        case .youngTree: return "Young tree"
        case .picketFence: return "Picket fence"
        case .wildflowers: return "Wildflowers"
        case .lamppost: return "Lamppost"
        case .secondResident: return "New neighbour"
        case .secondHouse: return "Blue-roof house"
        case .well: return "Village well"
        case .workshop: return "Workshop"
        case .artGarden: return "Art garden"
        case .readingNook: return "Reading nook"
        case .festivalBunting: return "Festival bunting"
        }
    }
}

public struct ActivityUnlock: Equatable, Sendable {
    public let category: ActivityCategory
    public let feature: TownFeature
    public let requiredSeconds: TimeInterval
    public let minimumLevel: Int

    public init(category: ActivityCategory, feature: TownFeature, requiredSeconds: TimeInterval, minimumLevel: Int) {
        self.category = category
        self.feature = feature
        self.requiredSeconds = requiredSeconds
        self.minimumLevel = minimumLevel
    }
}

/// All tunable growth numbers live here.
public struct GrowthRules: Equatable, Sendable {
    /// Cumulative growth seconds needed to reach level 2, 3, … (ascending).
    public var levelThresholds: [TimeInterval]
    /// Max growth credited per calendar day, so long sessions don't speed things up
    /// beyond a gentle pace. `nil` disables the cap.
    public var dailyGrowthCap: TimeInterval?
    public var levelFeatures: [Int: [TownFeature]]
    public var activityUnlocks: [ActivityUnlock]

    public init(
        levelThresholds: [TimeInterval],
        dailyGrowthCap: TimeInterval?,
        levelFeatures: [Int: [TownFeature]],
        activityUnlocks: [ActivityUnlock]
    ) {
        self.levelThresholds = levelThresholds
        self.dailyGrowthCap = dailyGrowthCap
        self.levelFeatures = levelFeatures
        self.activityUnlocks = activityUnlocks
    }

    public var maxLevel: Int { levelThresholds.count + 1 }

    public static let hour: TimeInterval = 3600

    public static let standard = GrowthRules(
        levelThresholds: [2 * hour, 6 * hour],
        dailyGrowthCap: 3 * hour,
        levelFeatures: [
            2: [.youngTree, .picketFence, .wildflowers, .lamppost, .secondResident],
            3: [.secondHouse, .well],
        ],
        activityUnlocks: [
            ActivityUnlock(category: .development, feature: .workshop, requiredSeconds: 0.75 * hour, minimumLevel: 2),
            ActivityUnlock(category: .creative, feature: .artGarden, requiredSeconds: 0.75 * hour, minimumLevel: 1),
            ActivityUnlock(category: .productivity, feature: .readingNook, requiredSeconds: 0.75 * hour, minimumLevel: 2),
            ActivityUnlock(category: .entertainment, feature: .festivalBunting, requiredSeconds: 0.75 * hour, minimumLevel: 1),
        ]
    )
}
