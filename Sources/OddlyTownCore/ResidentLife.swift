import Foundation

/// Deterministic RNG so behaviour and events are reproducible in tests.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

public enum Home: String, Sendable {
    case cottage, blueHouse
}

/// Named places residents go. The renderer maps each to a position.
public enum TownSpot: Hashable, Sendable {
    case home(Home)
    case seat(slot: Int)
    case wander(Int)
    case well, plaza, workshop, artGarden, readingNook

    public static let wanderCount = 7
}

public enum ResidentActivity: String, CaseIterable, Sendable {
    case walking, idle, sitting, working, socializing, returningHome
    case reading, admiringFlowers, celebrating

    public var displayName: String {
        switch self {
        case .walking: return "Taking a stroll"
        case .idle: return "Looking around"
        case .sitting: return "Resting on the bench"
        case .working: return "Working"
        case .socializing: return "Chatting"
        case .returningHome: return "At home"
        case .reading: return "Reading at the nook"
        case .admiringFlowers: return "Admiring the flowers"
        case .celebrating: return "Celebrating"
        }
    }

    /// Seconds spent doing the activity after arriving (walking time comes on top).
    /// Keeps the town calm: nobody switches activity every second.
    public var durationRange: ClosedRange<TimeInterval> {
        switch self {
        case .walking: return 3...6
        case .idle: return 6...12
        case .sitting: return 20...45
        case .working: return 15...35
        case .socializing: return 12...24
        case .returningHome: return 40...120
        case .reading: return 20...45
        case .admiringFlowers: return 12...25
        case .celebrating: return 14...24
        }
    }
}

public struct BehaviorPlan: Equatable, Sendable {
    public let activity: ResidentActivity
    public let spot: TownSpot
    public let duration: TimeInterval
    /// For socializing: who they're talking to (another resident's index), if anyone.
    public let partner: Int?

    public init(activity: ResidentActivity, spot: TownSpot, duration: TimeInterval, partner: Int? = nil) {
        self.activity = activity
        self.spot = spot
        self.duration = duration
        self.partner = partner
    }
}

/// What residents know about the world when choosing what to do next.
public struct LifeContext: Equatable, Sendable {
    public var phase: DayPhase
    public var lateNight: Bool
    public var features: Set<TownFeature>
    public var seatSlots: [Int]

    public init(phase: DayPhase, lateNight: Bool, features: Set<TownFeature>, seatSlots: [Int]) {
        self.phase = phase
        self.lateNight = lateNight
        self.features = features
        self.seatSlots = seatSlots
    }

    public init(snapshot: TownSnapshot) {
        self.init(phase: snapshot.phase, lateNight: snapshot.lateNight, features: snapshot.features, seatSlots: snapshot.seatSlots)
    }
}

/// Behaviour tuning in one place. Activity-driven buildings add their own activity,
/// so what the user does on the Mac changes what residents do, not just what's built.
public enum ResidentBehaviorRules {
    public struct FeatureActivity: Sendable {
        public let activity: ResidentActivity
        public let spot: TownSpot
        public let weight: Double
    }

    public static let featureActivities: [TownFeature: FeatureActivity] = [
        .workshop: FeatureActivity(activity: .working, spot: .workshop, weight: 3.5),
        .artGarden: FeatureActivity(activity: .admiringFlowers, spot: .artGarden, weight: 3),
        .readingNook: FeatureActivity(activity: .reading, spot: .readingNook, weight: 3),
        .festivalBunting: FeatureActivity(activity: .celebrating, spot: .plaza, weight: 1.5),
    ]

    /// Candidate activities with weights. `.returningHome` dominates in the evening and is
    /// the only choice late at night.
    public static func weights(for context: LifeContext, residentCount: Int) -> [ResidentActivity: Double] {
        if context.lateNight { return [.returningHome: 1] }
        var w: [ResidentActivity: Double] = [:]
        let hasSeat = !context.seatSlots.isEmpty
        let canChat = residentCount > 1
        switch context.phase {
        case .night:
            w[.returningHome] = 12
            w[.idle] = 1
        case .dusk:
            w[.returningHome] = 4
            w[.walking] = 1
            w[.idle] = 1
            if hasSeat { w[.sitting] = 2 }
            if canChat { w[.socializing] = 1.5 }
        case .dawn, .day:
            w[.walking] = 3
            w[.idle] = 2
            w[.working] = 1
            if hasSeat { w[.sitting] = 1.5 }
            if canChat { w[.socializing] = 1.5 }
        }
        if context.phase != .night {
            for (feature, entry) in featureActivities where context.features.contains(feature) {
                if entry.activity == .celebrating && context.phase == .dawn { continue }
                w[entry.activity, default: 0] += entry.weight
            }
        }
        return w
    }
}

/// One resident's memory: what they're doing and whether they're indoors.
public struct ResidentMind: Equatable, Sendable {
    public let index: Int
    public let home: Home
    public internal(set) var plan: BehaviorPlan?
    public internal(set) var lastActivity: ResidentActivity?

    /// Inside their home after `.returningHome` (the renderer hides them).
    public var isHome: Bool { plan?.activity == .returningHome }
}

/// The town's residents and how they pick what to do. Decisions happen only when a plan
/// finishes (every 10–60 s per resident), never per frame.
public struct TownLife: Sendable {
    public private(set) var residents: [ResidentMind] = []
    private var rng: SplitMix64

    public init(seed: UInt64) {
        rng = SplitMix64(seed: seed)
    }

    public static func home(forResident index: Int) -> Home {
        index == 2 ? .blueHouse : .cottage
    }

    /// Adds or removes residents (e.g. a level-up). New residents get a first plan.
    public mutating func setResidentCount(_ count: Int, context: LifeContext) -> [Int: BehaviorPlan] {
        var plans: [Int: BehaviorPlan] = [:]
        if residents.count > count { residents.removeLast(residents.count - count) }
        while residents.count < count {
            let index = residents.count
            residents.append(ResidentMind(index: index, home: Self.home(forResident: index)))
            plans.merge(nextPlans(finished: index, context: context)) { _, new in new }
        }
        return plans
    }

    /// Resident `index` finished its plan. Returns new plans — usually just for `index`,
    /// but socializing also pulls in a partner.
    public mutating func nextPlans(finished index: Int, context: LifeContext) -> [Int: BehaviorPlan] {
        guard residents.indices.contains(index) else { return [:] }
        var weights = ResidentBehaviorRules.weights(for: context, residentCount: residents.count)
        // No immediate repeats during the day (staying home at night is fine).
        if let last = residents[index].lastActivity, last != .returningHome, weights.count > 1 {
            weights[last] = nil
        }
        let partner = availablePartner(for: index)
        if partner == nil { weights[.socializing] = nil } // nobody free to chat: choose something else
        let activity = pick(weights) ?? .walking

        if activity == .socializing, let partner {
            let duration = randomDuration(.socializing)
            let a = BehaviorPlan(activity: .socializing, spot: .plaza, duration: duration, partner: partner)
            let b = BehaviorPlan(activity: .socializing, spot: .plaza, duration: duration, partner: index)
            assign(a, to: index)
            assign(b, to: partner)
            return [index: a, partner: b]
        }
        let plan = BehaviorPlan(activity: activity, spot: spot(for: activity, resident: index, context: context),
                                duration: randomDuration(activity))
        assign(plan, to: index)
        return [index: plan]
    }

    /// Everyone who's awake meets at the plaza (gathering event, festival).
    public mutating func gatherEveryone(duration: TimeInterval, celebrating: Bool) -> [Int: BehaviorPlan] {
        var plans: [Int: BehaviorPlan] = [:]
        let activity: ResidentActivity = celebrating ? .celebrating : .socializing
        for index in residents.indices {
            let partner = residents.count > 1 ? (index + 1) % residents.count : nil
            let plan = BehaviorPlan(activity: activity, spot: .plaza, duration: duration, partner: partner)
            assign(plan, to: index)
            plans[index] = plan
        }
        return plans
    }

    /// One free resident goes to greet a visitor at the plaza.
    public mutating func greetVisitor(duration: TimeInterval) -> [Int: BehaviorPlan] {
        guard let index = residents.indices.first(where: { isInterruptible(residents[$0]) }) else { return [:] }
        let plan = BehaviorPlan(activity: .socializing, spot: .plaza, duration: duration)
        assign(plan, to: index)
        return [index: plan]
    }

    // MARK: Private

    private mutating func assign(_ plan: BehaviorPlan, to index: Int) {
        residents[index].plan = plan
        residents[index].lastActivity = plan.activity
    }

    private func isInterruptible(_ mind: ResidentMind) -> Bool {
        guard let activity = mind.plan?.activity else { return true }
        return activity == .walking || activity == .idle || activity == .sitting
    }

    private func availablePartner(for index: Int) -> Int? {
        residents.indices.first { $0 != index && isInterruptible(residents[$0]) }
    }

    private mutating func spot(for activity: ResidentActivity, resident index: Int, context: LifeContext) -> TownSpot {
        let home = residents[index].home
        switch activity {
        case .walking, .idle:
            return .wander(Int(rng.next() % UInt64(TownSpot.wanderCount)))
        case .sitting:
            guard !context.seatSlots.isEmpty else { return .wander(0) }
            return .seat(slot: context.seatSlots[Int(rng.next() % UInt64(context.seatSlots.count))])
        case .working:
            return context.features.contains(.workshop) ? .workshop : .home(home)
        case .returningHome:
            return .home(home)
        case .reading: return .readingNook
        case .admiringFlowers: return .artGarden
        case .celebrating, .socializing: return .plaza
        }
    }

    private mutating func randomDuration(_ activity: ResidentActivity) -> TimeInterval {
        let range = activity.durationRange
        let unit = Double(rng.next() % 10_000) / 10_000
        return range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }

    private mutating func pick(_ weights: [ResidentActivity: Double]) -> ResidentActivity? {
        // Iterate in a fixed order so results are deterministic for a given seed.
        let entries = ResidentActivity.allCases.compactMap { a in weights[a].map { (a, $0) } }.filter { $0.1 > 0 }
        let total = entries.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return nil }
        var roll = Double(rng.next() % 1_000_000) / 1_000_000 * total
        for (activity, weight) in entries {
            if roll < weight { return activity }
            roll -= weight
        }
        return entries.last?.0
    }
}
