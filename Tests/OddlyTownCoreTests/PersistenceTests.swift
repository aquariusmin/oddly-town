import Foundation
import Testing
@testable import OddlyTownCore

@Suite struct PersistenceTests {
    @Test func townStateRoundTrip() throws {
        try TestSupport.withTempDirectory { dir in
            let store = JSONFileStore<TownState>(url: dir.appendingPathComponent("town.json"))
            let state = TownState(
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                growthSeconds: 1234.5,
                activitySeconds: [.development: 60, .creative: 30],
                capDay: "2026-10-21",
                growthSecondsOnCapDay: 99
            )
            try store.save(state)
            #expect(store.load().value == state)
        }
    }

    @Test func missingFile() throws {
        try TestSupport.withTempDirectory { dir in
            let store = JSONFileStore<TownState>(url: dir.appendingPathComponent("nope.json"))
            guard case .missing = store.load() else { Issue.record("expected .missing"); return }
            #expect(store.load(default: { TownState(growthSeconds: 7) }).growthSeconds == 7)
        }
    }

    @Test func corruptFileIsBackedUpAndDefaultUsed() throws {
        try TestSupport.withTempDirectory { dir in
            let url = dir.appendingPathComponent("town.json")
            try Data("{ this is not json".utf8).write(to: url)
            let store = JSONFileStore<TownState>(url: url)

            guard case .recovered(let backup) = store.load() else { Issue.record("expected .recovered"); return }
            let backupURL = try #require(backup)
            #expect(FileManager.default.fileExists(atPath: backupURL.path), "corrupt data preserved for inspection")
            #expect(!FileManager.default.fileExists(atPath: url.path))

            // Next launch starts clean and can save again.
            guard case .missing = store.load() else { Issue.record("expected .missing after recovery"); return }
            try store.save(TownState(growthSeconds: 1))
            #expect(store.load().value?.growthSeconds == 1)
        }
    }

    @Test func wrongShapeJSONIsTreatedAsCorrupt() throws {
        try TestSupport.withTempDirectory { dir in
            let url = dir.appendingPathComponent("town.json")
            try Data("[1, 2, 3]".utf8).write(to: url)
            guard case .recovered = JSONFileStore<TownState>(url: url).load() else { Issue.record("expected .recovered"); return }
        }
    }

    @Test func partialAndInvalidFieldsDecodeWithDefaults() throws {
        let json = """
        {
          "growthSeconds": -500,
          "activitySeconds": { "development": 120, "mystery": 50, "creative": -3 },
          "growthSecondsOnCapDay": "oops"
        }
        """
        try TestSupport.withTempDirectory { dir in
            let url = dir.appendingPathComponent("town.json")
            try Data(json.utf8).write(to: url)
            let state = try #require(JSONFileStore<TownState>(url: url).load().value)
            #expect(state.growthSeconds == 0, "negative values are clamped")
            #expect(state.activitySeconds[.development] == 120)
            #expect(state.activitySeconds[.creative] == 0)
            #expect(state.activitySeconds.count == 2, "unknown categories are dropped")
            #expect(state.growthSecondsOnCapDay == 0)
            #expect(state.schemaVersion == TownState.currentSchemaVersion)
        }
    }

    @Test func settingsDefaultsAndClamping() throws {
        let json = """
        { "windowWidth": 99999, "corner": "custom", "activityTrackingEnabled": true,
          "categoryOverrides": { "com.apple.Safari": "creative", "x.y": "bogus" } }
        """
        try TestSupport.withTempDirectory { dir in
            let url = dir.appendingPathComponent("settings.json")
            try Data(json.utf8).write(to: url)
            let settings = try #require(JSONFileStore<AppSettings>(url: url).load().value)
            #expect(settings.windowWidth == AppSettings.maxWidth)
            #expect(settings.corner == .bottomRight, "custom without an origin falls back")
            #expect(settings.activityTrackingEnabled)
            #expect(settings.townVisible)
            #expect(settings.categoryOverrides == ["com.apple.Safari": .creative])
        }
    }

    @Test func settingsRoundTrip() throws {
        var settings = AppSettings()
        settings.windowWidth = 560
        settings.corner = .custom
        settings.customOrigin = SavedPoint(x: 10, y: 20)
        settings.clickThrough = true
        settings.categoryOverrides = ["com.example.app": .entertainment]
        try TestSupport.withTempDirectory { dir in
            let store = JSONFileStore<AppSettings>(url: dir.appendingPathComponent("settings.json"))
            try store.save(settings)
            #expect(store.load().value == settings)
        }
        #expect(settings.windowHeight == 240)
    }
}
