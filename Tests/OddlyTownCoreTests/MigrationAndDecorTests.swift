import Foundation
import Testing
@testable import OddlyTownCore

/// v0.1 → v0.2 compatibility and Town Mode decorations.
@Suite struct MigrationTests {
    /// Exactly what v0.1.0 wrote (pretty-printed, sorted keys, ISO-8601 dates).
    static let v1TownJSON = """
    {
      "activitySeconds" : {
        "creative" : 3000,
        "development" : 1200
      },
      "capDay" : "2026-10-21",
      "createdAt" : "2026-10-20T15:00:00Z",
      "growthSeconds" : 7300,
      "growthSecondsOnCapDay" : 3000,
      "schemaVersion" : 1
    }
    """

    static let v1SettingsJSON = """
    {
      "activityTrackingEnabled" : true,
      "animationsEnabled" : true,
      "categoryOverrides" : { "com.apple.Safari" : "productivity" },
      "clickThrough" : true,
      "corner" : "topLeft",
      "floatAboveWindows" : false,
      "showOverFullScreenApps" : false,
      "townVisible" : true,
      "windowWidth" : 420
    }
    """

    @Test func v1TownLoadsWithProgressKeptAndDefaultDecor() throws {
        try TestSupport.withTempDirectory { dir in
            let url = dir.appendingPathComponent("town.json")
            try Data(Self.v1TownJSON.utf8).write(to: url)
            let store = JSONFileStore<TownState>(url: url)
            let state = try #require(store.load().value)

            #expect(state.growthSeconds == 7300)
            #expect(state.activitySeconds[.creative] == 3000)
            #expect(state.capDay == "2026-10-21")
            #expect(state.decor == .standard)
            #expect(state.schemaVersion == 2)
            #expect(GrowthEngine().level(of: state) == 2, "a v0.1 Level 2 town is still Level 2")

            // Written back as v2 and still identical when read again.
            try store.save(state)
            let text = try String(contentsOf: url, encoding: .utf8)
            #expect(text.contains("\"schemaVersion\" : 2"))
            #expect(text.contains("\"decor\""))
            #expect(store.load().value == state)
        }
    }

    @Test func v1SettingsKeepChoicesAndMoveToCompactDefault() throws {
        try TestSupport.withTempDirectory { dir in
            let url = dir.appendingPathComponent("settings.json")
            try Data(Self.v1SettingsJSON.utf8).write(to: url)
            let settings = try #require(JSONFileStore<AppSettings>(url: url).load().value)
            #expect(settings.windowWidth == 280, "v0.1's 420 default becomes the new 280 default")
            #expect(settings.windowHeight == 120)
            #expect(settings.pixelScale == 2)
            #expect(settings.corner == .topLeft)
            #expect(settings.clickThrough)
            #expect(!settings.floatAboveWindows)
            #expect(settings.activityTrackingEnabled)
            #expect(settings.categoryOverrides == ["com.apple.Safari": .productivity])
            #expect(settings.schemaVersion == 2)
        }
    }

    @Test func v1CustomWidthIsKeptAndSnapped() throws {
        let json = #"{ "windowWidth" : 500 }"#
        try TestSupport.withTempDirectory { dir in
            let url = dir.appendingPathComponent("settings.json")
            try Data(json.utf8).write(to: url)
            let settings = try #require(JSONFileStore<AppSettings>(url: url).load().value)
            #expect(settings.windowWidth == 560, "snapped to 4× (nearest whole pixel scale)")
            #expect(settings.pixelScale == 4)
        }
    }

    @Test func v2SettingsWith420StayAt420() throws {
        let json = #"{ "schemaVersion" : 2, "windowWidth" : 420 }"#
        try TestSupport.withTempDirectory { dir in
            let url = dir.appendingPathComponent("settings.json")
            try Data(json.utf8).write(to: url)
            #expect(JSONFileStore<AppSettings>(url: url).load().value?.windowWidth == 420)
        }
    }

    @Test func newDefaultsAreCompact() {
        let settings = AppSettings()
        #expect(settings.windowWidth == 280)
        #expect(settings.windowHeight == 120)
        #expect(AppSettings.clampWidth(10) == 280)
        #expect(AppSettings.clampWidth(10_000) == 840)
        #expect(AppSettings.clampWidth(700) == 700)
    }
}

@Suite struct DecorTests {
    @Test func standardLayoutHasABench() {
        #expect(DecorLayout.standard.slots.count == DecorLayout.slotCount)
        #expect(DecorLayout.standard.item(inSlot: 0) == .bench)
    }

    @Test func placeAndRemove() {
        var layout = DecorLayout.standard
        layout.place(.lantern, inSlot: 1)
        layout.place(nil, inSlot: 0)
        layout.place(.mushrooms, inSlot: 99) // ignored
        #expect(layout.item(inSlot: 1) == .lantern)
        #expect(layout.item(inSlot: 0) == nil)
        #expect(layout.slots.count == DecorLayout.slotCount)
    }

    @Test func lockedItemsStaySavedButHidden() {
        var layout = DecorLayout()
        layout.place(.bench, inSlot: 0)
        layout.place(.lantern, inSlot: 1)   // level 2
        layout.place(.pumpkins, inSlot: 2)  // level 3
        #expect(layout.visibleItems(level: 1) == [0: .bench])
        #expect(layout.visibleItems(level: 2) == [0: .bench, 1: .lantern])
        #expect(layout.visibleItems(level: 3).count == 3)
    }

    @Test func onlyDecorativeFeaturesCanBeHidden() {
        var layout = DecorLayout()
        layout.setHidden(true, .picketFence)
        layout.setHidden(true, .workshop) // progress can't be hidden
        #expect(layout.hiddenFeatures == [.picketFence])
        layout.setHidden(false, .picketFence)
        #expect(layout.hiddenFeatures.isEmpty)
    }

    @Test func lenientDecoding() throws {
        let json = """
        { "decor" : { "slots" : ["bench", "spaceship", null, "lantern", "mushrooms", "bench"],
                      "hiddenFeatures" : ["wildflowers", "workshop", "nonsense"] } }
        """
        try TestSupport.withTempDirectory { dir in
            let url = dir.appendingPathComponent("town.json")
            try Data(json.utf8).write(to: url)
            let state = try #require(JSONFileStore<TownState>(url: url).load().value)
            #expect(state.decor.slots == [.bench, nil, nil, .lantern], "unknown → empty, extra slots dropped")
            #expect(state.decor.hiddenFeatures == [.wildflowers])
        }
    }

    @Test func badDecorFallsBackToStandardWithoutLosingProgress() throws {
        let json = #"{ "growthSeconds" : 9000, "decor" : "garbage" }"#
        try TestSupport.withTempDirectory { dir in
            let url = dir.appendingPathComponent("town.json")
            try Data(json.utf8).write(to: url)
            let state = try #require(JSONFileStore<TownState>(url: url).load().value)
            #expect(state.growthSeconds == 9000)
            #expect(state.decor == .standard)
        }
    }

    @Test func decorSurvivesRestart() throws {
        var state = TownState(growthSeconds: 7 * 3600)
        var layout = DecorLayout()
        layout.place(.birdbath, inSlot: 3)
        layout.place(.sapling, inSlot: 1)
        layout.setHidden(true, .youngTree) // "moved" the tree into slot 1
        state.decor = layout
        try TestSupport.withTempDirectory { dir in
            let store = JSONFileStore<TownState>(url: dir.appendingPathComponent("town.json"))
            try store.save(state)
            let restored = try #require(store.load().value)
            #expect(restored.decor == layout)
        }
    }
}

@Suite struct SnapshotTests {
    let engine = GrowthEngine()
    let noon = TestSupport.date(day: 21, hour: 12)

    @Test func snapshotAppliesHiddenFeaturesAndLockedDecor() {
        var state = TownState(growthSeconds: 2 * 3600)
        var layout = DecorLayout()
        layout.place(.lantern, inSlot: 0)
        layout.place(.pumpkins, inSlot: 1)
        layout.setHidden(true, .picketFence)
        state.decor = layout
        let snapshot = TownSnapshot.make(state: state, engine: engine, now: noon, calendar: TestSupport.utc)
        #expect(snapshot.level == 2)
        #expect(!snapshot.features.contains(.picketFence))
        #expect(snapshot.features.contains(.lamppost))
        #expect(snapshot.decor == [0: .lantern], "pumpkins need Level 3")
        #expect(snapshot.residentCount == 2)
        #expect(snapshot.phase == .day)
    }

    /// Ambient and Town Mode both render `TownSnapshot.make`; a decor change made in
    /// Town Mode must give both the same picture, also after a restart.
    @Test func bothModesSeeTheSameTownAfterEditing() throws {
        var state = TownState(growthSeconds: 6 * 3600)
        let before = TownSnapshot.make(state: state, engine: engine, now: noon, calendar: TestSupport.utc)
        state.decor.place(.mushrooms, inSlot: 2)
        let ambient = TownSnapshot.make(state: state, engine: engine, now: noon, calendar: TestSupport.utc)
        let townMode = TownSnapshot.make(state: state, engine: engine, now: noon, calendar: TestSupport.utc)
        #expect(ambient == townMode)
        #expect(ambient != before)
        #expect(ambient.residentCount == 3)

        try TestSupport.withTempDirectory { dir in
            let store = JSONFileStore<TownState>(url: dir.appendingPathComponent("town.json"))
            try store.save(state)
            let restored = try #require(store.load().value)
            #expect(TownSnapshot.make(state: restored, engine: engine, now: noon, calendar: TestSupport.utc) == ambient)
        }
    }

    @Test func seatsComeFromBenches() {
        let snapshot = TownSnapshot(level: 1, features: [], phase: .day, decor: [2: .bench, 0: .flowerBox, 3: .bench])
        #expect(snapshot.seatSlots == [2, 3])
    }
}
