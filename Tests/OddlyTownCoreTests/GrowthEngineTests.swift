import XCTest
@testable import OddlyTownCore

final class GrowthEngineTests: XCTestCase {
    let hour = GrowthRules.hour
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    func testLevelsFollowThresholds() {
        let engine = GrowthEngine()
        XCTAssertEqual(engine.level(of: TownState(growthSeconds: 0)), 1)
        XCTAssertEqual(engine.level(of: TownState(growthSeconds: 2 * hour - 1)), 1)
        XCTAssertEqual(engine.level(of: TownState(growthSeconds: 2 * hour)), 2)
        XCTAssertEqual(engine.level(of: TownState(growthSeconds: 6 * hour)), 3)
        XCTAssertEqual(engine.level(of: TownState(growthSeconds: 100 * hour)), 3)
    }

    func testAdvancingAccumulatesUntilDailyCap() {
        let engine = GrowthEngine()
        var state = TownState()
        for minute in 0..<240 {  // four hours of one-minute ticks on the same day
            state = engine.advancing(state, by: 60, now: date(1, 9, 0).addingTimeInterval(Double(minute) * 60), calendar: calendar)
        }
        XCTAssertEqual(state.growthSeconds, 3 * hour, accuracy: 0.001, "daily cap is 3h")
        XCTAssertEqual(engine.remainingToday(state, now: date(1, 13), calendar: calendar), 0)
        XCTAssertEqual(engine.level(of: state), 2)
    }

    func testDailyCapResetsOnNextDay() {
        let engine = GrowthEngine()
        var state = engine.advancing(TownState(), by: 5 * hour, now: date(1, 10), calendar: calendar)
        XCTAssertEqual(state.growthSeconds, 3 * hour)
        state = engine.advancing(state, by: 5 * hour, now: date(2, 10), calendar: calendar)
        XCTAssertEqual(state.growthSeconds, 6 * hour)
        XCTAssertEqual(state.capDay, "2026-10-02")
        XCTAssertEqual(engine.level(of: state), 3)
    }

    func testDailyCapCanBeBypassedForDeveloperMode() {
        let engine = GrowthEngine()
        let state = engine.advancing(TownState(), by: 10 * hour, now: date(1, 10), calendar: calendar, applyDailyCap: false)
        XCTAssertEqual(state.growthSeconds, 10 * hour)
    }

    func testInvalidDurationsAreIgnored() {
        let engine = GrowthEngine()
        let state = TownState(growthSeconds: 100)
        XCTAssertEqual(engine.advancing(state, by: -50, now: date(1, 10), calendar: calendar), state)
        XCTAssertEqual(engine.advancing(state, by: .nan, now: date(1, 10), calendar: calendar), state)
        XCTAssertEqual(engine.recordingActivity(state, category: .creative, seconds: -1), state)
    }

    func testProgress() {
        let engine = GrowthEngine()
        let p1 = engine.progress(of: TownState(growthSeconds: hour))
        XCTAssertEqual(p1.level, 1)
        XCTAssertEqual(p1.fractionToNext, 0.5, accuracy: 0.0001)
        XCTAssertEqual(p1.secondsToNext, hour)

        let p2 = engine.progress(of: TownState(growthSeconds: 4 * hour))
        XCTAssertEqual(p2.level, 2)
        XCTAssertEqual(p2.fractionToNext, 0.5, accuracy: 0.0001)

        let p3 = engine.progress(of: TownState(growthSeconds: 7 * hour))
        XCTAssertEqual(p3.level, 3)
        XCTAssertEqual(p3.fractionToNext, 1)
        XCTAssertNil(p3.secondsToNext)
    }

    func testLevelFeatures() {
        let engine = GrowthEngine()
        XCTAssertTrue(engine.unlockedFeatures(of: TownState()).isEmpty)
        let l2 = engine.unlockedFeatures(of: TownState(growthSeconds: 2 * hour))
        XCTAssertTrue(l2.isSuperset(of: [.youngTree, .wildflowers, .lamppost, .secondResident]))
        XCTAssertFalse(l2.contains(.secondHouse))
        let l3 = engine.unlockedFeatures(of: TownState(growthSeconds: 6 * hour))
        XCTAssertTrue(l3.isSuperset(of: [.youngTree, .secondHouse, .well]))
    }

    func testDifferentCategoriesUnlockDifferentFeatures() {
        let engine = GrowthEngine()
        let base = TownState(growthSeconds: 2 * hour)

        let dev = engine.recordingActivity(base, category: .development, seconds: hour)
        let creative = engine.recordingActivity(base, category: .creative, seconds: hour)
        let fun = engine.recordingActivity(base, category: .entertainment, seconds: hour)
        let docs = engine.recordingActivity(base, category: .productivity, seconds: hour)

        XCTAssertTrue(engine.unlockedFeatures(of: dev).contains(.workshop))
        XCTAssertFalse(engine.unlockedFeatures(of: dev).contains(.artGarden))
        XCTAssertTrue(engine.unlockedFeatures(of: creative).contains(.artGarden))
        XCTAssertFalse(engine.unlockedFeatures(of: creative).contains(.workshop))
        XCTAssertTrue(engine.unlockedFeatures(of: fun).contains(.festivalBunting))
        XCTAssertTrue(engine.unlockedFeatures(of: docs).contains(.readingNook))
    }

    func testOtherCategoryOnlyFeedsGeneralGrowth() {
        let engine = GrowthEngine()
        let state = engine.recordingActivity(TownState(growthSeconds: 6 * hour), category: .other, seconds: 100 * hour)
        let activityFeatures: Set<TownFeature> = [.workshop, .artGarden, .readingNook, .festivalBunting]
        XCTAssertTrue(engine.unlockedFeatures(of: state).isDisjoint(with: activityFeatures))
    }

    func testActivityUnlockRespectsMinimumLevel() {
        let engine = GrowthEngine()
        let lowLevel = engine.recordingActivity(TownState(), category: .development, seconds: 10 * hour)
        XCTAssertFalse(engine.unlockedFeatures(of: lowLevel).contains(.workshop), "workshop needs level 2")
        let creative = engine.recordingActivity(TownState(), category: .creative, seconds: hour)
        XCTAssertTrue(engine.unlockedFeatures(of: creative).contains(.artGarden), "art garden allowed at level 1")
    }

    func testGrowthWorksWithTrackingDisabled() {
        // No activity is ever recorded; time alone must still reach max level.
        let engine = GrowthEngine()
        var state = TownState()
        for day in 1...3 {
            state = engine.advancing(state, by: 3 * hour, now: date(day, 12), calendar: calendar)
        }
        XCTAssertEqual(engine.level(of: state), 3)
        XCTAssertTrue(state.activitySeconds.isEmpty)
    }
}
