import Foundation

public enum Weather: String, CaseIterable, Codable, Sendable {
    case clear, rain, snow

    /// Rain or snow: residents stay in more, some events wait.
    public var isWet: Bool { self != .clear }
    public var displayName: String { rawValue.capitalized }
}

/// How often it rains or snows. On a "shower day" there is one shower of a few hours.
public struct WeatherRules: Equatable, Sendable {
    /// Chance per day of a shower, by season.
    public var showerChance: [Season: Double]
    /// Hour of the local day the shower starts (inclusive range).
    public var startHours: ClosedRange<Int>
    /// Shower length in hours.
    public var durationHours: ClosedRange<Int>

    public init(showerChance: [Season: Double], startHours: ClosedRange<Int>, durationHours: ClosedRange<Int>) {
        self.showerChance = showerChance
        self.startHours = startHours
        self.durationHours = durationHours
    }

    /// Roughly one shower day in five, a little wetter in spring, drier in summer.
    /// Showers start 06:00–19:00 and last 2–5 h, so they never run past midnight.
    public static let standard = WeatherRules(
        showerChance: [.spring: 0.25, .summer: 0.15, .autumn: 0.22, .winter: 0.22],
        startHours: 6...19,
        durationHours: 2...5
    )
}

/// The weather is worked out, not saved: the same day, season and town seed always give
/// the same shower, so Ambient Mode, Town Mode and a relaunch all agree, and tests can pin it.
public enum WeatherForecast {
    /// The shower on `date`'s local day, if that day has one.
    public static func shower(on date: Date, season: Season, seed: UInt64, rules: WeatherRules = .standard,
                              calendar: Calendar = .current) -> DateInterval? {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        let year: Int = day.year ?? 0, month: Int = day.month ?? 0, dayOfMonth: Int = day.day ?? 0
        let dayKey = UInt64(year * 10_000 + month * 100 + dayOfMonth)
        var rng = SplitMix64(seed: seed ^ (dayKey &* 0x9E37_79B9_7F4A_7C15))
        let roll = Double(rng.next() >> 11) / Double(1 << 53)
        guard roll < (rules.showerChance[season] ?? 0) else { return nil }

        let startSpan = UInt64(rules.startHours.count)
        let lengthSpan = UInt64(rules.durationHours.count)
        let startHour = rules.startHours.lowerBound + Int(rng.next() % startSpan)
        let hours = rules.durationHours.lowerBound + Int(rng.next() % lengthSpan)
        let midnight = calendar.startOfDay(for: date)
        guard let start = calendar.date(byAdding: .hour, value: startHour, to: midnight),
              let end = calendar.date(byAdding: .hour, value: hours, to: start) else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// Snow in winter, rain otherwise, clear outside the day's shower.
    public static func weather(at date: Date, season: Season, seed: UInt64, rules: WeatherRules = .standard,
                               calendar: Calendar = .current) -> Weather {
        guard let shower = shower(on: date, season: season, seed: seed, rules: rules, calendar: calendar),
              shower.start <= date, date < shower.end else { return .clear }
        return season == .winter ? .snow : .rain
    }
}

extension TownState {
    /// Gives each town its own weather pattern (two people's towns don't rain on the same days).
    public var weatherSeed: UInt64 {
        UInt64(bitPattern: Int64(createdAt.timeIntervalSince1970.rounded()))
    }
}
