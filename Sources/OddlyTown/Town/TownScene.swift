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
    /// Two residents decided to chat (for the town journal). Gatherings don't count.
    var onChat: ((Int, Int) -> Void)?

    let world = SKNode()
    let sky = SKNode()
    let starField = SKNode()
    let fireflies = SKNode()
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
    /// Capture Studio only: full-view backdrop and camera (nil in Ambient and Town Mode).
    var capture: CaptureRig?

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

    private var bubbleFontSize: CGFloat = 9
    private(set) var snapshot: TownSnapshot?
    private(set) var animating = true

    /// Decorative motion that loops forever: drifting clouds, swaying trees, chimney smoke,
    /// fluttering bunting, twinkling stars, fireflies and the selection arrow's bob.
    /// "Reduce Motion" freezes these one by one (not their containers, which still run the
    /// day/night fades). Residents, visitors and fades keep going: they are the town's life.
    private var ambientLoops: [SKNode] = []
    private(set) var reducesMotion = false

    /// Re-textures one seasonal sprite (ground, trees, houses, props). Nodes stay; only
    /// their textures change, once per season.
    private var seasonalSprites: [(Season) -> Void] = []
    private(set) var season: Season = .summer

    /// Rain or snow: a few prebuilt particles that loop down the view. Reduce Motion hides
    /// them (the grey tint and umbrellas still say it's raining).
    private let weatherLayer = SKNode()
    private var weatherParticles: [SKSpriteNode] = []
    private static let weatherParticleCount = 28
    private(set) var weather: Weather = .clear

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

    /// Follows the system's Reduce Motion setting (Capture Studio never calls this).
    func setReduceMotion(_ on: Bool) {
        reducesMotion = on
        for node in ambientLoops { node.isPaused = on }
        weatherLayer.isHidden = on
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
        if next.season != season {
            applySeason(next.season)
        }
        if next.weather != weather {
            applyWeather(next.weather, animated: animated)
        }
        if previous?.phase != next.phase || previous?.lateNight != next.lateNight || previous?.weather != next.weather {
            applyPhase(next.phase, lateNight: next.lateNight, weather: next.weather, animated: animated)
        }
        // Residents pick up the new world (evening, a new building) at their next decision.
        lifeContext = LifeContext(snapshot: next)
        if previous?.residentCount != next.residentCount {
            updateResidentCount(next.residentCount, firstTime: previous == nil)
        }
    }

    func showStatus(_ text: String) {
        // Long lines (journal) shrink a little, then get cut with "…", so the bubble fits the view.
        bubbleLabel.fontSize = bubbleFontSize
        bubbleLabel.text = text
        let maxWidth = size.width - 6
        func natural() -> CGFloat { bubbleLabel.frame.width + bubbleLabel.fontSize * 1.8 }
        if natural() > maxWidth {
            bubbleLabel.fontSize = max(7, bubbleLabel.fontSize * maxWidth / natural())
        }
        var shortened = text
        while natural() > maxWidth && shortened.count > 8 {
            shortened = String(shortened.dropLast(2))
            bubbleLabel.text = shortened + "…"
        }
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

    /// Only Capture Studio has per-frame work (the follow camera); other modes return at once.
    override func didFinishUpdate() {
        guard capture != nil else { return }
        stepCaptureCamera()
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
        buildWeather()
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
            ambientLoops.append(star)
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
        let halo = SKSpriteNode(texture: TownArt.cached("moon-halo") { PixelArt.glow(radius: 7, rgb: 0xF4F1DE) })
        halo.position = CGPoint(x: 3.5, y: 3.5)
        halo.zPosition = -1
        moon.addChild(halo)

        // Fireflies drift around the trees and flowers at night.
        let fly = TownArt.tex("firefly", ["c"], palette: ["c": 0xE8F57A])
        let homes: [(CGFloat, CGFloat)] = [(6, 18), (12, 24), (37, 20), (44, 26), (70, 17), (58, 14), (128, 16)]
        for (index, (x, y)) in homes.enumerated() {
            let node = SKSpriteNode(texture: fly)
            node.anchorPoint = .zero
            node.position = CGPoint(x: x, y: y)
            node.zPosition = 99
            fireflies.addChild(node)
            let dx = CGFloat(index % 3) - 1, dy = CGFloat(index % 2 == 0 ? 1 : -1)
            let wander = SKAction.sequence([
                .moveBy(x: 2 + dx, y: 2 * dy, duration: 1.7 + Double(index) * 0.2),
                .moveBy(x: -1, y: -dy, duration: 1.3),
                .moveBy(x: -(1 + dx), y: -dy, duration: 1.5 + Double(index % 3) * 0.3),
            ])
            let blink = SKAction.sequence([
                .wait(forDuration: 0.6 + Double(index) * 0.45),
                .fadeAlpha(to: 0.15, duration: 0.5),
                .fadeAlpha(to: 1, duration: 0.4),
            ])
            node.run(.repeatForever(wander))
            node.run(.repeatForever(blink))
            ambientLoops.append(node)
        }
        fireflies.alpha = 0
        world.addChild(fireflies)

        let clouds: [(name: String, rows: [String], x: CGFloat, y: CGFloat, speed: CGFloat)] = [
            ("cloud", TownArt.cloudRows, 18, 47, 1.6),
            ("cloud-small", TownArt.smallCloudRows, 82, 53, 1.1),
            ("cloud-small", TownArt.smallCloudRows, 120, 41, 2.0),
        ]
        for cloud in clouds {
            let node = sprite(TownArt.tex(cloud.name, cloud.rows), left: cloud.x, y: cloud.y, z: -40, parent: sky)
            let start: CGFloat = -20, end: CGFloat = 150
            ambientLoops.append(node)
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
        seasonalSprite("ground", TownArt.groundRows(), role: .ground, left: 0, y: 0, z: -20)
    }

    private func buildBaseTown() {
        swayingTree(TownArt.treeRows, name: "tree", centerX: 8, y: 12, period: 1.6)
        let cottage = house(TownArt.cottageRows, palette: TownArt.palette, name: "cottage", left: 14, doorX: 21,
                            owner: nil, parent: world)
        cottageBounds = cottage.frame
        seasonalSprite("mailbox", TownArt.mailboxRows, role: .structure, left: 31, y: 12)
        swayingTree(TownArt.treeRows, name: "tree", centerX: 39, y: 12, period: 2.1)
        seasonalSprite("rock", TownArt.rockRows, role: .structure, left: 132, y: 12)
    }

    private func buildLevelFeatures() {
        let youngTree = featureNode(.youngTree)
        swayingTree(TownArt.youngTreeRows, name: "young-tree", centerX: 74, y: 13, period: 1.8, parent: youngTree)

        let fence = featureNode(.picketFence)
        seasonalSprite("fence", TownArt.fenceRows, role: .structure, left: 112, y: 3, parent: fence)
        seasonalSprite("fence", TownArt.fenceRows, role: .structure, left: 123, y: 3, parent: fence)

        let flowers = featureNode(.wildflowers)
        let flowerTexture = TownArt.tex("wildflowers", TownArt.wildflowerRows)
        sprite(flowerTexture, left: 6, y: 2, parent: flowers)
        sprite(flowerTexture, left: 62, y: 2, parent: flowers)

        let lamp = featureNode(.lamppost)
        sprite(TownArt.tex("lamppost", TownArt.lamppostRows), left: 95, y: 13, parent: lamp)
        lampGlows.append(glow(radius: 5, center: CGPoint(x: 96.5, y: 22.5), parent: lamp))
        lampGlows.append(groundLight(centerX: 96.5, y: 5, width: 19, parent: lamp))

        let secondHouse = featureNode(.secondHouse)
        house(TownArt.blueHouseRows, palette: TownArt.blueHousePalette, name: "house-blue", left: 78, doorX: 85,
              owner: .secondHouse, parent: secondHouse)

        let well = featureNode(.well)
        seasonalSprite("well", TownArt.wellRows, role: .structure, left: 62, y: 13, parent: well)

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
            ambientLoops.append(smoke)
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
        ambientLoops.append(flags)
    }

    private func buildDecorSlots() {
        for origin in TownArt.decorSlots {
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
                    slotGlows.append(groundLight(centerX: origin.x + 1.5, y: origin.y - 1, width: 11, parent: holder))
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
            tintables.append(resident.umbrella)
            resident.onFinished = { [weak self] finished in self?.residentFinished(finished) }
            residents.append(resident)
        }
    }

    private func buildWeather() {
        weatherLayer.zPosition = 160 // in front of the town, behind the selection arrow
        weatherLayer.alpha = 0
        world.addChild(weatherLayer)
        for _ in 0..<Self.weatherParticleCount {
            let particle = SKSpriteNode(texture: TownArt.raindrop)
            particle.anchorPoint = .zero
            weatherLayer.addChild(particle)
            weatherParticles.append(particle)
            ambientLoops.append(particle)
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
        ambientLoops.append(selectionArrow)
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
        bubbleFontSize = min(max(4.5 * s, 9), 15)
        bubbleLabel.fontSize = bubbleFontSize
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
        let body = seasonalSprite(name, rows, palette: palette, role: .structure, left: left, y: 13, parent: parent)
        seasonalSprite("path-branch", TownArt.pathBranchRows, role: .ground, left: doorX, y: 8, z: -10, parent: parent)
        let windows = sprite(TownArt.lights(name, rows), left: left, y: 13, z: body.zPosition + 0.5, tint: false, parent: parent)
        windows.alpha = 0
        lights.append((owner, windows))
        for center in TownArt.windowCenters(rows) {
            let halo = glow(radius: 3, center: CGPoint(x: left + center.x, y: 13 + center.y), parent: parent)
            lights.append((owner, halo))
        }
        // Warm light spilling from the door onto the path.
        lights.append((owner, groundLight(centerX: doorX + 1, y: 5, width: 11, parent: parent)))
        if let owner { featureBounds[owner] = body.frame }
        return body
    }

    private func swayingTree(_ rows: [String], name: String, centerX: CGFloat, y: CGFloat, period: Double,
                             parent: SKNode? = nil) {
        let swayRows = PixelArt.shiftRows(rows, 0..<5, by: 1)
        let frames = { (season: Season) in
            [TownArt.seasonal(name, rows, role: .foliage, season: season),
             TownArt.seasonal("\(name)-sway", swayRows, role: .foliage, season: season)]
        }
        let width = CGFloat(rows.map(\.count).max() ?? 0)
        let tree = sprite(frames(season)[0], left: (centerX - width / 2).rounded(.down), y: y, parent: parent)
        tree.run(.repeatForever(.animate(with: frames(season), timePerFrame: period)), withKey: "sway")
        ambientLoops.append(tree)
        seasonalSprites.append { season in
            let next = frames(season)
            tree.texture = next[0]
            tree.run(.repeatForever(.animate(with: next, timePerFrame: period)), withKey: "sway")
        }
    }

    /// A sprite that follows the seasons (see `TownArt.seasonal`).
    @discardableResult
    private func seasonalSprite(_ name: String, _ rows: [String], palette: [Character: UInt32] = TownArt.palette,
                                role: SeasonRole, left: CGFloat, y: CGFloat, z: CGFloat? = nil,
                                parent: SKNode? = nil) -> SKSpriteNode {
        let node = sprite(TownArt.seasonal(name, rows, palette: palette, role: role, season: season),
                          left: left, y: y, z: z, parent: parent)
        seasonalSprites.append { season in
            node.texture = TownArt.seasonal(name, rows, palette: palette, role: role, season: season)
        }
        return node
    }

    private func applyWeather(_ next: Weather, animated: Bool) {
        weather = next
        let fadeTime = animated ? 1.5 : 0
        weatherLayer.removeAction(forKey: "stop")
        if next.isWet {
            startParticles(next)
        } else {
            // Let the last drops keep falling while the layer fades, then stop them.
            weatherLayer.run(.sequence([.wait(forDuration: fadeTime), .run { [weak self] in self?.stopParticles() }]),
                             withKey: "stop")
        }
        fade(weatherLayer, to: next.isWet ? 1 : 0, duration: fadeTime)
        for resident in residents { resident.setUmbrella(next == .rain) }
        if selectionArrow.parent !== world, selectionArrow.parent != nil {
            selectionArrow.position.y = residentArrowHeight
        }
    }

    /// Above a resident's head, or above the umbrella in the rain.
    var residentArrowHeight: CGFloat { weather == .rain ? 16 : 11 }

    /// Each particle falls from above the town to the ground on its own lane and period,
    /// starting part-way down so the view fills at once. Rain streaks down at a slant;
    /// snow drifts slowly side to side.
    private func startParticles(_ weather: Weather) {
        let top: CGFloat = 62
        for (i, particle) in weatherParticles.enumerated() {
            particle.removeAction(forKey: "fall")
            let texture = weather == .snow ? TownArt.snowflake : TownArt.raindrop
            particle.texture = texture
            particle.size = texture.size()
            let x = CGFloat((i * 47 + 13) % 150) - 5
            let bottom = CGFloat(3 + (i * 7) % 11)
            let drop = bottom - top
            let progress = CGFloat((i * 5) % 11) / 11
            let period: Double
            let slant: CGFloat
            if weather == .rain {
                period = 0.7 + Double(i % 5) * 0.08
                slant = -3
            } else {
                period = 5 + Double(i % 7) * 0.6
                slant = i % 2 == 0 ? 2 : -2
            }
            let restart = SKAction.move(to: CGPoint(x: x, y: top), duration: 0)
            let fall = SKAction.moveBy(x: slant, y: drop, duration: period)
            particle.position = CGPoint(x: x + slant * progress, y: top + drop * progress)
            let firstFall = SKAction.moveBy(x: slant * (1 - progress), y: drop * (1 - progress),
                                            duration: period * Double(1 - progress))
            particle.run(.sequence([firstFall, .repeatForever(.sequence([restart, fall]))]), withKey: "fall")
        }
    }

    private func stopParticles() {
        for particle in weatherParticles { particle.removeAction(forKey: "fall") }
    }

    private func applySeason(_ next: Season) {
        season = next
        for retexture in seasonalSprites { retexture(next) }
    }

    private func glow(radius: Int, center: CGPoint, parent: SKNode) -> SKSpriteNode {
        let node = SKSpriteNode(texture: TownArt.cached("glow-\(radius)") { PixelArt.glow(radius: radius, rgb: 0xFFD36E) })
        node.position = center
        node.zPosition = 95
        node.alpha = 0
        parent.addChild(node)
        return node
    }

    /// Flat pool of light on the ground (lamps, lanterns, open doors). Starts dark.
    private func groundLight(centerX: CGFloat, y: CGFloat, width: Int, parent: SKNode) -> SKSpriteNode {
        let node = SKSpriteNode(texture: TownArt.cached("ground-light-\(width)") { PixelArt.groundLight(width: width, rgb: 0xFFD36E) })
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        node.position = CGPoint(x: centerX, y: y)
        node.zPosition = -5 // on the ground, under every sprite
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
            if animated && reducesMotion {
                node.alpha = 0
                node.position.y = 0
                node.run(.fadeIn(withDuration: 0.8), withKey: "appear")
            } else if animated {
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

    static func skyColor(_ phase: DayPhase, weather: Weather = .clear) -> NSColor {
        if weather.isWet && (phase == .dawn || phase == .day) {
            return NSColor(calibratedRed: 0.66, green: 0.71, blue: 0.78, alpha: 1)
        }
        switch phase {
        case .dawn: return NSColor(calibratedRed: 0.96, green: 0.80, blue: 0.72, alpha: 1)
        case .day: return NSColor(calibratedRed: 0.76, green: 0.89, blue: 0.95, alpha: 1)
        case .dusk: return NSColor(calibratedRed: 0.90, green: 0.64, blue: 0.58, alpha: 1)
        case .night: return NSColor(calibratedRed: 0.13, green: 0.17, blue: 0.30, alpha: 1)
        }
    }

    private func applyPhase(_ phase: DayPhase, lateNight: Bool, weather: Weather, animated: Bool) {
        var tint: (NSColor, CGFloat)
        switch phase {
        case .dawn: tint = (NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.62, alpha: 1), 0.18)
        case .day: tint = (.white, 0)
        case .dusk: tint = (NSColor(calibratedRed: 0.95, green: 0.52, blue: 0.45, alpha: 1), 0.28)
        case .night: tint = (NSColor(calibratedRed: 0.16, green: 0.2, blue: 0.42, alpha: 1), 0.5)
        }
        // Overcast: a grey wash by day, a deeper dusk. Night already looks wet enough.
        if weather.isWet {
            switch phase {
            case .dawn, .day: tint = (NSColor(calibratedRed: 0.55, green: 0.6, blue: 0.7, alpha: 1), 0.3)
            case .dusk: tint.1 = 0.4
            case .night: break
            }
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
                backdrop.run(.colorize(with: Self.skyColor(phase, weather: weather), colorBlendFactor: 1, duration: duration), withKey: "tint")
            } else {
                backdrop.color = Self.skyColor(phase, weather: weather)
            }
        }
        let lightsOn: CGFloat = phase.lightsOn ? 1 : 0
        // Houses go dark late at night; the workshop and nook windows too. Lamps stay lit.
        for light in lights { fade(light.node, to: lateNight ? 0 : lightsOn, duration: duration) }
        for glow in lampGlows + slotGlows { fade(glow, to: lightsOn, duration: duration) }
        fade(starField, to: phase == .night ? 1 : 0, duration: duration)
        fade(fireflies, to: phase == .night ? 1 : 0, duration: duration)
        captureBackdropFollow(phase, animated: animated)
        fade(sun, to: phase == .night || weather.isWet ? 0 : 1, duration: duration)
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
