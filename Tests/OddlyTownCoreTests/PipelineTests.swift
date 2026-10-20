import XCTest
@testable import OddlyTownCore

/// Drives accumulator + engine + store the same way AppController does, minute by minute.
final class PipelineTests: XCTestCase {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    func testDurationText() {
        XCTAssertEqual(DurationText.short(10), "<1m")
        XCTAssertEqual(DurationText.short(45 * 60), "45m")
        XCTAssertEqual(DurationText.short(2 * 3600 + 5 * 60), "2h 5m")
        XCTAssertEqual(DurationText.short(.infinity), "<1m")
    }

    /// Three days of 4-hour sessions: 2h in a code editor, 2h in Figma.
    func testSimulatedWeekGrowsDifferentlyByCategory() throws {
        let engine = GrowthEngine()
        let classifier = ActivityClassifier()
        var state = TownState()
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 9))!

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

        XCTAssertEqual(state.growthSeconds, 9 * 3600, accuracy: 1, "3h daily cap × 3 days")
        XCTAssertEqual(engine.level(of: state), 3)
        XCTAssertEqual(state.activitySeconds(for: .development), 6 * 3600, accuracy: 180)
        XCTAssertEqual(state.activitySeconds(for: .creative), 6 * 3600, accuracy: 180)
        let features = engine.unlockedFeatures(of: state)
        XCTAssertTrue(features.isSuperset(of: [.workshop, .artGarden, .secondHouse, .well]))
        XCTAssertFalse(features.contains(.readingNook))
        XCTAssertFalse(features.contains(.festivalBunting))

        // Survives a save/restore cycle unchanged.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pipeline-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = JSONFileStore<TownState>(url: url)
        try store.save(state)
        let restored = try XCTUnwrap(store.load().value)
        XCTAssertEqual(engine.unlockedFeatures(of: restored), features)
        XCTAssertEqual(restored.growthSeconds, state.growthSeconds, accuracy: 0.001)
    }
}
