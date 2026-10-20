import Foundation
import Testing
@testable import OddlyTownCore

/// Drives accumulator + engine + store the same way AppController does, minute by minute.
@Suite struct PipelineTests {
    @Test func durationText() {
        #expect(DurationText.short(10) == "<1m")
        #expect(DurationText.short(45 * 60) == "45m")
        #expect(DurationText.short(2 * 3600 + 5 * 60) == "2h 5m")
        #expect(DurationText.short(.infinity) == "<1m")
    }

    /// Three days of 4-hour sessions: 2h in a code editor, 2h in Figma.
    @Test func simulatedDaysGrowDifferentlyByCategory() throws {
        let engine = GrowthEngine()
        let classifier = ActivityClassifier()
        let calendar = TestSupport.utc
        var state = TownState()
        let start = TestSupport.date(day: 19, hour: 9)

        for day in 0..<3 {
            var accumulator = ActivityAccumulator()
            let sessionStart = start.addingTimeInterval(Double(day) * 86_400)
            for minute in 0..<240 {
                let now = sessionStart.addingTimeInterval(Double(minute) * 60)
                if minute == 0 {
                    _ = accumulator.switchTo(classifier.category(forBundleID: "com.microsoft.VSCode"), at: now)
                } else if minute == 120, let credit = accumulator.switchTo(classifier.category(forBundleID: "com.figma.Desktop"), at: now) {
                    state = engine.recordingActivity(state, category: credit.category, seconds: credit.seconds)
                }
                state = engine.advancing(state, by: 60, now: now, calendar: calendar)
                if let credit = accumulator.checkpoint(at: now, isIdle: false) {
                    state = engine.recordingActivity(state, category: credit.category, seconds: credit.seconds)
                }
            }
        }

        #expect(TestSupport.isClose(state.growthSeconds, 9 * 3600, 1), "3h daily cap × 3 days")
        #expect(engine.level(of: state) == 3)
        #expect(TestSupport.isClose(state.activitySeconds(for: .development), 6 * 3600, 180))
        #expect(TestSupport.isClose(state.activitySeconds(for: .creative), 6 * 3600, 180))
        let features = engine.unlockedFeatures(of: state)
        #expect(features.isSuperset(of: [.workshop, .artGarden, .secondHouse, .well]))
        #expect(!features.contains(.readingNook))
        #expect(!features.contains(.festivalBunting))

        // Survives a save/restore cycle unchanged.
        try TestSupport.withTempDirectory { dir in
            let store = JSONFileStore<TownState>(url: dir.appendingPathComponent("town.json"))
            try store.save(state)
            let restored = try #require(store.load().value)
            #expect(engine.unlockedFeatures(of: restored) == features)
            #expect(TestSupport.isClose(restored.growthSeconds, state.growthSeconds))
        }
    }
}
