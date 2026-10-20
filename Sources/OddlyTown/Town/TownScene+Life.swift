import SpriteKit
import OddlyTownCore

/// Plays one `BehaviorPlan` at a time as a single SKAction sequence. Decisions happen in
/// `TownLife` (core) only when a sequence finishes — nothing is evaluated per frame.
final class ResidentSprite {
    let index: Int
    let name: String
    let node: SKSpriteNode
    let frames: ResidentFrames
    var onFinished: ((Int) -> Void)?

    private(set) var plan: BehaviorPlan?
    private var facing: CGFloat = 1
    /// Bumped on every new plan so a cancelled sequence can't report back.
    private var generation = 0
    private let dots: SKSpriteNode
    private static let speed: CGFloat = 5 // pixels per second

    init(index: Int, frames: ResidentFrames, name: String) {
        self.index = index
        self.name = name
        self.frames = frames
        node = SKSpriteNode(texture: frames.idle)
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        node.zPosition = 100 - TownScene.pathY
        dots = SKSpriteNode(texture: TownArt.chatDots)
        dots.anchorPoint = CGPoint(x: 0.5, y: 0)
        dots.position = CGPoint(x: 1, y: 9)
        dots.zPosition = 1
        dots.alpha = 0
        node.addChild(dots)
    }

    var isIndoors: Bool { node.alpha < 0.5 }

    /// `instant`: jump straight into the plan (used at launch so nobody is mid-walk at night).
    func perform(_ plan: BehaviorPlan, at target: CGPoint, face: CGFloat?, instant: Bool = false) {
        self.plan = plan
        generation += 1
        let myGeneration = generation
        node.removeAction(forKey: "plan")
        dots.removeAllActions()
        dots.alpha = 0

        var steps: [SKAction] = []
        if instant {
            node.position = CGPoint(x: target.x, y: TownScene.pathY)
            node.alpha = plan.activity == .returningHome ? 0 : 1
        } else if isIndoors {
            steps.append(.fadeIn(withDuration: 0.6)) // stepping out of the door
        }

        if node.position.y != TownScene.pathY {
            steps.append(.moveTo(y: TownScene.pathY, duration: 0.4)) // get up from the bench
        }
        let distance = target.x - node.position.x
        if abs(distance) >= 1 && !instant {
            facing = distance < 0 ? -1 : 1
            let duration = Double(abs(distance) / Self.speed)
            steps.append(.scaleX(to: facing, duration: 0))
            steps.append(.group([
                .moveTo(x: target.x, duration: duration),
                .repeat(.animate(with: frames.walk, timePerFrame: 0.25), count: max(1, Int(duration / 0.5))),
            ]))
        }
        steps.append(.setTexture(frames.idle))
        if let face {
            facing = face
            steps.append(.scaleX(to: face, duration: 0))
        }
        steps.append(activity(plan, at: target))
        steps.append(.setTexture(frames.idle))
        steps.append(.run { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.generation == myGeneration else { return }
                self.onFinished?(self.index)
            }
        })
        node.run(.sequence(steps), withKey: "plan")
    }

    private func activity(_ plan: BehaviorPlan, at target: CGPoint) -> SKAction {
        let d = plan.duration
        switch plan.activity {
        case .walking:
            return .wait(forDuration: d)
        case .idle:
            // Look one way, then the other.
            return .sequence([
                .wait(forDuration: d * 0.4),
                .scaleX(to: -facing, duration: 0),
                .wait(forDuration: d * 0.35),
                .scaleX(to: facing, duration: 0),
                .wait(forDuration: d * 0.25),
            ])
        case .sitting:
            return .sequence([
                .moveTo(y: target.y, duration: 0.4),
                .setTexture(frames.sit),
                .wait(forDuration: d),
            ])
        case .working:
            return .repeat(.animate(with: frames.work, timePerFrame: 0.45), count: max(1, Int(d / 0.9)))
        case .reading:
            return .repeat(.animate(with: frames.read, timePerFrame: 2.2), count: max(1, Int(d / 4.4)))
        case .admiringFlowers:
            let bend = SKAction.sequence([.setTexture(frames.crouch), .wait(forDuration: 1.6),
                                          .setTexture(frames.idle), .wait(forDuration: 1.2)])
            return .repeat(bend, count: max(1, Int(d / 2.8)))
        case .socializing:
            // A couple of tiny "…" now and then; mostly just standing together.
            dots.run(.sequence([
                .wait(forDuration: 1.5 + Double(index)),
                .fadeIn(withDuration: 0.2), .wait(forDuration: 1.4), .fadeOut(withDuration: 0.3),
                .wait(forDuration: 4),
                .fadeIn(withDuration: 0.2), .wait(forDuration: 1.2), .fadeOut(withDuration: 0.3),
            ]), withKey: "dots")
            let gesture = SKAction.sequence([.setTexture(frames.talk), .wait(forDuration: 0.8),
                                             .setTexture(frames.idle), .wait(forDuration: 1.8)])
            return .repeat(gesture, count: max(1, Int(d / 2.6)))
        case .celebrating:
            let hop = SKAction.sequence([
                .setTexture(frames.cheer), .moveBy(x: 0, y: 1, duration: 0.15), .moveBy(x: 0, y: -1, duration: 0.15),
                .setTexture(frames.idle), .wait(forDuration: 0.7),
            ])
            return .repeat(hop, count: max(1, Int(d / 1.0)))
        case .returningHome:
            return .sequence([.fadeOut(withDuration: 0.6), .wait(forDuration: d)])
        }
    }
}

extension TownScene {
    /// Pixel position for a spot. Spots shared by several residents (the plaza) are spread out.
    func position(of spot: TownSpot, resident index: Int) -> CGPoint {
        let y = Self.pathY
        switch spot {
        case .home(.cottage): return CGPoint(x: 22, y: y)
        case .home(.blueHouse): return CGPoint(x: 86, y: y)
        case .seat(let slot):
            let origin = TownArt.decorSlots[min(max(slot, 0), TownArt.decorSlots.count - 1)]
            return CGPoint(x: origin.x + 3 + CGFloat(index % 2) * 2, y: origin.y + 2)
        case .wander(let i):
            let xs: [CGFloat] = [12, 30, 46, 60, 78, 94, 128]
            return CGPoint(x: xs[min(max(i, 0), xs.count - 1)], y: y)
        case .well: return CGPoint(x: 66, y: y)
        case .plaza: return CGPoint(x: 64 + CGFloat(index) * 6, y: y)
        case .workshop: return CGPoint(x: 104, y: y)
        case .artGarden: return CGPoint(x: 54 + CGFloat(index), y: y)
        case .readingNook: return CGPoint(x: 130, y: y)
        }
    }

    func updateResidentCount(_ count: Int, firstTime: Bool) {
        let plans = life.setResidentCount(count, context: lifeContext)
        for (index, resident) in residents.enumerated() {
            let active = index < count
            if !active {
                resident.node.removeAllActions()
                resident.node.isHidden = true
            } else if resident.node.isHidden {
                resident.node.isHidden = false
                resident.node.alpha = 1
            }
        }
        start(plans, instant: firstTime)
    }

    func start(_ plans: [Int: BehaviorPlan], instant: Bool = false) {
        for (index, plan) in plans where index < residents.count && !residents[index].node.isHidden {
            let target = position(of: plan.spot, resident: index)
            residents[index].perform(plan, at: target, face: facing(for: plan, resident: index, target: target), instant: instant)
        }
    }

    private func facing(for plan: BehaviorPlan, resident index: Int, target: CGPoint) -> CGFloat? {
        guard plan.activity == .socializing || plan.activity == .celebrating else { return nil }
        if let partner = plan.partner {
            return position(of: plan.spot, resident: partner).x < target.x ? -1 : 1
        }
        return 1 // greeting a visitor, who stands to the right of the plaza
    }

    func residentFinished(_ index: Int) {
        start(life.nextPlans(finished: index, context: lifeContext))
    }

    func residentActivity(_ index: Int) -> ResidentActivity? {
        guard residents.indices.contains(index), !residents[index].node.isHidden else { return nil }
        return residents[index].plan?.activity
    }

    /// Demo Mode: everyone does `activity` now (falls back to normal life afterwards).
    func demoForce(_ activity: ResidentActivity) {
        var plans: [Int: BehaviorPlan] = [:]
        let count = life.residents.count
        for index in 0..<count {
            let spot: TownSpot
            switch activity {
            case .sitting: spot = .seat(slot: lifeContext.seatSlots.first ?? 0)
            case .working: spot = lifeContext.features.contains(.workshop) ? .workshop : .home(TownLife.home(forResident: index))
            case .returningHome: spot = .home(TownLife.home(forResident: index))
            case .reading: spot = .readingNook
            case .admiringFlowers: spot = .artGarden
            case .socializing, .celebrating: spot = .plaza
            case .walking, .idle: spot = .wander(index * 2 + 1)
            }
            let partner = (activity == .socializing && count > 1) ? (index + 1) % count : nil
            let plan = BehaviorPlan(activity: activity, spot: spot, duration: activity.durationRange.upperBound, partner: partner)
            life.impose(plan, on: index)
            plans[index] = plan
        }
        start(plans)
    }
}
