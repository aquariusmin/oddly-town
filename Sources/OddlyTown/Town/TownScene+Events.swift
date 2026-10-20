import SpriteKit
import OddlyTownCore

// MARK: Small events

extension TownScene {
    /// Plays an event's visuals. Nodes are prebuilt; only short-lived SKActions are created.
    func startEvent(_ kind: TownEventKind, duration: TimeInterval) {
        endEvent(nil)
        switch kind {
        case .strayCat: runCat(duration: duration)
        case .traveler: runTraveler(duration: duration)
        case .gathering:
            let celebrating = lifeContext.features.contains(.festivalBunting)
            start(life.gatherEveryone(duration: max(10, duration - 15), celebrating: celebrating))
        }
    }

    /// Stops visitor visuals (`kind` nil = whatever is running). Residents simply carry on.
    func endEvent(_ kind: TownEventKind?) {
        if kind == nil || kind == .strayCat {
            catNode.removeAllActions()
            catNode.isHidden = true
        }
        if kind == nil || kind == .traveler {
            travelerNode.removeAllActions()
            travelerNode.isHidden = true
        }
    }

    private func walk(_ node: SKSpriteNode, frames: [SKTexture], to x: CGFloat, speed: CGFloat) -> SKAction {
        let duration = Double(abs(x - node.position.x) / speed)
        return .group([
            .moveTo(x: x, duration: duration),
            .repeat(.animate(with: frames, timePerFrame: 0.2), count: max(1, Int(duration / 0.4))),
        ])
    }

    private func runCat(duration: TimeInterval) {
        guard let frames = catFrames else { return }
        let speed: CGFloat = 8
        let stop: CGFloat = 58, exit: CGFloat = 150
        catNode.position = CGPoint(x: -10, y: 5)
        catNode.xScale = 1
        catNode.alpha = 1
        catNode.isHidden = false
        let walkIn = Double((stop + 10) / speed), walkOut = Double((exit - stop) / speed)
        let sit = max(4, duration - walkIn - walkOut)
        catNode.run(.sequence([
            .group([.moveTo(x: stop, duration: walkIn), .repeat(.animate(with: frames.walk, timePerFrame: 0.2), count: max(1, Int(walkIn / 0.4)))]),
            .setTexture(frames.sit),
            .wait(forDuration: sit),
            .group([.moveTo(x: exit, duration: walkOut), .repeat(.animate(with: frames.walk, timePerFrame: 0.2), count: max(1, Int(walkOut / 0.4)))]),
            .hide(),
        ]))
    }

    private func runTraveler(duration: TimeInterval) {
        guard let frames = travelerFrames else { return }
        let speed: CGFloat = 4
        let stop: CGFloat = 82, exit: CGFloat = 148
        travelerNode.position = CGPoint(x: -6, y: Self.pathY)
        travelerNode.xScale = 1
        travelerNode.alpha = 1
        travelerNode.isHidden = false
        let walkIn = Double((stop + 6) / speed), walkOut = Double((exit - stop) / speed)
        let stay = max(6, duration - walkIn - walkOut)
        travelerNode.run(.sequence([
            .group([.moveTo(x: stop, duration: walkIn), .repeat(.animate(with: frames.walk, timePerFrame: 0.25), count: max(1, Int(walkIn / 0.5)))]),
            .setTexture(frames.idle),
            .scaleX(to: -1, duration: 0), // turns to the neighbour who came to say hello
            .wait(forDuration: stay),
            .scaleX(to: 1, duration: 0),
            .group([.moveTo(x: exit, duration: walkOut), .repeat(.animate(with: frames.walk, timePerFrame: 0.25), count: max(1, Int(walkOut / 0.5)))]),
            .hide(),
        ]))
        start(life.greetVisitor(duration: max(10, stay * 0.7)))
    }
}

// MARK: Town Mode selection

extension TownScene {
    func handleClick(at point: CGPoint) {
        let selection = hitTest(point)
        select(selection)
        onSelect?(selection)
    }

    private func hitTest(_ point: CGPoint) -> TownSelection? {
        // Generous hit boxes: residents are only 7 px wide.
        for resident in residents.reversed() where !resident.node.isHidden && !resident.isIndoors {
            if resident.node.frame.insetBy(dx: -2, dy: -2).contains(point) { return .resident(resident.index) }
        }
        for (slot, origin) in TownArt.decorSlots.enumerated() {
            if CGRect(x: origin.x - 1, y: origin.y - 1, width: 11, height: 9).contains(point) { return .slot(slot) }
        }
        let order: [TownFeature] = [.workshop, .readingNook, .secondHouse, .well, .artGarden, .lamppost,
                                    .youngTree, .picketFence, .wildflowers, .festivalBunting]
        for feature in order where visibleFeatures.contains(feature) {
            if let bounds = featureBounds[feature] ?? accumulatedBounds(of: feature), bounds.contains(point) {
                return .feature(feature)
            }
        }
        if cottageBounds.contains(point) { return .cottage }
        return nil
    }

    private func accumulatedBounds(of feature: TownFeature) -> CGRect? {
        guard let node = featureNodes[feature], !node.children.isEmpty else { return nil }
        let frames = node.children.map(\.frame)
        let bounds = frames.dropFirst().reduce(frames[0]) { $0.union($1) }
        featureBounds[feature] = bounds
        return bounds
    }

    /// Shows the bobbing arrow above the selection (follows residents as they move).
    func select(_ selection: TownSelection?) {
        selectionArrow.removeFromParent()
        guard let selection else {
            selectionArrow.isHidden = true
            return
        }
        selectionArrow.isHidden = false
        switch selection {
        case .resident(let index):
            residents[index].node.addChild(selectionArrow)
            selectionArrow.position = CGPoint(x: 0, y: 11)
            selectionArrow.zPosition = 10
        case .slot(let slot):
            world.addChild(selectionArrow)
            let origin = TownArt.decorSlots[slot]
            selectionArrow.position = CGPoint(x: origin.x + 4, y: origin.y + 9)
            selectionArrow.zPosition = 200
        case .feature(let feature):
            world.addChild(selectionArrow)
            let bounds = featureBounds[feature] ?? accumulatedBounds(of: feature) ?? .zero
            selectionArrow.position = CGPoint(x: bounds.midX, y: min(bounds.maxY + 1, 55))
            selectionArrow.zPosition = 200
        case .cottage:
            world.addChild(selectionArrow)
            selectionArrow.position = CGPoint(x: cottageBounds.midX, y: cottageBounds.maxY + 1)
            selectionArrow.zPosition = 200
        }
    }
}
