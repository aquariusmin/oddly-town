import AppKit
import OddlyTownCore

/// Demo Mode state. Lives only in memory — never saved, never mixed into real progress.
struct DemoState {
    var level: Int
    var phase: DayPhase?        // nil = follow the real clock
    var cycling = false
    var extras: Set<TownFeature> = []
}

/// Wires the pure core (growth, activity, persistence) to the macOS pieces
/// (overlay, menu bar, frontmost-app monitor). Single owner of all side effects.
@MainActor
final class AppController: NSObject {
    let environment: AppEnvironment
    let model: AppModel
    let engine: GrowthEngine

    private let townStore: JSONFileStore<TownState>
    private let settingsStore: JSONFileStore<AppSettings>
    private var state: TownState
    private var classifier: ActivityClassifier
    private var accumulator = ActivityAccumulator()
    private let monitor = FrontmostAppMonitor()
    private let overlay = OverlayWindowController()
    private let windows = WindowPresenter()
    private var menuBar: MenuBarController?

    private var tickTimer: Timer?
    private var lastTick = Date()
    private var ticksSinceSave = 0
    private var lastSnapshot: TownSnapshot?
    private(set) var demo: DemoState?
    private var demoCycleTimer: Timer?

    /// No input for this long → the current span doesn't count toward activity.
    private let idleThreshold: TimeInterval = 300

    init(environment: AppEnvironment) {
        let engine = GrowthEngine(rules: .standard)
        let townStore = JSONFileStore<TownState>(url: environment.dataDirectory.appendingPathComponent("town.json"))
        let settingsStore = JSONFileStore<AppSettings>(url: environment.dataDirectory.appendingPathComponent("settings.json"))

        let loaded: TownState
        switch townStore.load() {
        case .loaded(let saved):
            loaded = saved
        case .missing:
            loaded = TownState()
        case .recovered(let backup):
            loaded = TownState()
            NSLog("Oddly Town: town.json was unreadable and has been moved to %@. Starting a fresh town.",
                  backup?.path ?? "(could not back up)")
        }
        let settings = settingsStore.load().value ?? AppSettings()

        self.environment = environment
        self.engine = engine
        self.townStore = townStore
        self.settingsStore = settingsStore
        self.state = loaded
        classifier = ActivityClassifier(overrides: settings.categoryOverrides)
        model = AppModel(
            settings: settings,
            status: TownStatus(progress: engine.progress(of: loaded), remainingToday: nil,
                               activitySeconds: loaded.activitySeconds, features: [], isDemo: false),
            rules: engine.rules,
            dataDirectory: environment.dataDirectory,
            isDeveloper: environment.isDeveloper
        )
        super.init()
    }

    // MARK: Lifecycle

    func start() {
        model.onSettingsChanged = { [weak self] old, new in self?.settingsDidChange(from: old, to: new) }
        model.onRequestTracking = { [weak self] enabled in self?.setTrackingEnabled(enabled) }
        model.onResetActivity = { [weak self] in self?.confirmResetActivity() }
        model.onResetTown = { [weak self] in self?.confirmResetTown() }
        model.onResetPosition = { [weak self] in self?.resetWindowPosition() }

        overlay.onClick = { [weak self] in self?.townClicked() }
        overlay.onMoved = { [weak self] origin in self?.townDragged(to: origin) }
        overlay.apply(model.settings)

        monitor.onChange = { [weak self] bundleID in self?.frontmostAppChanged(bundleID) }
        if model.settings.activityTrackingEnabled { monitor.start() }

        menuBar = MenuBarController(controller: self)

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        workspace.addObserver(self, selector: #selector(didWake), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)

        lastTick = Date()
        let timer = Timer(timeInterval: environment.tickInterval, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        timer.tolerance = environment.tickInterval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer

        refresh()
    }

    func shutdown() {
        tick()
        if let credit = accumulator.suspend(at: Date()) { apply(credit) }
        saveState()
    }

    // MARK: Time

    @objc private func tick() {
        let now = Date()
        // Clamp so a stalled timer or missed sleep notification can't grant hours at once.
        let elapsed = min(max(0, now.timeIntervalSince(lastTick)), environment.tickInterval * 3)
        lastTick = now

        let levelBefore = engine.level(of: state)
        state = engine.advancing(state, by: elapsed * environment.timeScale, now: now,
                                 applyDailyCap: !environment.isDeveloper)
        if model.settings.activityTrackingEnabled,
           let credit = accumulator.checkpoint(at: now, isIdle: IdleTime.seconds() >= idleThreshold) {
            apply(credit)
        }

        ticksSinceSave += 1
        if engine.level(of: state) != levelBefore || Double(ticksSinceSave) * environment.tickInterval >= 300 {
            saveState()
        }
        refresh()
    }

    @objc private func willSleep() {
        tick()
        if let credit = accumulator.suspend(at: Date()) { apply(credit) }
        saveState()
    }

    @objc private func didWake() {
        lastTick = Date()
        accumulator.resume(at: Date())
    }

    // MARK: Activity

    private func frontmostAppChanged(_ bundleID: String?) {
        let category = bundleID.map { classifier.category(forBundleID: $0) }
        if let credit = accumulator.switchTo(category, at: Date()) { apply(credit) }
    }

    private func apply(_ credit: ActivityCredit) {
        state = engine.recordingActivity(state, category: credit.category, seconds: credit.seconds * environment.timeScale)
    }

    func setTrackingEnabled(_ enabled: Bool) {
        guard enabled != model.settings.activityTrackingEnabled else { return }
        if enabled && !confirmTrackingConsent() {
            model.objectWillChange.send() // snap the SwiftUI toggle back
            return
        }
        model.settings.activityTrackingEnabled = enabled
    }

    private func startTracking() {
        accumulator = ActivityAccumulator()
        monitor.start()
    }

    private func stopTracking() {
        if let credit = accumulator.suspend(at: Date()) { apply(credit) }
        accumulator = ActivityAccumulator()
        monitor.stop()
        saveState()
    }

    private func confirmTrackingConsent() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Let your apps shape the town?"
        alert.informativeText = """
        Oddly Town will note which app is in front and sort it into one of five categories \
        (Development, Creative, Productivity, Entertainment, Other). Only the estimated total \
        time per category is saved, locally on this Mac.

        It does not read window contents, websites, documents, keystrokes or the screen, \
        needs no special permissions, and sends nothing anywhere. You can turn this off or \
        erase the history at any time.
        """
        alert.addButton(withTitle: "Turn On")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }

    // MARK: Settings

    private func settingsDidChange(from old: AppSettings, to new: AppSettings) {
        do { try settingsStore.save(new) } catch { NSLog("Oddly Town: could not save settings: %@", "\(error)") }
        overlay.apply(new)
        if old.categoryOverrides != new.categoryOverrides {
            classifier = ActivityClassifier(overrides: new.categoryOverrides)
        }
        if old.activityTrackingEnabled != new.activityTrackingEnabled {
            new.activityTrackingEnabled ? startTracking() : stopTracking()
        }
        refresh()
    }

    func toggleVisible() { model.settings.townVisible.toggle() }
    func toggleAnimations() { model.settings.animationsEnabled.toggle() }
    func toggleClickThrough() { model.settings.clickThrough.toggle() }

    func resetWindowPosition() {
        var settings = model.settings
        settings.customOrigin = nil
        settings.corner = .bottomRight
        settings.townVisible = true
        model.settings = settings // one assignment → one apply/save
        overlay.placeOnPrimaryScreen()
    }

    private func townDragged(to origin: CGPoint) {
        // Assign once: setting the fields separately would briefly snap the window to a corner.
        var settings = model.settings
        settings.customOrigin = SavedPoint(x: Double(origin.x), y: Double(origin.y))
        settings.corner = .custom
        model.settings = settings
    }

    // MARK: Status & windows

    var statusLine: String {
        let progress = model.status.progress
        let prefix = demo != nil ? "Demo · " : ""
        if progress.secondsToNext == nil { return "\(prefix)Level \(progress.level) · fully grown" }
        return "\(prefix)Level \(progress.level) · \(Int(progress.fractionToNext * 100))% to Level \(progress.level + 1)"
    }

    private func townClicked() {
        overlay.scene.showStatus(statusLine)
        overlay.requestRedraw(for: 4.5)
    }

    func showStatusWindow() {
        windows.show(id: "status", title: "Town Status") { StatusView(model: model) }
    }

    func showSettingsWindow() {
        windows.show(id: "settings", title: "Oddly Town Settings") { SettingsView(model: model) }
    }

    private func confirm(_ title: String, _ detail: String, action: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: action)
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func confirmResetActivity() {
        guard confirm("Erase activity history?",
                      "All saved category times are deleted. Buildings that came from activity will disappear; time-based growth is kept.",
                      action: "Erase") else { return }
        state.activitySeconds = [:]
        accumulator = ActivityAccumulator()
        if model.settings.activityTrackingEnabled { monitor.reportCurrent() }
        saveState()
        refresh()
    }

    private func confirmResetTown() {
        guard confirm("Start a new town?", "Level, growth and activity history are all reset to the beginning.",
                      action: "Reset Town") else { return }
        state = TownState()
        accumulator = ActivityAccumulator()
        saveState()
        refresh()
    }

    // MARK: Snapshot

    private func currentSnapshot(now: Date) -> TownSnapshot {
        if let demo {
            return TownSnapshot(
                level: demo.level,
                features: engine.levelFeatures(forLevel: demo.level).union(demo.extras),
                phase: demo.phase ?? DayPhase.at(now),
                lateNight: demo.phase == nil && TownSnapshot.isLateNight(now)
            )
        }
        return TownSnapshot(
            level: engine.level(of: state),
            features: engine.unlockedFeatures(of: state),
            phase: DayPhase.at(now),
            lateNight: TownSnapshot.isLateNight(now)
        )
    }

    private func refresh() {
        let now = Date()
        let snapshot = currentSnapshot(now: now)
        if snapshot != lastSnapshot {
            overlay.scene.apply(snapshot)
            overlay.requestRedraw(for: 4)
            lastSnapshot = snapshot
        }
        let progress: GrowthProgress
        if let demo {
            progress = engine.progress(of: TownState(growthSeconds: demo.level == 1 ? 0 : engine.rules.levelThresholds[demo.level - 2]))
        } else {
            progress = engine.progress(of: state)
        }
        model.status = TownStatus(
            progress: progress,
            remainingToday: engine.remainingToday(state, now: now),
            activitySeconds: state.activitySeconds,
            features: snapshot.features,
            isDemo: demo != nil
        )
    }

    private func saveState() {
        ticksSinceSave = 0
        do { try townStore.save(state) } catch { NSLog("Oddly Town: could not save town: %@", "\(error)") }
    }

    // MARK: Developer & Demo Mode

    func setDemoMode(_ on: Bool) {
        demo = on ? DemoState(level: engine.level(of: state)) : nil
        if !on { stopDemoCycle() }
        refresh()
    }

    func setDemoLevel(_ level: Int) {
        guard demo != nil else { return }
        demo?.level = min(max(level, 1), engine.rules.maxLevel)
        refresh()
    }

    func setDemoPhase(_ phase: DayPhase?) {
        guard demo != nil else { return }
        stopDemoCycle()
        demo?.phase = phase
        refresh()
    }

    func toggleDemoCycle() {
        guard demo != nil else { return }
        if demo?.cycling == true {
            stopDemoCycle()
            return
        }
        demo?.cycling = true
        demo?.phase = demo?.phase ?? .day
        let timer = Timer(timeInterval: 5, target: self, selector: #selector(advanceDemoPhase), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        demoCycleTimer = timer
        refresh()
    }

    private func stopDemoCycle() {
        demoCycleTimer?.invalidate()
        demoCycleTimer = nil
        demo?.cycling = false
    }

    @objc private func advanceDemoPhase() {
        guard let current = demo?.phase else { return }
        let all = DayPhase.allCases
        demo?.phase = all[(all.firstIndex(of: current)! + 1) % all.count]
        refresh()
    }

    func toggleDemoFeature(_ feature: TownFeature) {
        guard demo != nil else { return }
        if demo!.extras.contains(feature) { demo!.extras.remove(feature) } else { demo!.extras.insert(feature) }
        refresh()
    }

    /// Developer mode only: adds real (dev-folder) progress to test growth and unlocks end to end.
    func devAddGrowth(hours: Double) {
        guard environment.isDeveloper else { return }
        state = engine.advancing(state, by: hours * GrowthRules.hour, now: Date(), applyDailyCap: false)
        saveState()
        refresh()
    }

    func devAddActivity(_ category: ActivityCategory, minutes: Double) {
        guard environment.isDeveloper else { return }
        state = engine.recordingActivity(state, category: category, seconds: minutes * 60)
        saveState()
        refresh()
    }
}
