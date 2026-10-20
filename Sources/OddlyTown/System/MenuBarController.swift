import AppKit
import OddlyTownCore

/// The status-bar icon and its menu. The menu is rebuilt each time it opens,
/// so titles and checkmarks always reflect current state.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private unowned let controller: AppController

    init(controller: AppController) {
        self.controller = controller
        super.init()
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "house.fill", accessibilityDescription: "Oddly Town")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Oddly Town"
        }
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild()
    }

    private func rebuild() {
        menu.removeAllItems()
        let settings = controller.model.settings

        let header = NSMenuItem(title: controller.statusLine, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(item("Town Status…", #selector(showStatus)))
        menu.addItem(.separator())

        menu.addItem(item(settings.townVisible ? "Hide Town" : "Show Town", #selector(toggleVisible)))
        menu.addItem(item(settings.animationsEnabled ? "Pause Animation" : "Resume Animation", #selector(toggleAnimations)))
        menu.addItem(item("Click-through", #selector(toggleClickThrough), on: settings.clickThrough))
        menu.addItem(item("Activity Tracking", #selector(toggleTracking), on: settings.activityTrackingEnabled))
        menu.addItem(item("Reset Window Position", #selector(resetPosition)))
        menu.addItem(.separator())

        menu.addItem(item("Settings…", #selector(showSettings), key: ","))
        if controller.environment.isDeveloper {
            let developer = NSMenuItem(title: "Developer", action: nil, keyEquivalent: "")
            developer.submenu = developerMenu()
            menu.addItem(developer)
        }
        menu.addItem(.separator())
        menu.addItem(item("Quit Oddly Town", #selector(quit), key: "q"))
    }

    private func developerMenu() -> NSMenu {
        let sub = NSMenu()
        sub.autoenablesItems = false
        let demo = controller.demo
        sub.addItem(item("Demo Mode (not saved)", #selector(toggleDemo), on: demo != nil))

        var items: [NSMenuItem] = []
        for level in 1...controller.engine.rules.maxLevel {
            items.append(item("Level \(level)", #selector(demoLevel(_:)), on: demo?.level == level, tag: level))
        }
        items.append(.separator())
        items.append(item("Time: Real Clock", #selector(demoPhase(_:)), on: demo != nil && demo?.phase == nil && demo?.cycling == false, tag: -1))
        for (index, phase) in DayPhase.allCases.enumerated() {
            items.append(item("Time: \(phase.rawValue.capitalized)", #selector(demoPhase(_:)),
                              on: demo?.cycling == false && demo?.phase == phase, tag: index))
        }
        items.append(item("Cycle Day & Night (5 s)", #selector(demoCycle), on: demo?.cycling == true))
        items.append(.separator())
        let activityFeatures: [(TownFeature, String)] = [
            (.workshop, "Development → Workshop"),
            (.artGarden, "Creative → Art Garden"),
            (.readingNook, "Productivity → Reading Nook"),
            (.festivalBunting, "Entertainment → Festival"),
        ]
        for (feature, title) in activityFeatures {
            let on = demo.map { controller.engine.levelFeatures(forLevel: $0.level).union($0.extras).contains(feature) } ?? false
            let entry = item(title, #selector(demoFeature(_:)), on: on)
            entry.representedObject = feature.rawValue
            items.append(entry)
        }
        for entry in items {
            if !entry.isSeparatorItem { entry.isEnabled = demo != nil; entry.indentationLevel = 1 }
            sub.addItem(entry)
        }

        sub.addItem(.separator())
        let info = NSMenuItem(title: "Dev data folder · time ×\(Int(controller.environment.timeScale))", action: nil, keyEquivalent: "")
        info.isEnabled = false
        sub.addItem(info)
        sub.addItem(item("Grow +1 hour", #selector(devGrow)))
        for category in ActivityCategory.allCases where category != .other {
            let entry = item("Add 45 min \(category.displayName)", #selector(devActivity(_:)))
            entry.representedObject = category.rawValue
            sub.addItem(entry)
        }
        return sub
    }

    private func item(_ title: String, _ action: Selector, on: Bool? = nil, key: String = "", tag: Int = 0) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
        entry.target = self
        entry.tag = tag
        if let on { entry.state = on ? .on : .off }
        return entry
    }

    // MARK: Actions

    @objc private func showStatus() { controller.showStatusWindow() }
    @objc private func showSettings() { controller.showSettingsWindow() }
    @objc private func toggleVisible() { controller.toggleVisible() }
    @objc private func toggleAnimations() { controller.toggleAnimations() }
    @objc private func toggleClickThrough() { controller.toggleClickThrough() }
    @objc private func toggleTracking() { controller.setTrackingEnabled(!controller.model.settings.activityTrackingEnabled) }
    @objc private func resetPosition() { controller.resetWindowPosition() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func toggleDemo() { controller.setDemoMode(controller.demo == nil) }
    @objc private func demoLevel(_ sender: NSMenuItem) { controller.setDemoLevel(sender.tag) }
    @objc private func demoCycle() { controller.toggleDemoCycle() }

    @objc private func demoPhase(_ sender: NSMenuItem) {
        let phases = DayPhase.allCases
        controller.setDemoPhase(phases.indices.contains(sender.tag) ? phases[sender.tag] : nil)
    }

    @objc private func demoFeature(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let feature = TownFeature(rawValue: raw) else { return }
        controller.toggleDemoFeature(feature)
    }

    @objc private func devGrow() { controller.devAddGrowth(hours: 1) }

    @objc private func devActivity(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let category = ActivityCategory(rawValue: raw) else { return }
        controller.devAddActivity(category, minutes: 45)
    }
}
