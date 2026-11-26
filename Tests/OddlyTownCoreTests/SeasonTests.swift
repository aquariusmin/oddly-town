import Foundation
import Testing
@testable import OddlyTownCore

@Suite struct SeasonTests {
    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, in calendar: Calendar = TestSupport.utc) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func calendar(_ zone: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: zone)!
        return c
    }

    @Test func northernMonths() {
        let expected: [Int: Season] = [1: .winter, 2: .winter, 3: .spring, 4: .spring, 5: .spring, 6: .summer,
                                       7: .summer, 8: .summer, 9: .autumn, 10: .autumn, 11: .autumn, 12: .winter]
        for (month, season) in expected {
            #expect(Season.at(date(2026, month, 15), hemisphere: .northern, calendar: TestSupport.utc) == season, "month \(month)")
        }
    }

    @Test func southernIsSixMonthsOn() {
        for month in 1...12 {
            let north = Season.at(date(2026, month, 15), hemisphere: .northern, calendar: TestSupport.utc)
            let south = Season.at(date(2026, (month + 5) % 12 + 1, 15), hemisphere: .southern, calendar: TestSupport.utc)
            #expect(north == south, "month \(month)")
        }
        #expect(Season.at(date(2026, 12, 25), hemisphere: .southern, calendar: TestSupport.utc) == .summer)
        #expect(Season.at(date(2026, 7, 1), hemisphere: .southern, calendar: TestSupport.utc) == .winter)
    }

    /// Winter starts at local midnight on 1 December, not UTC midnight.
    @Test func boundaryUsesTheLocalCalendar() {
        let seoul = calendar("Asia/Seoul")
        let lastAutumnMinute = seoul.date(from: DateComponents(year: 2026, month: 11, day: 30, hour: 23, minute: 59))!
        let firstWinterMinute = seoul.date(from: DateComponents(year: 2026, month: 12, day: 1, hour: 0, minute: 0))!
        #expect(Season.at(lastAutumnMinute, hemisphere: .northern, calendar: seoul) == .autumn)
        #expect(Season.at(firstWinterMinute, hemisphere: .northern, calendar: seoul) == .winter)
        // Same instant, still 30 November in UTC.
        #expect(Season.at(firstWinterMinute, hemisphere: .northern, calendar: TestSupport.utc) == .autumn)
    }

    @Test func hemisphereGuess() {
        for zone in ["Australia/Sydney", "Australia/Perth", "Pacific/Auckland", "America/Argentina/Buenos_Aires",
                     "America/Sao_Paulo", "America/Santiago", "Africa/Johannesburg", "Asia/Jakarta"] {
            #expect(Hemisphere.guess(from: TimeZone(identifier: zone)!) == .southern, "\(zone)")
        }
        for zone in ["Asia/Seoul", "Asia/Tokyo", "Europe/London", "America/New_York", "America/Los_Angeles",
                     "Asia/Singapore", "Africa/Cairo", "UTC"] {
            #expect(Hemisphere.guess(from: TimeZone(identifier: zone)!) == .northern, "\(zone)")
        }
    }

    @Test func settingPicksTheSeason() {
        let sydney = calendar("Australia/Sydney")
        let december = date(2026, 12, 15, in: sydney)
        #expect(SeasonSetting.automatic.season(at: december, calendar: sydney) == .summer)
        #expect(SeasonSetting.northern.season(at: december, calendar: sydney) == .winter)
        #expect(SeasonSetting.southern.season(at: december, calendar: sydney) == .summer)
        #expect(SeasonSetting.off.season(at: december, calendar: sydney) == .summer)
        #expect(SeasonSetting.off.hemisphere(timeZone: sydney.timeZone) == nil)
        let seoul = calendar("Asia/Seoul")
        #expect(SeasonSetting.automatic.season(at: date(2026, 12, 15, in: seoul), calendar: seoul) == .winter)
    }

    @Test func snapshotCarriesTheSeason() {
        let engine = GrowthEngine(rules: .standard)
        let state = TownState()
        let december = date(2026, 12, 2)
        #expect(TownSnapshot.make(state: state, engine: engine, now: december, calendar: TestSupport.utc).season == .winter)
        #expect(TownSnapshot.make(state: state, engine: engine, now: december, calendar: TestSupport.utc,
                                  seasons: .off).season == .summer)
        // Two modes rendering at the same moment agree, season included.
        #expect(TownSnapshot.make(state: state, engine: engine, now: december, calendar: TestSupport.utc)
                == TownSnapshot.make(state: state, engine: engine, now: december, calendar: TestSupport.utc))
    }

    @Test func settingsDecodeSeasonsLeniently() throws {
        let decoder = JSONDecoder()
        // 0.2 files have no "seasons" key.
        let old = try decoder.decode(AppSettings.self, from: Data(#"{"schemaVersion": 2, "windowWidth": 420}"#.utf8))
        #expect(old.seasons == .automatic)
        #expect(old.windowWidth == 420)
        let unknown = try decoder.decode(AppSettings.self, from: Data(#"{"schemaVersion": 2, "seasons": "monsoon"}"#.utf8))
        #expect(unknown.seasons == .automatic)
        var settings = AppSettings()
        settings.seasons = .southern
        let roundTrip = try decoder.decode(AppSettings.self, from: JSONEncoder().encode(settings))
        #expect(roundTrip.seasons == .southern)
    }

    @Test func winterPresetExists() {
        let winter = CapturePreset.all.first { $0.season == .winter }
        #expect(winter?.phase == .night)
        #expect(CapturePreset.all.filter { $0.season != nil }.count >= 1)
    }
}
