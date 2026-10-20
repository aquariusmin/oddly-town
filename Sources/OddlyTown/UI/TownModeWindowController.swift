import AppKit
import SpriteKit
import SwiftUI

/// Town Mode: a normal window with the town at 6× and a small panel below.
/// Created when opened and torn down when closed, so it costs nothing in Ambient Mode.
@MainActor
final class TownModeWindowController: NSObject, NSWindowDelegate {
    static let pixelScale = 6
    static let townSize = CGSize(width: 140 * 6, height: 60 * 6)
    static let framesPerSecond = 20

    let scene: TownScene
    var onClose: (() -> Void)?

    private let window: NSWindow
    private let townView: SKView

    init(model: AppModel) {
        let townSize = Self.townSize
        let panelHeight = TownModePanel.height
        scene = TownScene(pixelScale: Self.pixelScale, interactive: true)

        townView = SKView(frame: NSRect(x: 0, y: panelHeight, width: townSize.width, height: townSize.height))
        townView.preferredFramesPerSecond = Self.framesPerSecond
        townView.ignoresSiblingOrder = false

        let panel = NSHostingView(rootView: TownModePanel(model: model))
        panel.frame = NSRect(x: 0, y: 0, width: townSize.width, height: panelHeight)

        let content = NSView(frame: NSRect(x: 0, y: 0, width: townSize.width, height: townSize.height + panelHeight))
        content.addSubview(townView)
        content.addSubview(panel)

        window = NSWindow(contentRect: content.frame, styleMask: [.titled, .closable, .miniaturizable],
                          backing: .buffered, defer: false)
        window.title = "Oddly Town"
        window.contentView = content
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenNone]
        super.init()
        window.delegate = self
        if !window.setFrameUsingName("OddlyTownTownMode") { window.center() }
        window.setFrameAutosaveName("OddlyTownTownMode")
        townView.presentScene(scene)
    }

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window.close()
    }

    func windowWillClose(_ notification: Notification) {
        // Free the renderer right away; the controller drops this object in onClose.
        townView.isPaused = true
        townView.presentScene(nil)
        onClose?()
    }

    func windowDidMiniaturize(_ notification: Notification) { townView.isPaused = true }
    func windowDidDeminiaturize(_ notification: Notification) { townView.isPaused = false }
}
