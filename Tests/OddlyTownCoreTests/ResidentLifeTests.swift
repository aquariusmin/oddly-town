import Foundation
import Testing
@testable import OddlyTownCore

@Suite struct ResidentLifeTests {
    func context(_ phase: DayPhase, lateNight: Bool = false, features: Set<TownFeature> = [],
                 seats: [Int] = [0]) -> LifeContext {
        LifeContext(phase: phase, lateNight: lateNight, features: features, seatSlots: seats)
    }

    /// Runs `count` decisions for resident 0 and returns the plans in order.
    func simulate(_ ctx: LifeContext, residents: Int = 2, count: Int = 400, seed: UInt64 = 1) -> [BehaviorPlan] {
        var life = TownLife(seed: seed)
        _ = life.setResidentCount(residents, context: ctx)
        var plans: [BehaviorPlan] = []
        for _ in 0..<count {
            // Resident 0's plans are recorded; the others keep living so partners free up.
            for (index, plan) in life.nextPlans(finished: 0, context: ctx) where index == 0 {
                plans.append(plan)
            }
            for other in 1..<max(1, residents) {
                // A neighbour starting a chat hands resident 0 a plan too.
                if let pulled = life.nextPlans(finished: other, context: ctx)[0] { plans.append(pulled) }
            }
        }
        return plans
    }

    @Test func everyPlanRespectsItsMinimumDuration() {
        for phase in DayPhase.allCases {
            let all: Set<TownFeature> = [.workshop, .artGarden, .readingNook, .festivalBunting]
            for plan in simulate(context(phase, features: all)) {
                #expect(plan.duration >= plan.activity.durationRange.lowerBound)
                #expect(plan.duration <= plan.activity.durationRange.upperBound)
                #expect(plan.duration >= 3, "nothing changes every second")
            }
        }
    }

    @Test func dayHasVarietyAndNoImmediateRepeats() {
        let plans = simulate(context(.day))
        let kinds = Set(plans.map(\.activity))
        #expect(kinds.isSuperset(of: [.walking, .idle, .sitting, .working, .socializing]))
        for (a, b) in zip(plans, plans.dropFirst()) {
            #expect(a.activity != b.activity)
        }
    }

    @Test func eveningSendsPeopleHome() {
        let dusk = simulate(context(.dusk))
        let homeShare = Double(dusk.filter { $0.activity == .returningHome }.count) / Double(dusk.count)
        #expect(homeShare > 0.3)
        #expect(dusk.contains { $0.activity == .returningHome && $0.spot == .home(.cottage) })

        let night = simulate(context(.night))
        let nightHome = Double(night.filter { $0.activity == .returningHome }.count) / Double(night.count)
        #expect(nightHome > 0.85, "mostly indoors at night")

        let late = simulate(context(.night, lateNight: true))
        #expect(late.allSatisfy { $0.activity == .returningHome })
    }

    @Test func workshopTurnsWorkIntoWorkshopTime() {
        let without = simulate(context(.day)).filter { $0.activity == .working }
        #expect(!without.isEmpty)
        #expect(without.allSatisfy { $0.spot == .home(.cottage) }, "without a workshop they tinker at home")

        let with = simulate(context(.day, features: [.workshop]))
        let working = with.filter { $0.activity == .working }
        #expect(working.allSatisfy { $0.spot == .workshop })
        #expect(working.count > without.count, "Development activity makes residents work more")
    }

    @Test func creativeAndProductivityBuildingsAddTheirOwnBehaviour() {
        let base = simulate(context(.day))
        #expect(!base.contains { $0.activity == .admiringFlowers || $0.activity == .reading || $0.activity == .celebrating })

        let garden = simulate(context(.day, features: [.artGarden]))
        #expect(garden.contains { $0.activity == .admiringFlowers && $0.spot == .artGarden })
        let nook = simulate(context(.day, features: [.readingNook]))
        #expect(nook.contains { $0.activity == .reading && $0.spot == .readingNook })
        let festival = simulate(context(.day, features: [.festivalBunting]))
        #expect(festival.contains { $0.activity == .celebrating })
    }

    @Test func noFeatureBehaviourAtNight() {
        let all: Set<TownFeature> = [.workshop, .artGarden, .readingNook, .festivalBunting]
        let night = simulate(context(.night, features: all))
        #expect(!night.contains { [.working, .reading, .admiringFlowers, .celebrating].contains($0.activity) })
    }

    @Test func sittingNeedsABench() {
        let noSeat = simulate(context(.day, seats: []))
        #expect(!noSeat.contains { $0.activity == .sitting })
        let twoSeats = simulate(context(.day, seats: [1, 3]))
        let spots = Set(twoSeats.filter { $0.activity == .sitting }.map(\.spot))
        #expect(spots.isSubset(of: [.seat(slot: 1), .seat(slot: 3)]))
        #expect(!spots.isEmpty)
    }

    @Test func socializingPairsTwoResidents() {
        var life = TownLife(seed: 3)
        let ctx = context(.day)
        _ = life.setResidentCount(2, context: ctx)
        var found = false
        for _ in 0..<200 {
            let plans = life.nextPlans(finished: 0, context: ctx)
            if plans[0]?.activity == .socializing {
                let mine = plans[0]!, theirs = try! #require(plans[1])
                #expect(mine.partner == 1 && theirs.partner == 0)
                #expect(theirs.activity == .socializing && theirs.duration == mine.duration)
                #expect(mine.spot == .plaza && theirs.spot == .plaza)
                found = true
                break
            }
            _ = life.nextPlans(finished: 1, context: ctx) // let resident 1 become interruptible again
        }
        #expect(found)
    }

    @Test func aLoneResidentNeverSocializes() {
        let plans = simulate(context(.day), residents: 1)
        #expect(!plans.contains { $0.activity == .socializing })
    }

    @Test func residentCountChangesWithGrowth() {
        var life = TownLife(seed: 9)
        let ctx = context(.day)
        #expect(life.setResidentCount(1, context: ctx).count == 1)
        let added = life.setResidentCount(3, context: ctx)
        #expect(Set(added.keys).isSuperset(of: [1, 2]))
        #expect(life.residents.map(\.home) == [.cottage, .cottage, .blueHouse])
        _ = life.setResidentCount(1, context: ctx) // town reset
        #expect(life.residents.count == 1)
        #expect(life.nextPlans(finished: 2, context: ctx).isEmpty)
    }

    @Test func gatheringBringsEveryoneToThePlaza() {
        var life = TownLife(seed: 4)
        _ = life.setResidentCount(3, context: context(.day))
        let plans = life.gatherEveryone(duration: 60, celebrating: false)
        #expect(plans.count == 3)
        #expect(plans.values.allSatisfy { $0.spot == .plaza && $0.activity == .socializing && $0.duration == 60 })
    }

    @Test func sameSeedSameTown() {
        #expect(simulate(context(.day), seed: 42) == simulate(context(.day), seed: 42))
    }
}
