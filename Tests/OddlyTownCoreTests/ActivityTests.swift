import XCTest
@testable import OddlyTownCore

final class ActivityClassifierTests: XCTestCase {
    func testExactAndPrefixMatches() {
        let classifier = ActivityClassifier()
        XCTAssertEqual(classifier.category(forBundleID: "com.apple.dt.Xcode"), .development)
        XCTAssertEqual(classifier.category(forBundleID: "com.jetbrains.intellij"), .development)
        XCTAssertEqual(classifier.category(forBundleID: "com.figma.Desktop"), .creative)
        XCTAssertEqual(classifier.category(forBundleID: "com.adobe.Photoshop"), .creative)
        XCTAssertEqual(classifier.category(forBundleID: "com.apple.iWork.Pages"), .productivity)
        XCTAssertEqual(classifier.category(forBundleID: "com.spotify.client"), .entertainment)
    }

    func testExactBeatsPrefix() {
        XCTAssertEqual(ActivityClassifier().category(forBundleID: "com.adobe.Acrobat.Pro"), .productivity)
    }

    func testUnknownBrowsersAndNilAreOther() {
        let classifier = ActivityClassifier()
        XCTAssertEqual(classifier.category(forBundleID: "com.apple.Safari"), .other)
        XCTAssertEqual(classifier.category(forBundleID: "com.example.unknown"), .other)
        XCTAssertEqual(classifier.category(forBundleID: nil), .other)
        XCTAssertEqual(classifier.category(forBundleID: ""), .other)
    }

    func testOverridesWinAndAreCaseInsensitive() {
        let classifier = ActivityClassifier(overrides: ["COM.APPLE.SAFARI": .productivity, "com.apple.dt.Xcode": .creative])
        XCTAssertEqual(classifier.category(forBundleID: "com.apple.Safari"), .productivity)
        XCTAssertEqual(classifier.category(forBundleID: "com.apple.dt.Xcode"), .creative)
    }
}

final class ActivityAccumulatorTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    func testSwitchCreditsPreviousCategory() {
        var acc = ActivityAccumulator(maxCreditPerSpan: 600)
        XCTAssertNil(acc.switchTo(.development, at: t0))
        let credit = acc.switchTo(.creative, at: t0.addingTimeInterval(120))
        XCTAssertEqual(credit, ActivityCredit(category: .development, seconds: 120))
        XCTAssertEqual(acc.current, .creative)
    }

    func testCheckpointRestartsSpan() {
        var acc = ActivityAccumulator(maxCreditPerSpan: 600)
        _ = acc.switchTo(.productivity, at: t0)
        XCTAssertEqual(acc.checkpoint(at: t0.addingTimeInterval(60), isIdle: false)?.seconds, 60)
        XCTAssertEqual(acc.checkpoint(at: t0.addingTimeInterval(90), isIdle: false)?.seconds, 30)
    }

    func testLongGapsAreClamped() {
        var acc = ActivityAccumulator(maxCreditPerSpan: 180)
        _ = acc.switchTo(.entertainment, at: t0)
        XCTAssertEqual(acc.checkpoint(at: t0.addingTimeInterval(8 * 3600), isIdle: false)?.seconds, 180)
    }

    func testIdleSpansEarnNothing() {
        var acc = ActivityAccumulator()
        _ = acc.switchTo(.development, at: t0)
        XCTAssertNil(acc.checkpoint(at: t0.addingTimeInterval(60), isIdle: true))
        XCTAssertEqual(acc.checkpoint(at: t0.addingTimeInterval(100), isIdle: false)?.seconds, 40)
    }

    func testSuspendAndResume() {
        var acc = ActivityAccumulator()
        _ = acc.switchTo(.creative, at: t0)
        XCTAssertEqual(acc.suspend(at: t0.addingTimeInterval(30))?.seconds, 30)
        XCTAssertNil(acc.checkpoint(at: t0.addingTimeInterval(5000), isIdle: false), "nothing counted while suspended")
        acc.resume(at: t0.addingTimeInterval(6000))
        XCTAssertEqual(acc.checkpoint(at: t0.addingTimeInterval(6010), isIdle: false)?.seconds, 10)
    }

    func testClockGoingBackwardsCreditsNothing() {
        var acc = ActivityAccumulator()
        _ = acc.switchTo(.creative, at: t0)
        XCTAssertNil(acc.checkpoint(at: t0.addingTimeInterval(-100), isIdle: false))
    }
}
