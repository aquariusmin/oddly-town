import SpriteKit
import OddlyTownCore

/// Capture Studio state that lives on its scene: framing numbers, the follow camera,
/// a backdrop filling the whole view, and the help overlay. Ambient Mode and Town Mode
/// never create one.
final class CaptureRig {
    var pointScale: Int
    var zoom: Int
    var focus: CaptureFocus
    var background: CaptureBackground
    let devicePixelsPerPoint: CGFloat
    var phase: DayPhase = .day
    /// Smoothed world origin; nil makes the next frame jump straight to the target (a cut).
    var camera: CGPoint?

    let backdrop = SKSpriteNode()
    let previousBackdrop = SKSpriteNode()
    let stars = SKNode()
    let help = SKLabelNode(fontNamed: "Menlo")
    let helpBox = SKShapeNode()

    var worldScale: Int { pointScale * zoom }

    init(pointScale: Int, zoom: Int, focus: CaptureFocus, background: CaptureBackground, devicePixelsPerPoint: CGFloat) {
        self.pointScale = pointScale
        self.zoom = zoom
        self.focus = focus
        self.background = background
        self.devicePixelsPerPoint = devicePixelsPerPoint
    }
}

extension TownScene {
    func enterCapture(_ rig: CaptureRig, viewSize: CGSize) {
        capture = rig
        rig.previousBackdrop.zPosition = -1001
        rig.backdrop.zPosition = -1000
        rig.stars.zPosition = -999
        for node in [rig.previousBackdrop, rig.backdrop] {
            node.anchorPoint = .zero
            node.position = .zero
            addChild(node)
        }
        addChild(rig.stars)

        rig.helpBox.fillColor = NSColor(calibratedWhite: 0.05, alpha: 0.85)
        rig.helpBox.strokeColor = .clear
        rig.helpBox.zPosition = 2000
        rig.helpBox.isHidden = true
        rig.help.numberOfLines = 0
        rig.help.fontColor = .white
        rig.help.horizontalAlignmentMode = .left
        rig.help.verticalAlignmentMode = .bottom
        rig.helpBox.addChild(rig.help)
        addChild(rig.helpBox)

        layoutCapture(viewSize: viewSize)
    }

    /// Call after framing, scale or zoom change. Cuts the camera (no glide).
    func layoutCapture(viewSize: CGSize) {
        guard let rig = capture else { return }
        size = viewSize
        world.setScale(CGFloat(rig.worldScale))
        for node in [rig.previousBackdrop, rig.backdrop] { node.size = viewSize }
        rig.backdrop.texture = captureBackdropTexture(rig.background, rig.phase)
        rig.backdrop.alpha = 1
        rig.previousBackdrop.alpha = 0
        rebuildCaptureStars(viewSize: viewSize, pixel: CGFloat(rig.pointScale))

        let p = CGFloat(rig.pointScale)
        tagLabel.fontSize = 4 * p
        tagLabel.position = CGPoint(x: 4 * p, y: viewSize.height - 4 * p)
        rig.help.fontSize = 11
        rig.camera = nil
        stepCaptureCamera()
    }

    /// Shows (or hides with nil) the help overlay at the bottom-left.
    func setCaptureHelp(_ text: String?) {
        guard let rig = capture else { return }
        rig.helpBox.isHidden = text == nil
        guard let text else { return }
        rig.help.text = text
        let frame = rig.help.frame
        let pad: CGFloat = 10
        rig.helpBox.path = CGPath(roundedRect: CGRect(x: -pad, y: -pad, width: frame.width + pad * 2, height: frame.height + pad * 2),
                                  cornerWidth: 8, cornerHeight: 8, transform: nil)
        rig.helpBox.position = CGPoint(x: 18, y: 18)
    }

    func setCaptureBackground(_ background: CaptureBackground) {
        guard let rig = capture else { return }
        rig.background = background
        rig.backdrop.texture = captureBackdropTexture(background, rig.phase)
        rig.stars.alpha = background == .sky && rig.phase == .night ? 1 : 0
    }

    /// Cross-fades the sky backdrop with the town's own light change.
    func captureBackdropFollow(_ phase: DayPhase, animated: Bool) {
        guard let rig = capture else { return }
        rig.phase = phase
        let next = captureBackdropTexture(rig.background, phase)
        if animated && rig.background == .sky {
            rig.previousBackdrop.texture = rig.backdrop.texture
            rig.previousBackdrop.alpha = 1
            rig.backdrop.texture = next
            rig.backdrop.alpha = 0
            rig.backdrop.run(.fadeIn(withDuration: 3.0))
        } else {
            rig.backdrop.texture = next
        }
        fade(rig.stars, to: rig.background == .sky && phase == .night ? 1 : 0, duration: animated ? 3.0 : 0)
    }

    /// Keeps the focus centred, gliding toward it and landing on whole device pixels.
    func stepCaptureCamera() {
        guard let rig = capture else { return }
        let target = CaptureLayout.worldOrigin(focus: captureFocusPoint(rig.focus), viewSize: size,
                                               worldScale: rig.worldScale, devicePixelsPerPoint: rig.devicePixelsPerPoint)
        let current: CGPoint
        if let camera = rig.camera {
            current = CGPoint(x: camera.x + (target.x - camera.x) * 0.12, y: camera.y + (target.y - camera.y) * 0.12)
        } else {
            current = target
        }
        rig.camera = current
        world.position = CaptureLayout.snapped(current, devicePixelsPerPoint: rig.devicePixelsPerPoint)
    }

    /// The art-pixel point the camera should centre.
    func captureFocusPoint(_ focus: CaptureFocus) -> CGPoint {
        switch focus {
        case .town:
            return CaptureLayout.townCentre
        case .point(let x, let y):
            return CGPoint(x: x, y: y)
        case .resident(let index):
            guard residents.indices.contains(index), !residents[index].node.isHidden, residents[index].node.alpha > 0.5
            else { return CaptureLayout.townCentre }
            let p = residents[index].node.position
            return CGPoint(x: p.x, y: p.y + 6)
        }
    }

    private func rebuildCaptureStars(viewSize: CGSize, pixel: CGFloat) {
        guard let rig = capture else { return }
        rig.stars.removeAllChildren()
        // Fixed spots (fractions of the view) so the sky looks the same every take.
        let spots: [(CGFloat, CGFloat)] = [
            (0.06, 0.93), (0.18, 0.86), (0.31, 0.95), (0.44, 0.88), (0.57, 0.97), (0.69, 0.84), (0.83, 0.92),
            (0.94, 0.87), (0.11, 0.76), (0.26, 0.71), (0.52, 0.78), (0.78, 0.74), (0.91, 0.66), (0.04, 0.62),
            (0.38, 0.64), (0.64, 0.6), (0.2, 0.55), (0.86, 0.52), (0.47, 0.5), (0.72, 0.9),
        ]
        for (index, (fx, fy)) in spots.enumerated() {
            let star = SKSpriteNode(color: NSColor(calibratedRed: 1, green: 0.96, blue: 0.85, alpha: 1),
                                    size: CGSize(width: pixel, height: pixel))
            star.anchorPoint = .zero
            star.position = CGPoint(x: (fx * viewSize.width / pixel).rounded() * pixel,
                                    y: (fy * viewSize.height / pixel).rounded() * pixel)
            rig.stars.addChild(star)
            star.run(.repeatForever(.sequence([
                .wait(forDuration: 1.1 + Double(index % 5) * 0.6),
                .fadeAlpha(to: 0.3, duration: 0.9),
                .fadeAlpha(to: 1, duration: 0.9),
            ])))
        }
        rig.stars.alpha = rig.background == .sky && rig.phase == .night ? 1 : 0
    }

    /// Stepped vertical gradients (hard pixel bands), or flat magenta for keying.
    private func captureBackdropTexture(_ background: CaptureBackground, _ phase: DayPhase) -> SKTexture {
        let stops: (top: UInt32, bottom: UInt32)
        switch background {
        case .key:
            return TownArt.cached("capture-key") { PixelArt.make(width: 1, height: 1) { _, _ in (0xFF00FF, 1) } }
        case .studio:
            stops = (0x121831, 0x2C3563)
        case .sky:
            switch phase {
            case .dawn: stops = (0x8FA3D6, 0xF5C8B3)
            case .day: stops = (0x5FA8E8, 0xCFEAF6)
            case .dusk: stops = (0x4A4B8B, 0xEF9F7C)
            case .night: stops = (0x0A1233, 0x27356F)
            }
        }
        let key = "capture-\(background.rawValue)-\(background == .sky ? phase.rawValue : "")"
        return TownArt.cached(key) {
            let bands = 12
            return PixelArt.make(width: 1, height: bands) { _, y in
                let t = Double(y) / Double(bands - 1)
                func mix(_ shift: UInt32) -> UInt32 {
                    let a = Double((stops.top >> shift) & 0xFF), b = Double((stops.bottom >> shift) & 0xFF)
                    return UInt32((a + (b - a) * t).rounded()) << shift
                }
                return (mix(16) | mix(8) | mix(0), 1)
            }
        }
    }
}
