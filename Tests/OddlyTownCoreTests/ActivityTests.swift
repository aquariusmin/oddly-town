import Foundation
import Testing
@testable import OddlyTownCore

@Suite struct ActivityClassifierTests {
    @Test func exactAndPrefixMatches() {
        let classifier = ActivityClassifier()
        #expect(classifier.category(forBundleID: "com.apple.dt.Xcode") == .development)
        #expect(classifier.category(forBundleID: "com.jetbrains.intellij") == .development)
        #expect(classifier.category(forBundleID: "com.figma.Desktop") == .creative)
        #expect(classifier.category(forBundleID: "com.adobe.Photoshop") == .creative)
        #expect(classifier.category(forBundleID: "com.apple.iWork.Pages") == .productivity)
        #expect(classifier.category(forBundleID: "com.spotify.client") == .entertainment)
    }

    @Test func exactBeatsPrefix() {
        #expect(ActivityClassifier().category(forBundleID: "com.adobe.Acrobat.Pro") == .productivity)
    }

    @Test func unknownBrowsersAndNilAreOther() {
        let classifier = ActivityClassifier()
        #expect(classifier.category(forBundleID: "com.apple.Safari") == .other)
        #expect(classifier.category(forBundleID: "com.example.unknown") == .other)
        #expect(classifier.category(forBundleID: nil) == .other)
        #expect(classifier.category(forBundleID: "") == .other)
    }

    @Test func overridesWinAndAreCaseInsensitive() {
        let classifier = ActivityClassifier(overrides: ["COM.APPLE.SAFARI": .productivity, "com.apple.dt.Xcode": .creative])
        #expect(classifier.category(forBundleID: "com.apple.Safari") == .productivity)
        #expect(classifier.category(forBundleID: "com.apple.dt.Xcode") == .creative)
    }
}

@Suite struct ActivityAccumulatorTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func switchCreditsPreviousCategory() {
        var acc = ActivityAccumulator(maxCreditPerSpan: 600)
        #expect(acc.switchTo(.development, at: t0) == nil)
        let credit = acc.switchTo(.creative, at: t0.addingTimeInterval(120))
        #expect(credit == ActivityCredit(category: .development, seconds: 120))
        #expect(acc.current == .creative)
    }

    @Test func checkpointRestartsSpan() {
        var acc = ActivityAccumulator(maxCreditPerSpan: 600)
        _ = acc.switchTo(.productivity, at: t0)
        #expect(acc.checkpoint(at: t0.addingTimeInterval(60), isIdle: false)?.seconds == 60)
        #expect(acc.checkpoint(at: t0.addingTimeInterval(90), isIdle: false)?.seconds == 30)
    }

    @Test func longGapsAreClamped() {
        var acc = ActivityAccumulator(maxCreditPerSpan: 180)
        _ = acc.switchTo(.entertainment, at: t0)
        #expect(acc.checkpoint(at: t0.addingTimeInterval(8 * 3600), isIdle: false)?.seconds == 180)
    }

    @Test func idleSpansEarnNothing() {
        var acc = ActivityAccumulator()
        _ = acc.switchTo(.development, at: t0)
        #expect(acc.checkpoint(at: t0.addingTimeInterval(60), isIdle: true) == nil)
        #expect(acc.checkpoint(at: t0.addingTimeInterval(100), isIdle: false)?.seconds == 40)
    }

    @Test func suspendAndResume() {
        var acc = ActivityAccumulator()
        _ = acc.switchTo(.creative, at: t0)
        #expect(acc.suspend(at: t0.addingTimeInterval(30))?.seconds == 30)
        #expect(acc.checkpoint(at: t0.addingTimeInterval(5000), isIdle: false) == nil, "nothing counted while suspended")
        acc.resume(at: t0.addingTimeInterval(6000))
        #expect(acc.checkpoint(at: t0.addingTimeInterval(6010), isIdle: false)?.seconds == 10)
    }

    @Test func clockGoingBackwardsCreditsNothing() {
        var acc = ActivityAccumulator()
        _ = acc.switchTo(.creative, at: t0)
        #expect(acc.checkpoint(at: t0.addingTimeInterval(-100), isIdle: false) == nil)
    }
}
