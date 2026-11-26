import Foundation
import Testing
@testable import OddlyTownCore

@Suite struct WeatherTests {
    let calendar = TestSupport.utc
    let seed: UInt64 = 0x0DD1_7041

    private func day(_ offset: Int, hour: Int = 12) -> Date {
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: hour))!
        return calendar.date(byAdding: .day, value: offset, to: start)!
    }

    @Test func sameDayAndSeedGiveTheSameShower() {
        for offset in 0..<200 {
            let a = WeatherForecast.shower(on: day(offset, hour: 3), season: .autumn, seed: seed, calendar: calendar)
            let b = WeatherForecast.shower(on: day(offset, hour: 22), season: .autumn, seed: seed, calendar: calendar)
            #expect(a == b, "day \(offset): the forecast must not depend on the time of day it's asked")
        }
    }

    @Test func differentTownsGetDifferentWeather() {
        let a = (0..<120).map { WeatherForecast.shower(on: day($0), season: .autumn, seed: 1, calendar: calendar) != nil }
        let b = (0..<120).map { WeatherForecast.shower(on: day($0), season: .autumn, seed: 2, calendar: calendar) != nil }
        #expect(a != b)
    }

    @Test func showerDaysMatchTheSeasonalChance() {
        let days = 3000
        for (season, chance) in WeatherRules.standard.showerChance {
            let wet = (0..<days).filter { WeatherForecast.shower(on: day($0), season: season, seed: seed, calendar: calendar) != nil }.count
            let rate = Double(wet) / Double(days)
            #expect(abs(rate - chance) < 0.03, "\(season): \(rate) vs \(chance)")
        }
    }

    @Test func showersStayWithinTheDay() {
        let rules = WeatherRules.standard
        for offset in 0..<1000 {
            guard let shower = WeatherForecast.shower(on: day(offset), season: .spring, seed: seed, calendar: calendar) else { continue }
            let startHour = calendar.component(.hour, from: shower.start)
            #expect(rules.startHours.contains(startHour))
            let hours = Int(shower.duration / 3600)
            #expect(rules.durationHours.contains(hours))
            #expect(calendar.isDate(shower.end.addingTimeInterval(-1), inSameDayAs: shower.start))
        }
    }

    @Test func snowInWinterRainOtherwiseClearOutsideTheShower() throws {
        let offset = try #require((0..<365).first {
            WeatherForecast.shower(on: day($0), season: .winter, seed: seed, calendar: calendar) != nil
        })
        let shower = try #require(WeatherForecast.shower(on: day(offset), season: .winter, seed: seed, calendar: calendar))
        let during = shower.start.addingTimeInterval(60)
        #expect(WeatherForecast.weather(at: during, season: .winter, seed: seed, calendar: calendar) == .snow)
        #expect(WeatherForecast.weather(at: shower.start.addingTimeInterval(-60), season: .winter, seed: seed, calendar: calendar) == .clear)
        #expect(WeatherForecast.weather(at: shower.end, season: .winter, seed: seed, calendar: calendar) == .clear)
        // Same day in autumn uses the autumn chance, so look up a wet autumn day separately.
        let autumnDay = try #require((0..<365).first {
            WeatherForecast.shower(on: day($0), season: .autumn, seed: seed, calendar: calendar) != nil
        })
        let autumn = try #require(WeatherForecast.shower(on: day(autumnDay), season: .autumn, seed: seed, calendar: calendar))
        #expect(WeatherForecast.weather(at: autumn.start, season: .autumn, seed: seed, calendar: calendar) == .rain)
    }

    @Test func daylightSavingDaysWork() {
        var berlin = Calendar(identifier: .gregorian)
        berlin.timeZone = TimeZone(identifier: "Europe/Berlin")!
        for date in [DateComponents(year: 2026, month: 3, day: 29, hour: 12), DateComponents(year: 2026, month: 10, day: 25, hour: 12)] {
            let noon = berlin.date(from: date)!
            for s in 0..<50 as Range<UInt64> {
                if let shower = WeatherForecast.shower(on: noon, season: .spring, seed: s, calendar: berlin) {
                    #expect(shower.duration >= 3600)
                }
            }
        }
    }

    @Test func snapshotCarriesWeatherAndBothModesAgree() throws {
        let engine = GrowthEngine(rules: .standard)
        let state = TownState(createdAt: Date(timeIntervalSince1970: 1_790_000_000))
        let winter = (0..<90).map { calendar.date(byAdding: .day, value: $0, to: calendar.date(from: DateComponents(year: 2026, month: 12, day: 1))!)! }
        let wetDay = try #require(winter.first {
            WeatherForecast.shower(on: $0, season: .winter, seed: state.weatherSeed, calendar: calendar) != nil
        })
        let shower = try #require(WeatherForecast.shower(on: wetDay, season: .winter, seed: state.weatherSeed, calendar: calendar))
        let during = shower.start.addingTimeInterval(600)
        let ambient = TownSnapshot.make(state: state, engine: engine, now: during, calendar: calendar)
        let townMode = TownSnapshot.make(state: state, engine: engine, now: during, calendar: calendar)
        #expect(ambient.weather == .snow)
        #expect(ambient == townMode)
    }
}

@Suite struct WeatherBehaviourTests {
    private func context(_ weather: Weather, phase: DayPhase = .day, season: Season = .autumn) -> LifeContext {
        LifeContext(phase: phase, lateNight: false, features: [.artGarden, .festivalBunting], seatSlots: [0],
                    season: season, weather: weather)
    }

    @Test func rainKeepsPeopleIn() {
        let clear = ResidentBehaviorRules.weights(for: context(.clear), residentCount: 3)
        let rain = ResidentBehaviorRules.weights(for: context(.rain), residentCount: 3)
        #expect((rain[.walking] ?? 0) < (clear[.walking] ?? 0))
        #expect((rain[.admiringFlowers] ?? 0) < (clear[.admiringFlowers] ?? 0))
        #expect((rain[.returningHome] ?? 0) > (clear[.returningHome] ?? 0))
    }

    @Test func snowIsGentlerThanRain() {
        let rain = ResidentBehaviorRules.weights(for: context(.rain), residentCount: 3)
        let snow = ResidentBehaviorRules.weights(for: context(.snow), residentCount: 3)
        #expect((snow[.walking] ?? 0) > (rain[.walking] ?? 0))
        #expect((snow[.returningHome] ?? 0) < (rain[.returningHome] ?? 0))
    }

    @Test func rainyDaysAreSpentMostlyIndoors() {
        func homeShare(_ weather: Weather) -> Double {
            var life = TownLife(seed: 7)
            let ctx = context(weather)
            _ = life.setResidentCount(3, context: ctx)
            var home = 0, total = 0
            for step in 0..<600 {
                for (_, plan) in life.nextPlans(finished: step % 3, context: ctx) {
                    total += 1
                    if plan.activity == .returningHome { home += 1 }
                }
            }
            return Double(home) / Double(total)
        }
        #expect(homeShare(.rain) > homeShare(.clear) + 0.2)
    }

    @Test func winterEveningsEndEarlier() {
        let autumn = ResidentBehaviorRules.weights(for: context(.clear, phase: .dusk, season: .autumn), residentCount: 3)
        let winter = ResidentBehaviorRules.weights(for: context(.clear, phase: .dusk, season: .winter), residentCount: 3)
        #expect((winter[.returningHome] ?? 0) > (autumn[.returningHome] ?? 0))
    }

    @Test func lateNightIsUnchanged() {
        let ctx = LifeContext(phase: .night, lateNight: true, features: [], seatSlots: [], season: .winter, weather: .snow)
        #expect(ResidentBehaviorRules.weights(for: ctx, residentCount: 3) == [.returningHome: 1])
    }

    @Test func eventsWaitForTheWeather() {
        let scheduler = EventScheduler(start: Date())
        func kinds(_ weather: Weather) -> Set<TownEventKind> {
            Set(scheduler.eligibleRules(for: EventContext(level: 3, phase: .day, lateNight: false, residentCount: 3,
                                                          isVisible: true, weather: weather)).map(\.kind))
        }
        #expect(kinds(.clear) == [.strayCat, .traveler, .gathering])
        #expect(kinds(.rain).isEmpty)
        #expect(kinds(.snow) == [.traveler, .gathering])
    }
}
