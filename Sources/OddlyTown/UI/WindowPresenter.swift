import AppKit
import SwiftUI

/// Opens one regular window per id for the SwiftUI screens (Status, Settings).
@MainActor
final class WindowPresenter {
    private var windows: [String: NSWindow] = [:]

    func show<Content: View>(id: String, title: String, content: () -> Content) {
        NSApp.activate()
        if let window = windows[id] {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let host = NSHostingController(rootView: content())
        host.sizingOptions = .preferredContentSize
        let window = NSWindow(contentViewController: host)
        window.title = title
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        windows[id] = window
        window.makeKeyAndOrderFront(nil)
    }
}
