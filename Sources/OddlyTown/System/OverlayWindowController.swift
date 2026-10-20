import AppKit
import SpriteKit
import OddlyTownCore

/// Borderless, transparent, non-activating panel: it never takes keyboard focus
/// from the app you're working in.
final class OverlayPanel: NSPanel {
    /// Just above desktop icons: the town sits on the desktop, behind normal windows.
    static let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)

    static func make(size: CGSize) -> OverlayPanel {
        let panel = OverlayPanel(contentRect: NSRect(origin: .zero, size: size),
                                 styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.configure()
        return panel
    }

    private func configure() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        isMovable = false // dragging is handled by TownView so clicks and drags can be told apart
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// SKView that turns a click into `onClick` and a drag into moving the window.
final class TownView: SKView {
    var onClick: (() -> Void)?
    var onDragEnded: (() -> Void)?
    var dragEnabled = true

    private var mouseDownLocation: NSPoint?
    private var windowOriginAtMouseDown: NSPoint?
    private var dragged = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = NSEvent.mouseLocation
        windowOriginAtMouseDown = window?.frame.origin
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragEnabled, let start = mouseDownLocation, let origin = windowOriginAtMouseDown, let window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - start.x, dy = now.y - start.y
        if !dragged && hypot(dx, dy) < 3 { return }
        dragged = true
        window.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        if dragged { onDragEnded?() } else if mouseDownLocation != nil { onClick?() }
        mouseDownLocation = nil
        dragged = false
    }
}

/// Owns the overlay panel and decides when SpriteKit should render at all.
/// Rendering stops when the town is hidden, paused, occluded or the displays sleep.
@MainActor
final class OverlayWindowController: NSObject {
    static let framesPerSecond = 15

    let panel: OverlayPanel
    let townView: TownView
    let scene: TownScene

    var onClick: (() -> Void)?
    var onMoved: ((CGPoint) -> Void)?

    private var settings = AppSettings()
    private var hasPlaced = false
    private var occluded = false
    private var displaysAsleep = false
    private var redrawTimer: Timer?

    override init() {
        let size = TownScene.sceneSize
        panel = OverlayPanel.make(size: size)
        townView = TownView(frame: NSRect(origin: .zero, size: size))
        scene = TownScene(size: size)
        super.init()

        townView.allowsTransparency = true
        townView.preferredFramesPerSecond = Self.framesPerSecond
        townView.autoresizingMask = [.width, .height]
        townView.presentScene(scene)
        panel.contentView = townView

        townView.onClick = { [weak self] in self?.onClick?() }
        townView.onDragEnded = { [weak self] in
            guard let self else { return }
            self.onMoved?(self.panel.frame.origin)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(occlusionChanged),
                                               name: NSWindow.didChangeOcclusionStateNotification, object: panel)
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(displaysDidSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(displaysDidWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    var isAnimating: Bool {
        settings.townVisible && settings.animationsEnabled && !occluded && !displaysAsleep
    }

    func apply(_ new: AppSettings) {
        let old = settings
        settings = new

        panel.ignoresMouseEvents = new.clickThrough
        townView.dragEnabled = !new.clickThrough
        panel.level = new.floatAboveWindows ? .floating : OverlayPanel.desktopLevel
        var behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        if new.showOverFullScreenApps { behavior.insert(.fullScreenAuxiliary) }
        panel.collectionBehavior = behavior

        if !hasPlaced || old.windowWidth != new.windowWidth || old.corner != new.corner || old.customOrigin != new.customOrigin {
            placeWindow(preferPrimary: !hasPlaced)
        }
        if new.townVisible {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
        updateRendering()
    }

    func placeOnPrimaryScreen() {
        placeWindow(preferPrimary: true)
    }

    /// Lets one frame (or a short animation like the status bubble) draw while paused.
    func requestRedraw(for seconds: TimeInterval = 0.5) {
        guard settings.townVisible, townView.isPaused || redrawTimer != nil else { return }
        townView.isPaused = false
        redrawTimer?.invalidate()
        let timer = Timer(timeInterval: seconds, target: self, selector: #selector(redrawExpired), userInfo: nil, repeats: false)
        RunLoop.main.add(timer, forMode: .common)
        redrawTimer = timer
    }

    // MARK: Private

    private func placeWindow(preferPrimary: Bool) {
        let size = CGSize(width: settings.windowWidth, height: settings.windowHeight)
        let visibleFrames = NSScreen.screens.map(\.visibleFrame) // screens[0] is the menu-bar screen
        guard !visibleFrames.isEmpty else { return }

        let frame: CGRect
        if settings.corner == .custom, let origin = settings.customOrigin {
            let rect = CGRect(origin: CGPoint(x: origin.x, y: origin.y), size: size)
            let index = OverlayLayout.bestScreenIndex(for: rect, visibleFrames: visibleFrames) ?? 0
            frame = OverlayLayout.clamp(rect, into: visibleFrames[index])
        } else {
            let index = preferPrimary ? 0 : (OverlayLayout.bestScreenIndex(for: panel.frame, visibleFrames: visibleFrames) ?? 0)
            frame = OverlayLayout.frame(corner: settings.corner, size: size, in: visibleFrames[index])
        }
        panel.setFrame(frame, display: true)
        hasPlaced = true
    }

    private func updateRendering() {
        let animate = isAnimating
        scene.setAnimating(animate)
        if animate {
            redrawTimer?.invalidate()
            redrawTimer = nil
            townView.isPaused = false
        } else if redrawTimer == nil {
            townView.isPaused = true
        }
    }

    @objc private func redrawExpired() {
        redrawTimer = nil
        updateRendering()
    }

    @objc private func occlusionChanged() {
        occluded = !panel.occlusionState.contains(.visible)
        updateRendering()
    }

    @objc private func screensChanged() {
        placeWindow(preferPrimary: false)
    }

    @objc private func displaysDidSleep() {
        displaysAsleep = true
        updateRendering()
    }

    @objc private func displaysDidWake() {
        displaysAsleep = false
        updateRendering()
    }
}
