import SpriteKit
import OddlyTownCore

/// What the user clicked in Town Mode.
enum TownSelection: Equatable {
    case resident(Int)
    case feature(TownFeature)
    case cottage
    case slot(Int)
}

/// Renders a `TownSnapshot`. Every node is created once in `build()`; snapshots only
/// show/hide nodes and retint them, and textures come from a shared cache, so nothing
/// piles up while the town runs.
///
/// Coordinates: a 140 × 60 pixel grid inside `world`, scaled by a whole number
/// (2× in Ambient Mode, 6× in Town Mode) so pixels stay crisp.
///
/// The same class draws both modes; `interactive` adds a sky backdrop, slot markers and
/// click selection for Town Mode.
final class TownScene: SKScene {
    static let artSize = CGSize(width: 140, height: 60)
    static let pathY: CGFloat = 6

    let interactive: Bool
    private(set) var pixelScale: Int

    /// Town Mode: something was clicked (nil = empty ground).
    var onSelect: ((TownSelection?) -> Void)?

    let world = SKNode()
    let sky = SKNode()
    let starField = SKNode()
    var tintables: [SKSpriteNode] = []
    var featureNodes: [TownFeature: SKNode] = [:]
    var featureBounds: [TownFeature: CGRect] = [:]
    var cottageBounds = CGRect.zero
    var visibleFeatures: Set<TownFeature> = []
    var lights: [(owner: TownFeature?, node: SKNode)] = []
    var lampGlows: [SKNode] = []
    var sun = SKSpriteNode()
    var moon = SKSpriteNode()
    var backdrop: SKSpriteNode?

    /// Per slot: one prebuilt node per item (only the placed one is shown).
    var slotItems: [[DecorItem: SKNode]] = []
    var slotMarkers: [SKSpriteNode] = []
    var slotGlows: [SKNode] = []

    var residents: [ResidentSprite] = []
    var life = TownLife(seed: 0x0DD1)
    var lifeContext = LifeContext(phase: .day, lateNight: false, features: [], seatSlots: [])

    var catNode = SKSpriteNode()
    var catFrames: (walk: [SKTexture], sit: SKTexture)?
    var travelerNode = SKSpriteNode()
    var travelerFrames: (idle: SKTexture, walk: [SKTexture])?
    var selectionArrow = SKSpriteNode()

    let bubble = SKShapeNode()
    let bubbleLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    let tagLabel = SKLabelNode(fontNamed: "Menlo-Bold")

    private(set) var snapshot: TownSnapshot?
    private(set) var animating = true

    init(pixelScale: Int, interactive: Bool) {
        self.pixelScale = max(1, pixelScale)
        self.interactive = interactive
        super.init(size: CGSize(width: Self.artSize.width * CGFloat(max(1, pixelScale)),
                                height: Self.artSize.height * CGFloat(max(1, pixelScale))))
        backgroundColor = .clear
        anchorPoint = .zero
        scaleMode = .aspectFit
        build()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Public API

    override func mouseDown(with event: NSEvent) {
        guard interactive else { return }
        handleClick(at: event.location(in: world))
    }

    func setPixelScale(_ scale: Int) {
        let scale = max(1, scale)
        guard scale != pixelScale else { return }
        pixelScale = scale
        size = CGSize(width: Self.artSize.width * CGFloat(scale), height: Self.artSize.height * CGFloat(scale))
        world.setScale(CGFloat(scale))
        layoutOverlays()
    }

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
        if previous?.decor != next.decor {
            applyDecor(next.decor)
        }
        if previous?.phase != next.phase || previous?.lateNight != next.lateNight {
            applyPhase(next.phase, lateNight: next.lateNight, animated: animated)
        }
        // Residents pick up the new world (evening, a new building) at their next decision.
        lifeContext = LifeContext(snapshot: next)
        if previous?.residentCount != next.residentCount {
            updateResidentCount(next.residentCount, firstTime: previous == nil)
        }
    }

    func showStatus(_ text: String) {
        bubbleLabel.text = text
        let width = bubbleLabel.frame.width + bubbleLabel.fontSize * 1.8
        let height = bubbleLabel.fontSize * 1.9
        bubble.path = CGPath(
            roundedRect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height),
            cornerWidth: height * 0.4, cornerHeight: height * 0.4, transform: nil
        )
        bubble.removeAllActions()
        bubble.run(.sequence([
            .fadeAlpha(to: 1, duration: 0.15),
            .wait(forDuration: 3.5),
            .fadeAlpha(to: 0, duration: 0.5),
        ]))
    }

    /// Small corner label, e.g. "DEMO", so recorded footage can't be mistaken for real progress.
    func setTag(_ text: String?) {
        tagLabel.text = text
        tagLabel.isHidden = text == nil
    }

    // MARK: Build

    private func build() {
        world.setScale(CGFloat(pixelScale))
        addChild(world)
        world.addChild(sky)
        sky.zPosition = -50
        sky.addChild(starField)

        if interactive {
            let backdrop = SKSpriteNode(color: .white, size: Self.artSize)
            backdrop.anchorPoint = .zero
            backdrop.zPosition = -100
            backdrop.color = Self.skyColor(.day)
            world.addChild(backdrop)
            self.backdrop = backdrop
        }

        buildSky()
        buildGround()
        buildBaseTown()
        buildLevelFeatures()
        buildActivityFeatures()
        buildDecorSlots()
        buildResidents()
        buildVisitors()
        buildOverlays()
    }

    private func buildSky() {
        // Fixed star positions so the night sky looks the same every evening.
        let stars: [(CGFloat, CGFloat)] = [(9, 52), (21, 57), (34, 47), (48, 55), (61, 50), (77, 58), (88, 46),
                                           (101, 54), (113, 49), (120, 57), (68, 41), (17, 43)]
        let starTexture = TownArt.tex("star", ["c"], palette: ["c": 0xFFF6D8])
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

        let clouds: [(name: String, rows: [String], x: CGFloat, y: CGFloat, speed: CGFloat)] = [
            ("cloud", TownArt.cloudRows, 18, 47, 1.6),
            ("cloud-small", TownArt.smallCloudRows, 82, 53, 1.1),
            ("cloud-small", TownArt.smallCloudRows, 120, 41, 2.0),
        ]
        for cloud in clouds {
            let node = sprite(TownArt.tex(cloud.name, cloud.rows), left: cloud.x, y: cloud.y, z: -40, parent: sky)
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
        let cottage = house(TownArt.cottageRows, palette: TownArt.palette, name: "cottage", left: 14, doorX: 21,
                            owner: nil, parent: world)
        cottageBounds = cottage.frame
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
        lampGlows.append(glow(radius: 5, center: CGPoint(x: 96.5, y: 22.5), parent: lamp))

        let secondHouse = featureNode(.secondHouse)
        house(TownArt.blueHouseRows, palette: TownArt.blueHousePalette, name: "house-blue", left: 78, doorX: 85,
              owner: .secondHouse, parent: secondHouse)

        let well = featureNode(.well)
        sprite(TownArt.tex("well", TownArt.wellRows), left: 62, y: 13, parent: well)

        // Residents are drawn separately; these empty containers only exist for selection info.
        _ = featureNode(.secondResident)
        _ = featureNode(.thirdResident)
    }

    private func buildActivityFeatures() {
        // Development → workshop with a smoking chimney.
        let workshop = featureNode(.workshop)
        house(TownArt.workshopRows, palette: TownArt.palette, name: "workshop", left: 99, doorX: 108,
              owner: .workshop, parent: workshop)
        let puff = TownArt.tex("smoke", ["CC", "CC"], palette: ["C": 0xD9D9D9])
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
        house(TownArt.readingNookRows, palette: TownArt.tealRoof, name: "reading-nook", left: 118, doorX: 124,
              owner: .readingNook, parent: nook)

        // Entertainment → festival bunting across the whole town.
        let bunting = featureNode(.festivalBunting)
        let poleTexture = TownArt.tex("pole", TownArt.poleRows)
        sprite(poleTexture, left: 2, y: 13, z: 60, parent: bunting)
        sprite(poleTexture, left: 136, y: 13, z: 60, parent: bunting)
        let frames = [TownArt.cached("bunting-0") { TownArt.buntingTexture(width: 134, frame: 0) },
                      TownArt.cached("bunting-1") { TownArt.buntingTexture(width: 134, frame: 1) }]
        let flags = sprite(frames[0], left: 3, y: 30, z: 61, parent: bunting)
        flags.run(.repeatForever(.animate(with: frames, timePerFrame: 0.7)))
    }

    private func buildDecorSlots() {
        for (index, origin) in TownArt.decorSlots.enumerated() {
            var items: [DecorItem: SKNode] = [:]
            for item in DecorItem.allCases {
                let holder = SKNode()
                holder.isHidden = true
                world.addChild(holder)
                if item == .sapling {
                    swayingTree(TownArt.youngTreeRows, name: "young-tree", centerX: origin.x + 4, y: origin.y, period: 1.9, parent: holder)
                } else {
                    sprite(TownArt.decorTexture(item), left: origin.x, y: origin.y, parent: holder)
                }
                if item == .lantern {
                    slotGlows.append(glow(radius: 4, center: CGPoint(x: origin.x + 1.5, y: origin.y + 5), parent: holder))
                }
                items[item] = holder
            }
            slotItems.append(items)

            let marker = SKSpriteNode(texture: TownArt.emptySlotMarker)
            marker.anchorPoint = .zero
            marker.position = CGPoint(x: origin.x, y: origin.y)
            marker.zPosition = 97
            marker.alpha = 0.55
            marker.isHidden = true
            world.addChild(marker)
            slotMarkers.append(marker)
        }
    }

    private func buildResidents() {
        let startX: [CGFloat] = [30, 100, 86]
        for (index, look) in TownArt.residentLooks.enumerated() {
            let resident = ResidentSprite(index: index, frames: TownArt.residentFrames(look), name: look.name)
            resident.node.position = CGPoint(x: startX[index % startX.count], y: Self.pathY)
            resident.node.isHidden = true
            world.addChild(resident.node)
            tintables.append(resident.node)
            resident.onFinished = { [weak self] finished in self?.residentFinished(finished) }
            residents.append(resident)
        }
    }

    private func buildVisitors() {
        let cat = TownArt.catFrames()
        catFrames = cat
        catNode = SKSpriteNode(texture: cat.sit)
        catNode.anchorPoint = CGPoint(x: 0.5, y: 0)
        catNode.zPosition = 100 - 5
        catNode.isHidden = true
        world.addChild(catNode)
        tintables.append(catNode)

        let traveler = TownArt.travelerFrames()
        travelerFrames = traveler
        travelerNode = SKSpriteNode(texture: traveler.idle)
        travelerNode.anchorPoint = CGPoint(x: 0.5, y: 0)
        travelerNode.zPosition = 100 - Self.pathY + 0.5
        travelerNode.isHidden = true
        world.addChild(travelerNode)
        tintables.append(travelerNode)

        selectionArrow = SKSpriteNode(texture: TownArt.selectionArrow)
        selectionArrow.anchorPoint = CGPoint(x: 0.5, y: 0)
        selectionArrow.zPosition = 200
        selectionArrow.isHidden = true
        world.addChild(selectionArrow)
        selectionArrow.run(.repeatForever(.sequence([.moveBy(x: 0, y: 1, duration: 0.5), .moveBy(x: 0, y: -1, duration: 0.5)])))
    }

    private func buildOverlays() {
        bubble.fillColor = NSColor(calibratedWhite: 0.08, alpha: 0.82)
        bubble.strokeColor = .clear
        bubble.zPosition = 1000
        bubble.alpha = 0
        bubbleLabel.fontColor = .white
        bubbleLabel.verticalAlignmentMode = .center
        bubbleLabel.horizontalAlignmentMode = .center
        bubble.addChild(bubbleLabel)
        addChild(bubble)

        tagLabel.fontColor = NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.2, alpha: 0.9)
        tagLabel.horizontalAlignmentMode = .left
        tagLabel.verticalAlignmentMode = .top
        tagLabel.zPosition = 1000
        tagLabel.isHidden = true
        addChild(tagLabel)
        layoutOverlays()
    }

    private func layoutOverlays() {
        let s = CGFloat(pixelScale)
        bubbleLabel.fontSize = min(max(4.5 * s, 9), 15)
        bubble.position = CGPoint(x: size.width / 2, y: size.height - bubbleLabel.fontSize * 1.4)
        tagLabel.fontSize = min(max(3.5 * s, 7), 12)
        tagLabel.position = CGPoint(x: 2 * s, y: size.height - 2 * s)
    }

    // MARK: Building helpers

    /// Places a sprite by its left edge and base line (whole pixels keep the art crisp).
    /// zPosition defaults to "lower on screen = in front".
    @discardableResult
    func sprite(_ texture: SKTexture, left: CGFloat, y: CGFloat, z: CGFloat? = nil,
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

    @discardableResult
    private func house(_ rows: [String], palette: [Character: UInt32], name: String, left: CGFloat, doorX: CGFloat,
                       owner: TownFeature?, parent: SKNode) -> SKSpriteNode {
        let body = sprite(TownArt.tex(name, rows, palette: palette), left: left, y: 13, parent: parent)
        sprite(TownArt.tex("path-branch", TownArt.pathBranchRows), left: doorX, y: 8, z: -10, parent: parent)
        let windows = sprite(TownArt.lights(name, rows), left: left, y: 13, z: body.zPosition + 0.5, tint: false, parent: parent)
        windows.alpha = 0
        lights.append((owner, windows))
        for center in TownArt.windowCenters(rows) {
            let halo = glow(radius: 3, center: CGPoint(x: left + center.x, y: 13 + center.y), parent: parent)
            lights.append((owner, halo))
        }
        if let owner { featureBounds[owner] = body.frame }
        return body
    }

    private func swayingTree(_ rows: [String], name: String, centerX: CGFloat, y: CGFloat, period: Double,
                             parent: SKNode? = nil) {
        let frames = [TownArt.tex(name, rows),
                      TownArt.cached("\(name)-sway") { PixelArt.texture(PixelArt.shiftRows(rows, 0..<5, by: 1), palette: TownArt.palette) }]
        let width = CGFloat(rows.map(\.count).max() ?? 0)
        let tree = sprite(frames[0], left: (centerX - width / 2).rounded(.down), y: y, parent: parent)
        tree.run(.repeatForever(.animate(with: frames, timePerFrame: period)))
    }

    private func glow(radius: Int, center: CGPoint, parent: SKNode) -> SKSpriteNode {
        let node = SKSpriteNode(texture: TownArt.cached("glow-\(radius)") { PixelArt.glow(radius: radius, rgb: 0xFFD36E) })
        node.position = center
        node.zPosition = 95
        node.alpha = 0
        parent.addChild(node)
        return node
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

    private func applyDecor(_ decor: [Int: DecorItem]) {
        for (slot, items) in slotItems.enumerated() {
            let placed = decor[slot]
            for (item, node) in items { node.isHidden = item != placed }
            slotMarkers[slot].isHidden = !interactive || placed != nil
        }
    }

    static func skyColor(_ phase: DayPhase) -> NSColor {
        switch phase {
        case .dawn: return NSColor(calibratedRed: 0.96, green: 0.80, blue: 0.72, alpha: 1)
        case .day: return NSColor(calibratedRed: 0.76, green: 0.89, blue: 0.95, alpha: 1)
        case .dusk: return NSColor(calibratedRed: 0.90, green: 0.64, blue: 0.58, alpha: 1)
        case .night: return NSColor(calibratedRed: 0.13, green: 0.17, blue: 0.30, alpha: 1)
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
        if let backdrop {
            backdrop.removeAction(forKey: "tint")
            if animated {
                backdrop.run(.colorize(with: Self.skyColor(phase), colorBlendFactor: 1, duration: duration), withKey: "tint")
            } else {
                backdrop.color = Self.skyColor(phase)
            }
        }
        let lightsOn: CGFloat = phase.lightsOn ? 1 : 0
        // Houses go dark late at night; the workshop and nook windows too. Lamps stay lit.
        for light in lights { fade(light.node, to: lateNight ? 0 : lightsOn, duration: duration) }
        for glow in lampGlows + slotGlows { fade(glow, to: lightsOn, duration: duration) }
        fade(starField, to: phase == .night ? 1 : 0, duration: duration)
        fade(sun, to: phase == .night ? 0 : 1, duration: duration)
        fade(moon, to: phase == .night ? 1 : 0, duration: duration)
    }

    func fade(_ node: SKNode, to alpha: CGFloat, duration: TimeInterval) {
        node.removeAction(forKey: "fade")
        if duration > 0 {
            node.run(.fadeAlpha(to: alpha, duration: duration), withKey: "fade")
        } else {
            node.alpha = alpha
        }
    }
}
