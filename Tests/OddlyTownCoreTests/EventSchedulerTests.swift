import Foundation
import Testing
@testable import OddlyTownCore

@Suite struct EventSchedulerTests {
    let start = TestSupport.date(day: 21, hour: 9)

    func ctx(_ phase: DayPhase = .day, level: Int = 3, residents: Int = 3, visible: Bool = true,
             lateNight: Bool = false) -> EventContext {
        EventContext(level: level, phase: phase, lateNight: lateNight, residentCount: residents, isVisible: visible)
    }

    /// Minute ticks for `hours`, returns every change with its time.
    func run(hours: Double, context: EventContext, seed: UInt64 = 1) -> [(Date, EventChange)] {
        var scheduler = EventScheduler(start: start)
        var rng = SplitMix64(seed: seed)
        var log: [(Date, EventChange)] = []
        for minute in 1...Int(hours * 60) {
            let now = start.addingTimeInterval(Double(minute) * 60)
            for change in scheduler.update(now: now, elapsed: 60, context: context, using: &rng) {
                log.append((now, change))
            }
        }
        return log
    }

    @Test func nothingHappensDuringTheFirstQuietPeriod() {
        let log = run(hours: 0.4, context: ctx()) // 24 min < 25 min gap
        #expect(log.isEmpty)
    }

    @Test func neverTwoAtOnceAndAlwaysEnds() {
        let log = run(hours: 24, context: ctx())
        var running: TownEventKind?
        for (_, change) in log {
            switch change {
            case .started(let kind, _):
                #expect(running == nil, "only one event at a time")
                running = kind
            case .ended(let kind):
                #expect(running == kind)
                running = nil
            }
        }
        #expect(log.contains { if case .started = $0.1 { return true } else { return false } })
    }

    @Test func eventsAreRareAndSpacedOut() {
        let log = run(hours: 24, context: ctx())
        let starts = log.filter { if case .started = $0.1 { return true } else { return false } }.map(\.0)
        let ends = log.filter { if case .ended = $0.1 { return true } else { return false } }.map(\.0)
        #expect(starts.count <= 24 * 60 / 25, "at most one per quiet gap")
        #expect(starts.count >= 10, "but the town isn't dead either")
        for (end, nextStart) in zip(ends, starts.dropFirst()) {
            #expect(nextStart.timeIntervalSince(end) >= EventRules.standard.minimumGap)
        }
    }

    @Test func eventsEndAfterTheirDuration() {
        let log = run(hours: 6, context: ctx())
        var startedAt: [TownEventKind: Date] = [:]
        for (time, change) in log {
            switch change {
            case .started(let kind, let duration):
                startedAt[kind] = time
                #expect(duration == EventRules.standard.rule(for: kind)?.duration)
            case .ended(let kind):
                let began = try! #require(startedAt[kind])
                let rule = EventRules.standard.rule(for: kind)!.duration
                #expect(time.timeIntervalSince(began) >= rule)
                #expect(time.timeIntervalSince(began) < rule + 61, "ends at the first tick after its duration")
            }
        }
    }

    @Test func respectsConditions() {
        #expect(run(hours: 12, context: ctx(visible: false)).isEmpty, "nothing starts while nobody can see the town")
        #expect(run(hours: 12, context: ctx(.night)).isEmpty, "no events at night")
        #expect(run(hours: 12, context: ctx(lateNight: true)).isEmpty)

        let lonely = run(hours: 24, context: ctx(level: 1, residents: 1))
        #expect(!lonely.contains { $0.1 == .started(.gathering, duration: 60) }, "gathering needs neighbours")

        let dusk = run(hours: 24, context: ctx(.dusk))
        #expect(!dusk.contains { $0.1 == .started(.traveler, duration: 70) }, "travelers come by day")
    }

    @Test func forceReplacesTheRunningEvent() {
        var scheduler = EventScheduler(start: start)
        let first = scheduler.force(.strayCat, now: start)
        #expect(first == [.started(.strayCat, duration: 40)])
        let second = scheduler.force(.traveler, now: start.addingTimeInterval(5))
        #expect(second == [.ended(.strayCat), .started(.traveler, duration: 70)])
        #expect(scheduler.active?.kind == .traveler)
        #expect(scheduler.endActive(now: start.addingTimeInterval(10)) == [.ended(.traveler)])
        #expect(scheduler.active == nil)
    }

    @Test func longerTicksScaleTheChance() {
        // A 5-second developer tick must not make events 12× more likely than a 1-minute tick.
        var fast = EventScheduler(start: start)
        var rng = SplitMix64(seed: 7)
        var startsFast = 0
        var now = start
        for _ in 0..<(24 * 720) { // 24h of 5-second ticks
            now = now.addingTimeInterval(5)
            for change in fast.update(now: now, elapsed: 5, context: ctx(), using: &rng) {
                if case .started = change { startsFast += 1 }
            }
        }
        #expect(startsFast <= 24 * 60 / 25)
    }
}
