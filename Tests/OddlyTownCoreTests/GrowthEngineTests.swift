import Foundation
import Testing
@testable import OddlyTownCore

@Suite struct GrowthEngineTests {
    let hour = GrowthRules.hour
    let calendar = TestSupport.utc
    let engine = GrowthEngine()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        TestSupport.date(day: day, hour: hour, minute: minute)
    }

    @Test func levelsFollowThresholds() {
        #expect(engine.level(of: TownState(growthSeconds: 0)) == 1)
        #expect(engine.level(of: TownState(growthSeconds: 2 * hour - 1)) == 1)
        #expect(engine.level(of: TownState(growthSeconds: 2 * hour)) == 2)
        #expect(engine.level(of: TownState(growthSeconds: 6 * hour)) == 3)
        #expect(engine.level(of: TownState(growthSeconds: 100 * hour)) == 3)
    }

    @Test func advancingAccumulatesUntilDailyCap() {
        var state = TownState()
        for minute in 0..<240 { // four hours of one-minute ticks on the same day
            state = engine.advancing(state, by: 60, now: date(1, 9).addingTimeInterval(Double(minute) * 60), calendar: calendar)
        }
        #expect(TestSupport.isClose(state.growthSeconds, 3 * hour), "daily cap is 3h")
        #expect(engine.remainingToday(state, now: date(1, 13), calendar: calendar) == 0)
        #expect(engine.level(of: state) == 2)
    }

    @Test func dailyCapResetsOnNextDay() {
        var state = engine.advancing(TownState(), by: 5 * hour, now: date(1, 10), calendar: calendar)
        #expect(state.growthSeconds == 3 * hour)
        state = engine.advancing(state, by: 5 * hour, now: date(2, 10), calendar: calendar)
        #expect(state.growthSeconds == 6 * hour)
        #expect(state.capDay == "2026-10-02")
        #expect(engine.level(of: state) == 3)
    }

    @Test func dailyCapCanBeBypassedForDeveloperMode() {
        let state = engine.advancing(TownState(), by: 10 * hour, now: date(1, 10), calendar: calendar, applyDailyCap: false)
        #expect(state.growthSeconds == 10 * hour)
    }

    @Test func invalidDurationsAreIgnored() {
        let state = TownState(growthSeconds: 100)
        #expect(engine.advancing(state, by: -50, now: date(1, 10), calendar: calendar) == state)
        #expect(engine.advancing(state, by: .nan, now: date(1, 10), calendar: calendar) == state)
        #expect(engine.recordingActivity(state, category: .creative, seconds: -1) == state)
    }

    @Test func progress() {
        let p1 = engine.progress(of: TownState(growthSeconds: hour))
        #expect(p1.level == 1)
        #expect(TestSupport.isClose(p1.fractionToNext, 0.5))
        #expect(p1.secondsToNext == hour)

        let p2 = engine.progress(of: TownState(growthSeconds: 4 * hour))
        #expect(p2.level == 2)
        #expect(TestSupport.isClose(p2.fractionToNext, 0.5))

        let p3 = engine.progress(of: TownState(growthSeconds: 7 * hour))
        #expect(p3.level == 3)
        #expect(p3.fractionToNext == 1)
        #expect(p3.secondsToNext == nil)
    }

    @Test func levelFeatures() {
        #expect(engine.unlockedFeatures(of: TownState()).isEmpty)
        let l2 = engine.unlockedFeatures(of: TownState(growthSeconds: 2 * hour))
        #expect(l2.isSuperset(of: [.youngTree, .wildflowers, .lamppost, .secondResident]))
        #expect(!l2.contains(.secondHouse))
        let l3 = engine.unlockedFeatures(of: TownState(growthSeconds: 6 * hour))
        #expect(l3.isSuperset(of: [.youngTree, .secondHouse, .well]))
    }

    @Test func differentCategoriesUnlockDifferentFeatures() {
        let base = TownState(growthSeconds: 2 * hour)
        let dev = engine.unlockedFeatures(of: engine.recordingActivity(base, category: .development, seconds: hour))
        let creative = engine.unlockedFeatures(of: engine.recordingActivity(base, category: .creative, seconds: hour))
        let fun = engine.unlockedFeatures(of: engine.recordingActivity(base, category: .entertainment, seconds: hour))
        let docs = engine.unlockedFeatures(of: engine.recordingActivity(base, category: .productivity, seconds: hour))

        #expect(dev.contains(.workshop))
        #expect(!dev.contains(.artGarden))
        #expect(creative.contains(.artGarden))
        #expect(!creative.contains(.workshop))
        #expect(fun.contains(.festivalBunting))
        #expect(docs.contains(.readingNook))
    }

    @Test func otherCategoryOnlyFeedsGeneralGrowth() {
        let state = engine.recordingActivity(TownState(growthSeconds: 6 * hour), category: .other, seconds: 100 * hour)
        let activityFeatures: Set<TownFeature> = [.workshop, .artGarden, .readingNook, .festivalBunting]
        #expect(engine.unlockedFeatures(of: state).isDisjoint(with: activityFeatures))
    }

    @Test func activityUnlockRespectsMinimumLevel() {
        let lowLevel = engine.recordingActivity(TownState(), category: .development, seconds: 10 * hour)
        #expect(!engine.unlockedFeatures(of: lowLevel).contains(.workshop), "workshop needs level 2")
        let creative = engine.recordingActivity(TownState(), category: .creative, seconds: hour)
        #expect(engine.unlockedFeatures(of: creative).contains(.artGarden), "art garden allowed at level 1")
    }

    @Test func growthWorksWithTrackingDisabled() {
        // No activity is ever recorded; time alone must still reach max level.
        var state = TownState()
        for day in 1...3 {
            state = engine.advancing(state, by: 3 * hour, now: date(day, 12), calendar: calendar)
        }
        #expect(engine.level(of: state) == 3)
        #expect(state.activitySeconds.isEmpty)
    }
}
