import XCTest
@testable import OddlyTownCore

final class PersistenceTests: XCTestCase {
    var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("oddlytown-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testTownStateRoundTrip() throws {
        let store = JSONFileStore<TownState>(url: directory.appendingPathComponent("town.json"))
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let state = TownState(
            createdAt: created,
            growthSeconds: 1234.5,
            activitySeconds: [.development: 60, .creative: 30],
            capDay: "2026-10-21",
            growthSecondsOnCapDay: 99
        )
        try store.save(state)
        XCTAssertEqual(store.load().value, state)
    }

    func testMissingFile() {
        let store = JSONFileStore<TownState>(url: directory.appendingPathComponent("nope.json"))
        guard case .missing = store.load() else { return XCTFail("expected .missing") }
        XCTAssertEqual(store.load(default: { TownState(growthSeconds: 7) }).growthSeconds, 7)
    }

    func testCorruptFileIsBackedUpAndDefaultUsed() throws {
        let url = directory.appendingPathComponent("town.json")
        try Data("{ this is not json".utf8).write(to: url)
        let store = JSONFileStore<TownState>(url: url)

        guard case .recovered(let backup) = store.load() else { return XCTFail("expected .recovered") }
        XCTAssertNotNil(backup)
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup!.path), "corrupt data preserved for inspection")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))

        // Next launch starts clean and can save again.
        guard case .missing = store.load() else { return XCTFail("expected .missing after recovery") }
        try store.save(TownState(growthSeconds: 1))
        XCTAssertEqual(store.load().value?.growthSeconds, 1)
    }

    func testWrongShapeJSONIsTreatedAsCorrupt() throws {
        let url = directory.appendingPathComponent("town.json")
        try Data("[1, 2, 3]".utf8).write(to: url)
        guard case .recovered = JSONFileStore<TownState>(url: url).load() else { return XCTFail("expected .recovered") }
    }

    func testPartialAndInvalidFieldsDecodeWithDefaults() throws {
        let json = """
        {
          "growthSeconds": -500,
          "activitySeconds": { "development": 120, "mystery": 50, "creative": -3 },
          "growthSecondsOnCapDay": "oops"
        }
        """
        let url = directory.appendingPathComponent("town.json")
        try Data(json.utf8).write(to: url)
        let state = try XCTUnwrap(JSONFileStore<TownState>(url: url).load().value)
        XCTAssertEqual(state.growthSeconds, 0, "negative values are clamped")
        XCTAssertEqual(state.activitySeconds[.development], 120)
        XCTAssertEqual(state.activitySeconds[.creative], 0)
        XCTAssertEqual(state.activitySeconds.count, 2, "unknown categories are dropped")
        XCTAssertEqual(state.growthSecondsOnCapDay, 0)
        XCTAssertEqual(state.schemaVersion, TownState.currentSchemaVersion)
    }

    func testSettingsDefaultsAndClamping() throws {
        let json = """
        { "windowWidth": 99999, "corner": "custom", "activityTrackingEnabled": true,
          "categoryOverrides": { "com.apple.Safari": "creative", "x.y": "bogus" } }
        """
        let url = directory.appendingPathComponent("settings.json")
        try Data(json.utf8).write(to: url)
        let settings = try XCTUnwrap(JSONFileStore<AppSettings>(url: url).load().value)
        XCTAssertEqual(settings.windowWidth, AppSettings.maxWidth)
        XCTAssertEqual(settings.corner, .bottomRight, "custom without an origin falls back")
        XCTAssertTrue(settings.activityTrackingEnabled)
        XCTAssertTrue(settings.townVisible)
        XCTAssertEqual(settings.categoryOverrides, ["com.apple.Safari": .creative])
    }

    func testSettingsRoundTrip() throws {
        var settings = AppSettings()
        settings.windowWidth = 560
        settings.corner = .custom
        settings.customOrigin = SavedPoint(x: 10, y: 20)
        settings.clickThrough = true
        settings.categoryOverrides = ["com.example.app": .entertainment]
        let store = JSONFileStore<AppSettings>(url: directory.appendingPathComponent("settings.json"))
        try store.save(settings)
        XCTAssertEqual(store.load().value, settings)
        XCTAssertEqual(settings.windowHeight, 240)
    }
}
