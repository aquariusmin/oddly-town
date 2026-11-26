import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?
    private var terminationSignal: DispatchSourceSignal?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Menu-bar only: no Dock icon even when run via `swift run` without an Info.plist.
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = AppController(environment: .current())
        controller.start()
        self.controller = controller
        quitNormallyOnSIGTERM()
    }

    /// `kill`, launchd and scripts (e.g. `scripts/smoke-run.sh`) stop the app with SIGTERM,
    /// whose default action skips `applicationWillTerminate` and so the final save.
    /// Route it through `NSApp.terminate` instead.
    private func quitNormallyOnSIGTERM() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated { NSApp.terminate(nil) }
        }
        source.resume()
        terminationSignal = source
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
