import SpriteKit
import OddlyTownCore

/// Renders a `TownSnapshot`. Every node is created once in `build()`; snapshots only
/// show/hide nodes and retint them, so nothing is allocated while the town runs.
///
/// Coordinates: a 140 × 60 pixel grid inside `world`, scaled ×3 to the 420 × 180 scene.
final class TownScene: SKScene {
    static let sceneSize = CGSize(width: 420, height: 180)
    static let pixelScale: CGFloat = 3

    private let world = SKNode()
    private let sky = SKNode()
    private let starField = SKNode()
    private var tintables: [SKSpriteNode] = []
    private var featureNodes: [TownFeature: SKNode] = [:]
    private var visibleFeatures: Set<TownFeature> = []
    private var houseLights: [TownFeature?: SKSpriteNode] = [:]
    private var lampGlow = SKSpriteNode()
    private var sun = SKSpriteNode()
    private var moon = SKSpriteNode()
    private var residents: [Resident] = []

    private let bubble = SKShapeNode()
    private let bubbleLabel = SKLabelNode(fontNamed: "Menlo-Bold")

    private(set) var snapshot: TownSnapshot?
    private var animating = true

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
        anchorPoint = .zero
        scaleMode = .aspectFit
        build()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Public API

    /// Stops/starts all town motion. The status bubble lives outside `world` and keeps working.
    func setAnimating(_ on: Bool) {
        animating = on
        world.isPaused = !on
    }

    func apply(_ next: TownSnapshot) {
        let previous = snapshot
        snapshot = next
        let animated = animating && previous != nil

        for feature in TownFeature.allCases {
            setFeature(feature, visible: next.features.contains(feature), animated: animated)
        }
        if previous?.phase != next.phase || previous?.lateNight != next.lateNight {
            applyPhase(next.phase, lateNight: next.lateNight, animated: animated)
        }
        if previous?.features != next.features {
            for resident in residents { resident.startRoute(stops: residentStops(for: next.features)) }
        }
    }

    func showStatus(_ text: String) {
        bubbleLabel.text = text
        let width = bubbleLabel.frame.width + 22
        bubble.path = CGPath(
            roundedRect: CGRect(x: -width / 2, y: -11, width: width, height: 22),
            cornerWidth: 9, cornerHeight: 9, transform: nil
        )
        bubble.removeAllActions()
        bubble.run(.sequence([
            .fadeAlpha(to: 1, duration: 0.15),
            .wait(forDuration: 3.5),
            .fadeAlpha(to: 0, duration: 0.5),
        ]))
    }

    // MARK: Build

    private func build() {
        world.setScale(Self.pixelScale)
        addChild(world)
        world.addChild(sky)
        sky.zPosition = -50
        sky.addChild(starField)

        buildSky()
        buildGround()
        buildBaseTown()
        buildLevelFeatures()
        buildActivityFeatures()
        buildResidents()
        buildBubble()
    }

    private func buildSky() {
        // Fixed star positions so the night sky looks the same every evening.
        let stars: [(CGFloat, CGFloat)] = [(9, 52), (21, 57), (34, 47), (48, 55), (61, 50), (77, 58), (88, 46),
                                           (101, 54), (113, 49), (120, 57), (68, 41), (17, 43)]
        let starTexture = PixelArt.texture(["c"], palette: ["c": 0xFFF6D8])
        for (index, (x, y)) in stars.enumerated() {
            let star = SKSpriteNode(texture: starTexture)
            star.anchorPoint = .zero
            star.position = CGPoint(x: x, y: y)
            starField.addChild(star)
            star.run(.repeatForever(.sequence([
                .wait(forDuration: 1.3 + Double(index % 4) * 0.7),
                .fadeAlpha(to: 0.3, duration: 0.8),
                .fadeAlpha(to: 1, duration: 0.8),
            ])))
        }
        starField.alpha = 0

        sun = SKSpriteNode(texture: TownArt.tex("sun", TownArt.sunRows))
        moon = SKSpriteNode(texture: TownArt.tex("moon", TownArt.moonRows, palette: TownArt.moonPalette))
        for body in [sun, moon] {
            body.anchorPoint = .zero
            body.position = CGPoint(x: 126, y: 49)
            sky.addChild(body)
        }
        moon.alpha = 0

        let clouds: [(rows: [String], x: CGFloat, y: CGFloat, speed: CGFloat)] = [
            (TownArt.cloudRows, 18, 47, 1.6),
            (TownArt.smallCloudRows, 82, 53, 1.1),
            (TownArt.smallCloudRows, 120, 41, 2.0),
        ]
        for (index, cloud) in clouds.enumerated() {
            let node = sprite(TownArt.tex(index == 0 ? "cloud" : "cloud-small", cloud.rows), left: cloud.x, y: cloud.y, z: -40, parent: sky)
            let start: CGFloat = -20, end: CGFloat = 150
            node.run(.sequence([
                .moveTo(x: end, duration: Double((end - cloud.x) / cloud.speed)),
                .repeatForever(.sequence([
                    .moveTo(x: start, duration: 0),
                    .moveTo(x: end, duration: Double((end - start) / cloud.speed)),
                ])),
            ]))
        }
    }

    private func buildGround() {
        sprite(TownArt.tex("ground", TownArt.groundRows()), left: 0, y: 0, z: -20)
    }

    private func buildBaseTown() {
        swayingTree(TownArt.treeRows, name: "tree", centerX: 8, y: 12, period: 1.6)
        house(TownArt.cottageRows, palette: TownArt.palette, name: "cottage", left: 14, doorX: 21, feature: nil, parent: world)
        sprite(TownArt.tex("mailbox", TownArt.mailboxRows), left: 31, y: 12)
        swayingTree(TownArt.treeRows, name: "tree", centerX: 39, y: 12, period: 2.1)
        sprite(TownArt.tex("rock", TownArt.rockRows), left: 132, y: 12)
    }

    private func buildLevelFeatures() {
        let youngTree = featureNode(.youngTree)
        swayingTree(TownArt.youngTreeRows, name: "young-tree", centerX: 74, y: 13, period: 1.8, parent: youngTree)

        let fence = featureNode(.picketFence)
        let fenceTexture = TownArt.tex("fence", TownArt.fenceRows)
        sprite(fenceTexture, left: 112, y: 3, parent: fence)
        sprite(fenceTexture, left: 123, y: 3, parent: fence)

        let flowers = featureNode(.wildflowers)
        let flowerTexture = TownArt.tex("wildflowers", TownArt.wildflowerRows)
        sprite(flowerTexture, left: 6, y: 2, parent: flowers)
        sprite(flowerTexture, left: 62, y: 2, parent: flowers)

        let lamp = featureNode(.lamppost)
        sprite(TownArt.tex("lamppost", TownArt.lamppostRows), left: 95, y: 13, parent: lamp)
        lampGlow = glow(radius: 5, centerX: 96.5, centerY: 22.5, parent: lamp)

        let secondHouse = featureNode(.secondHouse)
        house(TownArt.cottageRows, palette: TownArt.blueRoof, name: "house-blue", left: 78, doorX: 85, feature: .secondHouse, parent: secondHouse)

        let well = featureNode(.well)
        sprite(TownArt.tex("well", TownArt.wellRows), left: 62, y: 13, parent: well)
    }

    private func buildActivityFeatures() {
        // Development → workshop with a smoking chimney.
        let workshop = featureNode(.workshop)
        house(TownArt.workshopRows, palette: TownArt.palette, name: "workshop", left: 99, doorX: 108, feature: .workshop, parent: workshop)
        let puff = PixelArt.texture(["CC", "CC"], palette: ["C": 0xD9D9D9])
        for index in 0..<3 {
            let smoke = SKSpriteNode(texture: puff)
            smoke.anchorPoint = .zero
            smoke.position = CGPoint(x: 112, y: 26)
            smoke.zPosition = 90
            smoke.alpha = 0
            workshop.addChild(smoke)
            smoke.run(.sequence([
                .wait(forDuration: Double(index) * 1.3),
                .repeatForever(.sequence([
                    .fadeAlpha(to: 0.8, duration: 0),
                    .group([.moveBy(x: 2, y: 9, duration: 3.9), .fadeOut(withDuration: 3.9)]),
                    .moveBy(x: -2, y: -9, duration: 0),
                ])),
            ]))
        }

        // Creative → art garden: flower bed and an easel.
        let garden = featureNode(.artGarden)
        sprite(TownArt.tex("easel", TownArt.easelRows), left: 49, y: 12, parent: garden)
        sprite(TownArt.tex("flower-bed", TownArt.flowerBedRows), left: 46, y: 9, parent: garden)

        // Productivity → reading nook.
        let nook = featureNode(.readingNook)
        house(TownArt.readingNookRows, palette: TownArt.tealRoof, name: "reading-nook", left: 118, doorX: 124, feature: .readingNook, parent: nook)

        // Entertainment → festival bunting across the whole town.
        let bunting = featureNode(.festivalBunting)
        let poleTexture = TownArt.tex("pole", TownArt.poleRows)
        sprite(poleTexture, left: 2, y: 13, z: 60, parent: bunting)
        sprite(poleTexture, left: 136, y: 13, z: 60, parent: bunting)
        let frames = [TownArt.buntingTexture(width: 134, frame: 0), TownArt.buntingTexture(width: 134, frame: 1)]
        let flags = sprite(frames[0], left: 3, y: 30, z: 61, parent: bunting)
        flags.run(.repeatForever(.animate(with: frames, timePerFrame: 0.7)))
    }

    private func buildResidents() {
        let first = TownArt.residentFrames(shirt: 0xE07A5F, hair: 0x4A3326)
        let ada = Resident(idle: first.idle, walk: first.walk, startX: 30, seed: 7)
        world.addChild(ada.node)
        tintables.append(ada.node)
        residents.append(ada)

        let second = TownArt.residentFrames(shirt: 0x81B29A, hair: 0xC0703A)
        let bo = Resident(idle: second.idle, walk: second.walk, startX: 100, seed: 19)
        featureNode(.secondResident).addChild(bo.node)
        tintables.append(bo.node)
        residents.append(bo)
    }

    private func buildBubble() {
        bubble.fillColor = NSColor(calibratedWhite: 0.08, alpha: 0.82)
        bubble.strokeColor = .clear
        bubble.position = CGPoint(x: size.width / 2, y: size.height - 18)
        bubble.zPosition = 1000
        bubble.alpha = 0
        bubbleLabel.fontSize = 11
        bubbleLabel.fontColor = .white
        bubbleLabel.verticalAlignmentMode = .center
        bubbleLabel.horizontalAlignmentMode = .center
        bubble.addChild(bubbleLabel)
        addChild(bubble)
    }

    // MARK: Building helpers

    /// Places a sprite by its left edge and base line (whole pixels keep the art crisp).
    /// zPosition defaults to "lower on screen = in front".
    @discardableResult
    private func sprite(_ texture: SKTexture, left: CGFloat, y: CGFloat, z: CGFloat? = nil,
                        tint: Bool = true, parent: SKNode? = nil) -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture)
        node.anchorPoint = .zero
        node.position = CGPoint(x: left, y: y)
        node.zPosition = z ?? (100 - y)
        (parent ?? world).addChild(node)
        if tint { tintables.append(node) }
        return node
    }

    private func featureNode(_ feature: TownFeature) -> SKNode {
        if let existing = featureNodes[feature] { return existing }
        let node = SKNode()
        node.isHidden = true
        world.addChild(node)
        featureNodes[feature] = node
        return node
    }

    private func house(_ rows: [String], palette: [Character: UInt32], name: String, left: CGFloat, doorX: CGFloat,
                       feature: TownFeature?, parent: SKNode) {
        let body = sprite(TownArt.tex(name, rows, palette: palette), left: left, y: 13, parent: parent)
        sprite(TownArt.tex("path-branch", TownArt.pathBranchRows), left: doorX, y: 8, z: -10, parent: parent)
        let lights = sprite(TownArt.lights(rows), left: left, y: 13, z: body.zPosition + 0.5, tint: false, parent: parent)
        lights.alpha = 0
        houseLights[feature] = lights
    }

    private func swayingTree(_ rows: [String], name: String, centerX: CGFloat, y: CGFloat, period: Double,
                             parent: SKNode? = nil) {
        let frames = [TownArt.tex(name, rows), PixelArt.texture(PixelArt.shiftRows(rows, 0..<5, by: 1), palette: TownArt.palette)]
        let width = CGFloat(rows.map(\.count).max() ?? 0)
        let tree = sprite(frames[0], left: (centerX - width / 2).rounded(.down), y: y, parent: parent)
        tree.run(.repeatForever(.animate(with: frames, timePerFrame: period)))
    }

    private func glow(radius: Int, centerX: CGFloat, centerY: CGFloat, parent: SKNode) -> SKSpriteNode {
        let node = SKSpriteNode(texture: PixelArt.glow(radius: radius, rgb: 0xFFD36E))
        node.position = CGPoint(x: centerX, y: centerY)
        node.zPosition = 95
        node.alpha = 0
        parent.addChild(node)
        return node
    }

    private func residentStops(for features: Set<TownFeature>) -> [CGFloat] {
        var stops: [CGFloat] = [22, 39, 60]
        if features.contains(.well) { stops.append(66) }
        if features.contains(.secondHouse) { stops.append(86) }
        if features.contains(.workshop) { stops.append(108) }
        if features.contains(.readingNook) { stops.append(124) }
        if features.contains(.artGarden) { stops.append(54) }
        return stops
    }

    // MARK: Snapshot application

    private func setFeature(_ feature: TownFeature, visible: Bool, animated: Bool) {
        guard let node = featureNodes[feature], visibleFeatures.contains(feature) != visible else { return }
        node.removeAction(forKey: "appear")
        if visible {
            visibleFeatures.insert(feature)
            node.isHidden = false
            if animated {
                node.alpha = 0
                node.position.y = -3
                node.run(.group([.fadeIn(withDuration: 0.8), .moveTo(y: 0, duration: 0.8)]), withKey: "appear")
            } else {
                node.alpha = 1
                node.position.y = 0
            }
        } else {
            visibleFeatures.remove(feature)
            if animated {
                node.run(.sequence([.fadeOut(withDuration: 0.6), .hide()]), withKey: "appear")
            } else {
                node.isHidden = true
            }
        }
    }

    private func applyPhase(_ phase: DayPhase, lateNight: Bool, animated: Bool) {
        let tint: (NSColor, CGFloat)
        switch phase {
        case .dawn: tint = (NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.62, alpha: 1), 0.18)
        case .day: tint = (.white, 0)
        case .dusk: tint = (NSColor(calibratedRed: 0.95, green: 0.52, blue: 0.45, alpha: 1), 0.28)
        case .night: tint = (NSColor(calibratedRed: 0.16, green: 0.2, blue: 0.42, alpha: 1), 0.5)
        }
        let duration = animated ? 3.0 : 0
        for node in tintables {
            node.removeAction(forKey: "tint")
            if animated {
                node.run(.colorize(with: tint.0, colorBlendFactor: tint.1, duration: duration), withKey: "tint")
            } else {
                node.color = tint.0
                node.colorBlendFactor = tint.1
            }
        }
        let lightsOn: CGFloat = phase.lightsOn ? 1 : 0
        for (_, light) in houseLights { fade(light, to: lateNight ? 0 : lightsOn, duration: duration) }
        fade(lampGlow, to: lightsOn, duration: duration)
        fade(starField, to: phase == .night ? 1 : 0, duration: duration)
        fade(sun, to: phase == .night ? 0 : 1, duration: duration)
        fade(moon, to: phase == .night ? 1 : 0, duration: duration)
    }

    private func fade(_ node: SKNode, to alpha: CGFloat, duration: TimeInterval) {
        node.removeAction(forKey: "fade")
        if duration > 0 {
            node.run(.fadeAlpha(to: alpha, duration: duration), withKey: "fade")
        } else {
            node.alpha = alpha
        }
    }
}

/// A villager walking a pre-built loop of stops. The loop is one repeating SKAction,
/// rebuilt only when the set of stops changes.
final class Resident {
    let node: SKSpriteNode
    private let idle: SKTexture
    private let walk: [SKTexture]
    private var rng: SplitMix64
    private static let pathY: CGFloat = 6
    private static let speed: CGFloat = 5 // pixels per second

    init(idle: SKTexture, walk: [SKTexture], startX: CGFloat, seed: UInt64) {
        self.idle = idle
        self.walk = walk
        self.rng = SplitMix64(seed: seed)
        node = SKSpriteNode(texture: idle)
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        node.position = CGPoint(x: startX, y: Self.pathY)
        node.zPosition = 100 - Self.pathY
    }

    func startRoute(stops: [CGFloat]) {
        guard !stops.isEmpty else { return }
        let start = node.position.x
        var x = start
        var steps: [SKAction] = []
        let targets = (0..<10).map { _ in stops[Int(rng.next() % UInt64(stops.count))] } + [start]
        for target in targets where abs(target - x) >= 1 {
            let duration = Double(abs(target - x) / Self.speed)
            let walkCycle = SKAction.animate(with: walk, timePerFrame: 0.25)
            steps.append(.scaleX(to: target < x ? -1 : 1, duration: 0))
            steps.append(.group([
                .moveTo(x: target, duration: duration),
                .repeat(walkCycle, count: max(1, Int(duration / 0.5))),
            ]))
            steps.append(.setTexture(idle))
            steps.append(.wait(forDuration: 2 + Double(rng.next() % 50) / 10))
            x = target
        }
        node.removeAction(forKey: "route")
        guard !steps.isEmpty else { return }
        node.run(.repeatForever(.sequence(steps)), withKey: "route")
    }
}

/// Tiny deterministic RNG so routes don't depend on global random state.
struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
