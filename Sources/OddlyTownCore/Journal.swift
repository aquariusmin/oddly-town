import Foundation

// The town journal: a few lines a day about what happened while the town was running,
// so there's something to read even if you weren't watching. Rules and wording live
// here (testable); AppController only reports what it saw. See docs/DESIGN-SEASONS-JOURNAL.md (C).
//
// Privacy: lines never name apps or activity categories. Buildings that came from activity
// are written as plain arrivals ("A workshop opened.") and are removed when the activity
// history is reset.

/// Something worth a line in the journal.
public enum JournalMoment: Equatable, Sendable {
    case event(TownEventKind, festive: Bool)
    case levelUp(Int)
    /// A building, a decoration feature or a new resident appeared.
    case arrived(TownFeature)
    case seasonBegan(Season)
    case shower(Weather, firstSnow: Bool)
    /// Residents `a` and `b` (indices) had a chat.
    case chat(Int, Int)

    /// Same key twice in one day is written once.
    public var key: String {
        switch self {
        case .event(let kind, _): return "event:\(kind.rawValue)"
        case .levelUp(let level): return "level:\(level)"
        case .arrived(let feature): return "arrived:\(feature.rawValue)"
        case .seasonBegan(let season): return "season:\(season.rawValue)"
        case .shower(let weather, let first): return first ? "first-snow" : "weather:\(weather.rawValue)"
        case .chat(let a, let b): return "chat:\(min(a, b))-\(max(a, b))"
        }
    }

    /// Milestones are always written; everyday moments share a daily limit.
    public var isMilestone: Bool {
        switch self {
        case .levelUp, .arrived, .seasonBegan: return true
        case .shower(_, let first): return first
        case .event, .chat: return false
        }
    }

    /// One sentence. `variant` picks among phrasings so days don't read the same.
    public func text(names: [String], variant: UInt64) -> String {
        func name(_ i: Int) -> String { names.indices.contains(i) ? names[i] : "A neighbour" }
        func pick(_ options: [String]) -> String { options[Int(variant % UInt64(options.count))] }
        switch self {
        case .event(.strayCat, _):
            return pick(["A stray cat wandered through.", "A stray cat napped by the mailbox for a while.",
                         "A stray cat came by and didn't stay long."])
        case .event(.traveler, _):
            return pick(["A traveler stopped by on their way somewhere.", "A traveler passed through and waved.",
                         "Someone new walked through town today."])
        case .event(.gathering, let festive):
            return festive
                ? pick(["The neighbours held a little festival.", "Everyone gathered under the bunting to celebrate."])
                : pick(["The neighbours gathered in the square.", "Everyone met in the square for a while."])
        case .levelUp(let level):
            return "The town grew to Level \(level)."
        case .arrived(let feature):
            switch feature {
            case .youngTree: return "A young tree was planted."
            case .picketFence: return "A picket fence went up."
            case .wildflowers: return "Wildflowers spread along the path."
            case .lamppost: return "A lamppost now lights the path."
            case .secondResident: return "\(name(1)) moved in."
            case .secondHouse: return "A blue-roofed house was built."
            case .well: return "A well was dug in the middle of town."
            case .thirdResident: return "\(name(2)) moved into the blue house."
            case .workshop: return "A workshop opened. Someone's already tinkering."
            case .artGarden: return "Flowers and an easel appeared by the path."
            case .readingNook: return "A little reading nook opened."
            case .festivalBunting: return "Bunting went up across the town."
            }
        case .seasonBegan(let season):
            switch season {
            case .spring: return "Spring arrived. The trees are in blossom."
            case .summer: return "Summer is here."
            case .autumn: return "The leaves turned for autumn."
            case .winter: return "Winter came to town."
            }
        case .shower(.snow, true):
            return "First snow of the winter!"
        case .shower(.snow, false):
            return pick(["It snowed for a while.", "Snow fell quietly over the town."])
        case .shower(_, _):
            return pick(["It rained for a while.", "A shower passed over the town.", "Rain kept everyone indoors for a bit."])
        case .chat(let a, let b):
            let (first, second) = a < b ? (a, b) : (b, a)
            return pick(["\(name(first)) and \(name(second)) had a chat in the square.",
                         "\(name(first)) and \(name(second)) stopped to talk.",
                         "\(name(second)) caught up with \(name(first))."])
        }
    }
}

public struct JournalEntry: Codable, Equatable, Sendable {
    public let time: Date
    public let key: String
    public let text: String
    public let isMilestone: Bool

    public init(time: Date, key: String, text: String, isMilestone: Bool) {
        self.time = time
        self.key = key
        self.text = text
        self.isMilestone = isMilestone
    }
}

public struct JournalDay: Codable, Equatable, Sendable {
    /// Local calendar day, "yyyy-MM-dd".
    public let day: String
    public internal(set) var entries: [JournalEntry]
}

/// Saved as journal.json, separate from town.json so a damaged journal never costs progress.
public struct Journal: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    /// Everyday lines per day (milestones don't count and are always written).
    public static let everydayLimit = 6
    /// Days kept; older ones are dropped.
    public static let keepDays = 60

    public var schemaVersion = Journal.currentSchemaVersion
    /// Oldest first.
    public private(set) var days: [JournalDay] = []
    /// The season the town last showed, so a new season is noticed even across launches.
    public var lastSeason: Season?
    /// Snow has been written down since the season last changed ("first snow" once per winter).
    public var snowedThisSeason = false

    public init() {}

    /// Writes `moment` unless it was already written today or today's everyday lines are used up.
    @discardableResult
    public mutating func record(_ moment: JournalMoment, at time: Date, names: [String],
                                calendar: Calendar = .current) -> JournalEntry? {
        let day = Self.dayKey(time, calendar: calendar)
        let index: Int
        if let last = days.indices.last, days[last].day == day {
            index = last
        } else {
            days.append(JournalDay(day: day, entries: []))
            index = days.count - 1
        }
        let today = days[index].entries
        guard !today.contains(where: { $0.key == moment.key }) else { return nil }
        if !moment.isMilestone && today.filter({ !$0.isMilestone }).count >= Self.everydayLimit { return nil }

        let variant = Self.hash("\(day)|\(moment.key)")
        let entry = JournalEntry(time: time, key: moment.key, text: moment.text(names: names, variant: variant),
                                 isMilestone: moment.isMilestone)
        days[index].entries.append(entry)
        if case .shower(.snow, _) = moment { snowedThisSeason = true }
        prune(before: time, calendar: calendar)
        return entry
    }

    /// Notes the season. Returns the moment to record when it changed since last time
    /// (never on the very first call).
    public mutating func noteSeason(_ season: Season) -> JournalMoment? {
        defer { lastSeason = season }
        guard let lastSeason, lastSeason != season else { return nil }
        snowedThisSeason = false
        return .seasonBegan(season)
    }

    public func entries(on date: Date, calendar: Calendar = .current) -> [JournalEntry] {
        let day = Self.dayKey(date, calendar: calendar)
        return days.last(where: { $0.day == day })?.entries ?? []
    }

    /// Newest day first, empty days skipped.
    public func recent(_ count: Int) -> [JournalDay] {
        Array(days.reversed().filter { !$0.entries.isEmpty }.prefix(count))
    }

    public var latest: JournalEntry? { days.last(where: { !$0.entries.isEmpty })?.entries.last }

    public mutating func removeEntries(where shouldRemove: (JournalEntry) -> Bool) {
        for i in days.indices { days[i].entries.removeAll(where: shouldRemove) }
        days.removeAll { $0.entries.isEmpty }
    }

    private mutating func prune(before time: Date, calendar: Calendar) {
        guard let cutoff = calendar.date(byAdding: .day, value: -(Self.keepDays - 1), to: time) else { return }
        let oldest = Self.dayKey(cutoff, calendar: calendar)
        days.removeAll { $0.day < oldest } // "yyyy-MM-dd" sorts by date
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let year: Int = c.year ?? 0, month: Int = c.month ?? 0, day: Int = c.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Stable across launches and platforms (unlike `Hasher`).
    static func hash(_ text: String) -> UInt64 {
        var h: UInt64 = 0xCBF2_9CE4_8422_2325 // FNV-1a
        for byte in text.utf8 { h = (h ^ UInt64(byte)) &* 0x0000_0100_0000_01B3 }
        return h
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, days, lastSeason, snowedThisSeason }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = Self.currentSchemaVersion
        days = (try? c.decodeIfPresent([JournalDay].self, forKey: .days)) ?? []
        lastSeason = try? c.decodeIfPresent(Season.self, forKey: .lastSeason)
        snowedThisSeason = (try? c.decodeIfPresent(Bool.self, forKey: .snowedThisSeason)) ?? false
    }
}

/// Remembers the town at the previous tick so changes can be written down. Not saved:
/// the first look after launch (or a reset) only takes note.
public struct JournalWatcher: Sendable {
    private var level: Int?
    private var unlocked: Set<TownFeature>?
    private var weather: Weather?

    public init() {}

    /// What's new since the last call: level-ups, arrivals (in a stable order), a shower starting.
    public mutating func changes(level: Int, unlocked: Set<TownFeature>, weather: Weather,
                                 snowedThisSeason: Bool) -> [JournalMoment] {
        defer {
            self.level = level
            self.unlocked = unlocked
            self.weather = weather
        }
        guard let oldLevel = self.level, let oldUnlocked = self.unlocked, let oldWeather = self.weather else { return [] }
        var moments: [JournalMoment] = []
        if level > oldLevel {
            moments += ((oldLevel + 1)...level).map { .levelUp($0) }
        }
        moments += TownFeature.allCases.filter { unlocked.contains($0) && !oldUnlocked.contains($0) }.map { .arrived($0) }
        if weather.isWet && weather != oldWeather {
            moments.append(.shower(weather, firstSnow: weather == .snow && !snowedThisSeason))
        }
        return moments
    }
}
