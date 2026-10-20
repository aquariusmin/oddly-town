import Foundation

/// Small, optional happenings. Missing one costs nothing; they end on their own.
public enum TownEventKind: String, CaseIterable, Codable, Sendable {
    case strayCat, traveler, gathering

    public var displayName: String {
        switch self {
        case .strayCat: return "A stray cat wanders through"
        case .traveler: return "A traveler stops by"
        case .gathering: return "The neighbours gather"
        }
    }
}

public struct TownEventRule: Sendable {
    public let kind: TownEventKind
    public let weight: Double
    public let duration: TimeInterval
    public let phases: Set<DayPhase>
    public let minimumLevel: Int
    public let minimumResidents: Int

    public init(kind: TownEventKind, weight: Double, duration: TimeInterval, phases: Set<DayPhase>,
                minimumLevel: Int = 1, minimumResidents: Int = 1) {
        self.kind = kind
        self.weight = weight
        self.duration = duration
        self.phases = phases
        self.minimumLevel = minimumLevel
        self.minimumResidents = minimumResidents
    }
}

public struct EventRules: Sendable {
    /// Quiet time after an event ends before another can start.
    public var minimumGap: TimeInterval
    /// Chance per minute (once the gap has passed) that something happens.
    public var chancePerMinute: Double
    public var rules: [TownEventRule]

    public init(minimumGap: TimeInterval, chancePerMinute: Double, rules: [TownEventRule]) {
        self.minimumGap = minimumGap
        self.chancePerMinute = chancePerMinute
        self.rules = rules
    }

    /// On average one small event every ~30 minutes of watching, never two at once.
    public static let standard = EventRules(
        minimumGap: 25 * 60,
        chancePerMinute: 0.15,
        rules: [
            TownEventRule(kind: .strayCat, weight: 3, duration: 40, phases: [.dawn, .day, .dusk]),
            TownEventRule(kind: .traveler, weight: 2, duration: 70, phases: [.day]),
            TownEventRule(kind: .gathering, weight: 2, duration: 60, phases: [.day, .dusk],
                          minimumLevel: 2, minimumResidents: 2),
        ]
    )

    public func rule(for kind: TownEventKind) -> TownEventRule? {
        rules.first { $0.kind == kind }
    }
}

public struct EventContext: Equatable, Sendable {
    public var level: Int
    public var phase: DayPhase
    public var lateNight: Bool
    public var residentCount: Int
    /// Nobody can see the town (hidden, display asleep): don't start anything.
    public var isVisible: Bool

    public init(level: Int, phase: DayPhase, lateNight: Bool, residentCount: Int, isVisible: Bool) {
        self.level = level
        self.phase = phase
        self.lateNight = lateNight
        self.residentCount = residentCount
        self.isVisible = isVisible
    }
}

public enum EventChange: Equatable, Sendable {
    case started(TownEventKind, duration: TimeInterval)
    case ended(TownEventKind)
}

/// Decides when events start and end. Called from the low-frequency app tick, so it costs
/// nothing between ticks and holds at most one active event.
public struct EventScheduler: Sendable {
    public struct Active: Equatable, Sendable {
        public let kind: TownEventKind
        public let endsAt: Date
    }

    public let rules: EventRules
    public private(set) var active: Active?
    public private(set) var quietUntil: Date

    public init(rules: EventRules = .standard, start: Date) {
        self.rules = rules
        quietUntil = start.addingTimeInterval(rules.minimumGap)
    }

    public func eligibleRules(for context: EventContext) -> [TownEventRule] {
        guard context.isVisible, !context.lateNight else { return [] }
        return rules.rules.filter {
            $0.phases.contains(context.phase) && context.level >= $0.minimumLevel && context.residentCount >= $0.minimumResidents
        }
    }

    /// `elapsed` is the time since the previous update, so the chance scales with tick length.
    public mutating func update<G: RandomNumberGenerator>(now: Date, elapsed: TimeInterval,
                                                          context: EventContext, using rng: inout G) -> [EventChange] {
        if let current = active {
            guard now >= current.endsAt else { return [] }
            active = nil
            quietUntil = now.addingTimeInterval(rules.minimumGap)
            return [.ended(current.kind)]
        }
        guard now >= quietUntil else { return [] }
        let candidates = eligibleRules(for: context)
        guard !candidates.isEmpty else { return [] }
        let minutes = max(0, elapsed) / 60
        let chance = 1 - pow(1 - rules.chancePerMinute, minutes)
        guard Double.random(in: 0..<1, using: &rng) < chance else { return [] }

        let total = candidates.reduce(0) { $0 + $1.weight }
        var roll = Double.random(in: 0..<total, using: &rng)
        var chosen = candidates[candidates.count - 1]
        for rule in candidates {
            if roll < rule.weight { chosen = rule; break }
            roll -= rule.weight
        }
        active = Active(kind: chosen.kind, endsAt: now.addingTimeInterval(chosen.duration))
        return [.started(chosen.kind, duration: chosen.duration)]
    }

    /// Demo Mode: start `kind` right away, ending whatever is running.
    public mutating func force(_ kind: TownEventKind, now: Date) -> [EventChange] {
        var changes: [EventChange] = []
        if let current = active { changes.append(.ended(current.kind)) }
        let duration = rules.rule(for: kind)?.duration ?? 45
        active = Active(kind: kind, endsAt: now.addingTimeInterval(duration))
        changes.append(.started(kind, duration: duration))
        return changes
    }

    public mutating func endActive(now: Date) -> [EventChange] {
        guard let current = active else { return [] }
        active = nil
        quietUntil = now.addingTimeInterval(rules.minimumGap)
        return [.ended(current.kind)]
    }
}
