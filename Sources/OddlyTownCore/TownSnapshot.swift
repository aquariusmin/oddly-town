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
/// Ambient Mode and Town Mode render the same snapshot, so both always show the same town.
public struct TownSnapshot: Equatable, Sendable {
    public var level: Int
    /// Unlocked features minus the ones the user hid.
    public var features: Set<TownFeature>
    public var phase: DayPhase
    /// 23:00–05:00: houses turn their lights off, the lamppost stays on.
    public var lateNight: Bool
    /// Slot → decoration, only items the level allows.
    public var decor: [Int: DecorItem]
    /// From the real calendar (or Demo). Never saved: it's worked out from the date.
    public var season: Season
    /// Worked out from the date, season and the town's seed (`WeatherForecast`). Never saved.
    public var weather: Weather

    public init(level: Int, features: Set<TownFeature>, phase: DayPhase, lateNight: Bool = false,
                decor: [Int: DecorItem] = [:], season: Season = .summer, weather: Weather = .clear) {
        self.level = level
        self.features = features
        self.phase = phase
        self.lateNight = lateNight
        self.decor = decor
        self.season = season
        self.weather = weather
    }

    /// The one place real state turns into what's drawn.
    public static func make(state: TownState, engine: GrowthEngine, now: Date, calendar: Calendar = .current,
                            seasons: SeasonSetting = .automatic) -> TownSnapshot {
        let level = engine.level(of: state)
        let season = seasons.season(at: now, calendar: calendar)
        return make(level: level, features: engine.unlockedFeatures(of: state), decor: state.decor,
                    phase: DayPhase.at(now, calendar: calendar), lateNight: isLateNight(now, calendar: calendar),
                    season: season,
                    weather: WeatherForecast.weather(at: now, season: season, seed: state.weatherSeed, calendar: calendar))
    }

    public static func make(level: Int, features: Set<TownFeature>, decor: DecorLayout,
                            phase: DayPhase, lateNight: Bool, season: Season = .summer,
                            weather: Weather = .clear) -> TownSnapshot {
        TownSnapshot(level: level, features: features.subtracting(decor.hiddenFeatures), phase: phase,
                     lateNight: lateNight, decor: decor.visibleItems(level: level), season: season, weather: weather)
    }

    public var residentCount: Int {
        1 + (features.contains(.secondResident) ? 1 : 0) + (features.contains(.thirdResident) ? 1 : 0)
    }

    public var seatSlots: [Int] {
        decor.filter { $0.value.isSeat }.keys.sorted()
    }

    public static func isLateNight(_ date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= 23 || hour < 5
    }
}
