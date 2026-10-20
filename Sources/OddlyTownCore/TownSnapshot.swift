import Foundation

public enum DayPhase: String, CaseIterable, Codable, Sendable {
    case dawn, day, dusk, night

    /// dawn 05:00–07:00, day 07:00–17:30, dusk 17:30–19:30, night otherwise.
    public static func at(_ date: Date, calendar: Calendar = .current) -> DayPhase {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (c.hour ?? 12) * 60 + (c.minute ?? 0)
        switch minutes {
        case 300..<420: return .dawn
        case 420..<1050: return .day
        case 1050..<1170: return .dusk
        default: return .night
        }
    }

    public var lightsOn: Bool { self == .dusk || self == .night }
}

/// Everything the renderer needs to draw the town. Built from real state or from Demo Mode.
public struct TownSnapshot: Equatable, Sendable {
    public var level: Int
    public var features: Set<TownFeature>
    public var phase: DayPhase
    /// 23:00–05:00: houses turn their lights off, the lamppost stays on.
    public var lateNight: Bool

    public init(level: Int, features: Set<TownFeature>, phase: DayPhase, lateNight: Bool = false) {
        self.level = level
        self.features = features
        self.phase = phase
        self.lateNight = lateNight
    }

    public static func isLateNight(_ date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= 23 || hour < 5
    }
}
