import Foundation
import Testing
@testable import OddlyTownCore

@Suite struct JournalTests {
    let calendar = TestSupport.utc
    let names = ["Mori", "Pip", "Juno"]

    private func at(day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        TestSupport.date(day: day, hour: hour, minute: minute)
    }

    @Test func sameMomentIsWrittenOncePerDay() {
        var journal = Journal()
        #expect(journal.record(.event(.strayCat, festive: false), at: at(day: 1, hour: 9), names: names, calendar: calendar) != nil)
        #expect(journal.record(.event(.strayCat, festive: false), at: at(day: 1, hour: 15), names: names, calendar: calendar) == nil)
        #expect(journal.record(.event(.strayCat, festive: false), at: at(day: 2, hour: 9), names: names, calendar: calendar) != nil)
        // A chat between the same two people, either order, is the same moment.
        #expect(journal.record(.chat(0, 1), at: at(day: 2, hour: 10), names: names, calendar: calendar) != nil)
        #expect(journal.record(.chat(1, 0), at: at(day: 2, hour: 11), names: names, calendar: calendar) == nil)
        #expect(journal.record(.chat(1, 2), at: at(day: 2, hour: 11), names: names, calendar: calendar) != nil)
    }

    @Test func everydayLinesAreCappedButMilestonesAlwaysGetIn() {
        var journal = Journal()
        let everyday: [JournalMoment] = [.event(.strayCat, festive: false), .event(.traveler, festive: false),
                                         .event(.gathering, festive: false), .chat(0, 1), .chat(1, 2), .chat(0, 2),
                                         .shower(.rain, firstSnow: false)]
        for (i, moment) in everyday.enumerated() {
            journal.record(moment, at: at(day: 3, hour: 8 + i), names: names, calendar: calendar)
        }
        #expect(journal.entries(on: at(day: 3), calendar: calendar).count == Journal.everydayLimit)
        #expect(journal.record(.levelUp(2), at: at(day: 3, hour: 20), names: names, calendar: calendar) != nil)
        #expect(journal.record(.arrived(.workshop), at: at(day: 3, hour: 21), names: names, calendar: calendar) != nil)
        #expect(journal.entries(on: at(day: 3), calendar: calendar).count == Journal.everydayLimit + 2)
    }

    @Test func onlyTheLastSixtyDaysAreKept() {
        var journal = Journal()
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12))!
        for d in 0..<100 {
            journal.record(.event(.strayCat, festive: false), at: calendar.date(byAdding: .day, value: d, to: start)!,
                           names: names, calendar: calendar)
        }
        #expect(journal.days.count == Journal.keepDays)
        #expect(journal.recent(1).first?.day == "2026-04-10") // day 99 after 1 January
    }

    @Test func textNamesResidentsAndNeverMentionsApps() {
        let all: [JournalMoment] = TownEventKind.allCases.flatMap { [.event($0, festive: false), .event($0, festive: true)] }
            + (2...3).map { .levelUp($0) } + TownFeature.allCases.map { .arrived($0) }
            + Season.allCases.map { .seasonBegan($0) }
            + [.shower(.rain, firstSnow: false), .shower(.snow, firstSnow: false), .shower(.snow, firstSnow: true),
               .chat(0, 1), .chat(2, 0)]
        for moment in all {
            for variant in 0..<6 as Range<UInt64> {
                let text = moment.text(names: names, variant: variant)
                #expect(!text.isEmpty)
                #expect(text.hasSuffix(".") || text.hasSuffix("!"), "\(text)")
                let words = Set(text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
                for word in ["development", "creative", "productivity", "entertainment", "app", "apps", "xcode"] {
                    #expect(!words.contains(word), "\(moment): \(text)")
                }
            }
        }
        #expect(JournalMoment.chat(2, 0).text(names: names, variant: 0).contains("Mori"))
        #expect(JournalMoment.chat(2, 0).text(names: names, variant: 0).contains("Juno"))
        #expect(JournalMoment.arrived(.thirdResident).text(names: names, variant: 0) == "Juno moved into the blue house.")
    }

    @Test func wordingIsStableForTheSameDay() {
        var a = Journal(), b = Journal()
        let x = a.record(.chat(0, 1), at: at(day: 5, hour: 9), names: names, calendar: calendar)
        let y = b.record(.chat(0, 1), at: at(day: 5, hour: 17), names: names, calendar: calendar)
        #expect(x?.text == y?.text)
    }

    @Test func seasonIsNoticedOnceAndNotOnFirstLaunch() {
        var journal = Journal()
        #expect(journal.noteSeason(.autumn) == nil)
        #expect(journal.noteSeason(.autumn) == nil)
        #expect(journal.noteSeason(.winter) == .seasonBegan(.winter))
        #expect(journal.noteSeason(.winter) == nil)
    }

    @Test func firstSnowOncePerWinter() {
        var journal = Journal()
        _ = journal.noteSeason(.autumn)
        _ = journal.noteSeason(.winter)
        var watcher = JournalWatcher()
        _ = watcher.changes(level: 3, unlocked: [], weather: .clear, snowedThisSeason: journal.snowedThisSeason)
        let first = watcher.changes(level: 3, unlocked: [], weather: .snow, snowedThisSeason: journal.snowedThisSeason)
        #expect(first == [.shower(.snow, firstSnow: true)])
        journal.record(first[0], at: at(day: 6), names: names, calendar: calendar)
        _ = watcher.changes(level: 3, unlocked: [], weather: .clear, snowedThisSeason: journal.snowedThisSeason)
        let second = watcher.changes(level: 3, unlocked: [], weather: .snow, snowedThisSeason: journal.snowedThisSeason)
        #expect(second == [.shower(.snow, firstSnow: false)])
        // Next winter starts fresh.
        _ = journal.noteSeason(.spring)
        _ = journal.noteSeason(.winter)
        #expect(journal.snowedThisSeason == false)
    }

    @Test func watcherReportsGrowthButNothingOnTheFirstLook() {
        var watcher = JournalWatcher()
        #expect(watcher.changes(level: 3, unlocked: [.well, .workshop], weather: .rain, snowedThisSeason: false).isEmpty)
        let grown = watcher.changes(level: 3, unlocked: [.well, .workshop, .readingNook], weather: .rain, snowedThisSeason: false)
        #expect(grown == [.arrived(.readingNook)])
        // Two levels at once (e.g. a long sleep) are both written; disappearing things aren't.
        var fresh = JournalWatcher()
        _ = fresh.changes(level: 1, unlocked: [.workshop], weather: .clear, snowedThisSeason: false)
        let jump = fresh.changes(level: 3, unlocked: [.youngTree, .secondHouse], weather: .clear, snowedThisSeason: false)
        #expect(jump == [.levelUp(2), .levelUp(3), .arrived(.youngTree), .arrived(.secondHouse)])
        #expect(fresh.changes(level: 1, unlocked: [], weather: .clear, snowedThisSeason: false).isEmpty)
    }

    @Test func activityLinesCanBeRemoved() {
        var journal = Journal()
        journal.record(.arrived(.workshop), at: at(day: 7, hour: 9), names: names, calendar: calendar)
        journal.record(.arrived(.well), at: at(day: 7, hour: 10), names: names, calendar: calendar)
        journal.record(.arrived(.artGarden), at: at(day: 8, hour: 10), names: names, calendar: calendar)
        let activityKeys = Set(GrowthRules.standard.activityUnlocks.map { JournalMoment.arrived($0.feature).key })
        journal.removeEntries { activityKeys.contains($0.key) }
        #expect(journal.days.flatMap(\.entries).map(\.key) == ["arrived:well"])
        #expect(journal.days.count == 1)
    }

    @Test func survivesASaveAndToleratesDamage() throws {
        var journal = Journal()
        _ = journal.noteSeason(.winter)
        journal.record(.levelUp(2), at: at(day: 9), names: names, calendar: calendar)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode(Journal.self, from: encoder.encode(journal))
        #expect(restored == journal)
        let damaged = try decoder.decode(Journal.self, from: Data(#"{"days": "nope", "lastSeason": "monsoon"}"#.utf8))
        #expect(damaged.days.isEmpty)
        #expect(damaged.lastSeason == nil)
    }

    @Test func journalFileRoundTripsThroughTheStore() throws {
        try TestSupport.withTempDirectory { dir in
            let store = JSONFileStore<Journal>(url: dir.appendingPathComponent("journal.json"))
            var journal = Journal()
            journal.record(.event(.traveler, festive: false), at: at(day: 10), names: names, calendar: calendar)
            try store.save(journal)
            #expect(store.load().value == journal)
        }
    }
}
