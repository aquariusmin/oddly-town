import Foundation

public struct GrowthProgress: Equatable, Sendable {
    public let level: Int
    public let maxLevel: Int
    /// 0…1 progress toward the next level (1 at max level).
    public let fractionToNext: Double
    /// Growth seconds still needed for the next level; `nil` at max level.
    public let secondsToNext: TimeInterval?
}

/// Pure growth logic: takes time and activity, returns new state. No UI, no clocks.
public struct GrowthEngine: Sendable {
    public let rules: GrowthRules

    public init(rules: GrowthRules = .standard) {
        self.rules = rules
    }

    /// Credits `seconds` of town time, respecting the daily cap when `applyDailyCap` is true.
    public func advancing(
        _ state: TownState,
        by seconds: TimeInterval,
        now: Date,
        calendar: Calendar = .current,
        applyDailyCap: Bool = true
    ) -> TownState {
        guard seconds.isFinite, seconds > 0 else { return state }
        var next = state
        let day = Self.dayKey(for: now, calendar: calendar)
        if next.capDay != day {
            next.capDay = day
            next.growthSecondsOnCapDay = 0
        }
        var credited = seconds
        if applyDailyCap, let cap = rules.dailyGrowthCap {
            credited = min(seconds, max(0, cap - next.growthSecondsOnCapDay))
        }
        next.growthSeconds += credited
        next.growthSecondsOnCapDay += credited
        return next
    }

    public func recordingActivity(_ state: TownState, category: ActivityCategory, seconds: TimeInterval) -> TownState {
        guard seconds.isFinite, seconds > 0 else { return state }
        var next = state
        next.activitySeconds[category, default: 0] += seconds
        return next
    }

    public func level(of state: TownState) -> Int {
        1 + rules.levelThresholds.filter { state.growthSeconds >= $0 }.count
    }

    public func progress(of state: TownState) -> GrowthProgress {
        let level = level(of: state)
        guard level < rules.maxLevel else {
            return GrowthProgress(level: level, maxLevel: rules.maxLevel, fractionToNext: 1, secondsToNext: nil)
        }
        let previous = level == 1 ? 0 : rules.levelThresholds[level - 2]
        let target = rules.levelThresholds[level - 1]
        let fraction = (state.growthSeconds - previous) / (target - previous)
        return GrowthProgress(
            level: level,
            maxLevel: rules.maxLevel,
            fractionToNext: min(max(fraction, 0), 1),
            secondsToNext: max(0, target - state.growthSeconds)
        )
    }

    /// Features unlocked purely by level (used by Demo Mode too).
    public func levelFeatures(forLevel level: Int) -> Set<TownFeature> {
        var features = Set<TownFeature>()
        for (required, list) in rules.levelFeatures where required <= level {
            features.formUnion(list)
        }
        return features
    }

    public func unlockedFeatures(of state: TownState) -> Set<TownFeature> {
        let level = level(of: state)
        var features = levelFeatures(forLevel: level)
        for unlock in rules.activityUnlocks
        where level >= unlock.minimumLevel && state.activitySeconds(for: unlock.category) >= unlock.requiredSeconds {
            features.insert(unlock.feature)
        }
        return features
    }

    /// Remaining seconds of the daily cap for `now`'s day (`nil` when uncapped).
    public func remainingToday(_ state: TownState, now: Date, calendar: Calendar = .current) -> TimeInterval? {
        guard let cap = rules.dailyGrowthCap else { return nil }
        let used = state.capDay == Self.dayKey(for: now, calendar: calendar) ? state.growthSecondsOnCapDay : 0
        return max(0, cap - used)
    }

    public static func dayKey(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
