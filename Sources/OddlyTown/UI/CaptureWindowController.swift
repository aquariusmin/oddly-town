import AppKit
import SpriteKit
import OddlyTownCore

/// Borderless so nothing but the town ends up in a recording, yet still able to take
/// key presses: every Capture Studio control is a keyboard shortcut.
final class CaptureWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Forwards key presses, moves the window on drag, and hides the pointer while it's
/// over the town so it never shows up in a take.
final class CaptureView: SKView {
    var onKey: ((NSEvent) -> Void)?
    private var tracking: NSTrackingArea?
    private(set) var cursorHidden = false

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func keyDown(with event: NSEvent) { onKey?(event) }

    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { setCursorHidden(true) }
    override func mouseExited(with event: NSEvent) { setCursorHidden(false) }

    func setCursorHidden(_ hidden: Bool) {
        guard hidden != cursorHidden else { return }
        cursorHidden = hidden
        hidden ? NSCursor.hide() : NSCursor.unhide()
    }
}

/// Capture Studio (Developer → Capture Studio…): a clean, UI-free view of the Demo town
/// for screen recording. Integer scales only (2×/3×/4× points per art pixel, plus 1–4×
/// close-up zoom), a pixel-snapped follow camera, and a sky/key/studio backdrop.
/// Separate from Ambient Mode; created on open and torn down on close.
@MainActor
final class CaptureWindowController: NSObject, NSWindowDelegate {
    static let framesPerSecond = 60

    let scene: TownScene
    let rig: CaptureRig
    var onClose: (() -> Void)?
    private(set) var showsTag = true

    private unowned let controller: AppController
    private let window: CaptureWindow
    private let view: CaptureView
    private var framing: CaptureFraming = .vertical
    private var requestedScale = 4
    private var showsHelp = true
    private var presetTitle = CapturePreset.all[0].title
    private var activity: ResidentActivity?
    private var eventIndex = 0
    private var decorIndex = 0

    init(controller: AppController) {
        self.controller = controller
        let screen = NSScreen.main
        // Defaults match `framing` and `requestedScale` (self isn't available before super.init).
        let scale = CaptureLayout.pointScale(requested: 4, framing: .vertical,
                                             fitting: screen?.visibleFrame.size ?? CGSize(width: 1440, height: 900))
        let size = CaptureLayout.viewSize(framing: .vertical, pointScale: scale)
        rig = CaptureRig(pointScale: scale, zoom: 1, focus: .town, background: .sky,
                         devicePixelsPerPoint: screen?.backingScaleFactor ?? 2)
        scene = TownScene(pixelScale: scale, interactive: false)
        view = CaptureView(frame: NSRect(origin: .zero, size: size))
        view.preferredFramesPerSecond = Self.framesPerSecond
        view.ignoresSiblingOrder = false
        window = CaptureWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless],
                               backing: .buffered, defer: false)
        super.init()

        window.contentView = view
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.hasShadow = false
        window.backgroundColor = .black
        window.title = "Oddly Town Capture Studio"
        window.collectionBehavior = [.fullScreenNone]
        window.center()
        scene.enterCapture(rig, viewSize: size)
        view.presentScene(scene)
        view.onKey = { [weak self] event in self?.handle(event) }
    }

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        updateHelp()
    }

    func close() { window.close() }

    func windowWillClose(_ notification: Notification) {
        view.setCursorHidden(false)
        view.isPaused = true
        view.presentScene(nil)
        onClose?()
    }

    /// Called by AppController after it applied a preset to the Demo state.
    func didApply(_ preset: CapturePreset) {
        presetTitle = preset.title
        activity = preset.residents
        rig.zoom = preset.zoom
        rig.focus = preset.focus
        relayout()
    }

    // MARK: Shortcuts

    private func handle(_ event: NSEvent) {
        switch event.keyCode {
        case 53: close(); return                          // Esc
        case 123: nudge(dx: -1, dy: 0); return            // ←
        case 124: nudge(dx: 1, dy: 0); return             // →
        case 125: nudge(dx: 0, dy: -1); return            // ↓
        case 126: nudge(dx: 0, dy: 1); return             // ↑
        default: break
        }
        guard let key = event.charactersIgnoringModifiers?.lowercased(), let ch = key.first else { return }

        if let preset = CapturePreset.all.first(where: { $0.key == key }) {
            controller.applyCapturePreset(preset)
            return
        }
        switch ch {
        case "l":
            let level = controller.demo?.level ?? 1
            controller.setDemoLevel(level % controller.engine.rules.maxLevel + 1)
        case "d": setPhase(.day, instant: event.modifierFlags.contains(.shift))
        case "s": setPhase(.dusk, instant: event.modifierFlags.contains(.shift))
        case "n": setPhase(.night, instant: event.modifierFlags.contains(.shift))
        case "m": setPhase(.dawn, instant: event.modifierFlags.contains(.shift))
        case "c": controller.toggleDemoCycle()
        case "e": controller.setDemoSeason(controller.currentSeason.next)
        case "r":
            let all = ResidentActivity.allCases
            let next = activity.map { all[((all.firstIndex(of: $0) ?? 0) + 1) % all.count] } ?? all[0]
            activity = next
            controller.demoResidents(next)
        case "v":
            let kinds = TownEventKind.allCases
            controller.demoTriggerEvent(kinds[eventIndex % kinds.count])
            eventIndex += 1
        case "o":
            decorIndex = (decorIndex + 1) % CapturePreset.decorSets.count
            controller.setDemoDecor(CapturePreset.decorSets[decorIndex])
        case "g":
            let on = controller.demo?.extras.isEmpty == false
            controller.setDemoExtras(on ? [] : CapturePreset.activityFeatures)
        case "z":
            let zooms = CaptureLayout.zooms
            rig.zoom = zooms[((zooms.firstIndex(of: rig.zoom) ?? 0) + 1) % zooms.count]
            relayout()
        case "f":
            switch rig.focus {
            case .town, .point: rig.focus = .resident(0)
            case .resident(let i): rig.focus = i + 1 < 3 ? .resident(i + 1) : .town
            }
        case "x":
            framing = framing.next
            relayout()
        case "=", "+":
            requestedScale = min(requestedScale + 1, CaptureLayout.pointScales.max() ?? 4)
            relayout()
        case "-":
            requestedScale = max(requestedScale - 1, CaptureLayout.pointScales.min() ?? 2)
            relayout()
        case "b": scene.setCaptureBackground(rig.background.next)
        case "t":
            showsTag.toggle()
            controller.refreshCaptureTag()
        case "h", "/", "?": showsHelp.toggle()
        case " ": scene.setAnimating(!scene.animating)
        default: return
        }
        updateHelp()
    }

    /// Light changes fade over 3 s; with Shift they switch on the spot (for hard cuts).
    private func setPhase(_ phase: DayPhase, instant: Bool) {
        let wasAnimating = scene.animating
        if instant { scene.setAnimating(false) } // a paused scene applies snapshots without animation
        controller.setDemoPhase(phase)
        if instant { scene.setAnimating(wasAnimating) }
    }

    /// Arrow keys move the camera one art pixel (only while not following a resident).
    private func nudge(dx: Double, dy: Double) {
        let p = scene.captureFocusPoint(rig.focus)
        rig.focus = .point(x: Double(p.x.rounded()) + dx, y: Double(p.y.rounded()) + dy)
        updateHelp()
    }

    private func relayout() {
        let available = window.screen?.visibleFrame.size ?? NSScreen.main?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
        rig.pointScale = CaptureLayout.pointScale(requested: requestedScale, framing: framing, fitting: available)
        let size = CaptureLayout.viewSize(framing: framing, pointScale: rig.pointScale)
        let topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
        window.setContentSize(size)
        window.setFrameTopLeftPoint(topLeft)
        view.frame = NSRect(origin: .zero, size: size)
        scene.layoutCapture(viewSize: size)
        updateHelp()
    }

    private func updateHelp() {
        guard showsHelp else {
            scene.setCaptureHelp(nil)
            return
        }
        let devicePx = rig.worldScale * Int(rig.devicePixelsPerPoint)
        let size = CaptureLayout.viewSize(framing: framing, pointScale: rig.pointScale)
        let recorded = "\(Int(size.width) * Int(rig.devicePixelsPerPoint))×\(Int(size.height) * Int(rig.devicePixelsPerPoint)) px"
        let demo = controller.demo
        let focus: String
        switch rig.focus {
        case .town: focus = "town"
        case .point(let x, let y): focus = "(\(Int(x)), \(Int(y)))"
        case .resident(let i): focus = TownArt.residentLooks[i].name
        }
        scene.setCaptureHelp("""
        CAPTURE STUDIO  \(framing.displayName) · \(rig.pointScale)× · zoom \(rig.zoom) · \(devicePx) px per art px · \(recorded)
        \(presetTitle) · Level \(demo?.level ?? 1) · \(demo?.phase?.rawValue ?? "real clock") · \(controller.currentSeason.rawValue)\(demo?.season == nil ? " (calendar)" : "") · residents: \(activity?.rawValue ?? "normal") · focus: \(focus) · \(rig.background.rawValue)
        1-6 presets   L level   D/S/N/M day/dusk/night/dawn (Shift = instant)   C cycle   E season
        R residents   V event   O decorations   G activity buildings
        Z zoom   F follow   arrows move   X framing   +/- scale   B backdrop
        T DEMO tag   Space pause   H hide this   Esc close
        """)
    }
}
