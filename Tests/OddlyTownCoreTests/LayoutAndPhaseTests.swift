import XCTest
@testable import OddlyTownCore

final class OverlayLayoutTests: XCTestCase {
    let screen = CGRect(x: 0, y: 80, width: 1512, height: 870) // visible frame minus Dock

    func testBottomRightIsDefaultCorner() {
        let frame = OverlayLayout.frame(corner: .bottomRight, size: CGSize(width: 420, height: 180), in: screen)
        XCTAssertEqual(frame.maxX, screen.maxX - OverlayLayout.margin)
        XCTAssertEqual(frame.minY, screen.minY + OverlayLayout.margin)
    }

    func testTopLeft() {
        let frame = OverlayLayout.frame(corner: .topLeft, size: CGSize(width: 420, height: 180), in: screen)
        XCTAssertEqual(frame.minX, OverlayLayout.margin)
        XCTAssertEqual(frame.maxY, screen.maxY - OverlayLayout.margin)
    }

    func testClampPullsOffscreenWindowBack() {
        let off = CGRect(x: 5000, y: -400, width: 420, height: 180)
        let clamped = OverlayLayout.clamp(off, into: screen)
        XCTAssertTrue(screen.contains(clamped))
    }

    func testBestScreenFallsBackToFirst() {
        let second = CGRect(x: 1512, y: 0, width: 1920, height: 1050)
        let onSecond = CGRect(x: 2000, y: 100, width: 420, height: 180)
        XCTAssertEqual(OverlayLayout.bestScreenIndex(for: onSecond, visibleFrames: [screen, second]), 1)
        let nowhere = CGRect(x: -9000, y: 0, width: 10, height: 10)
        XCTAssertEqual(OverlayLayout.bestScreenIndex(for: nowhere, visibleFrames: [screen, second]), 0)
        XCTAssertNil(OverlayLayout.bestScreenIndex(for: nowhere, visibleFrames: []))
    }
}

final class DayPhaseTests: XCTestCase {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: hour, minute: minute))!
    }

    func testPhases() {
        XCTAssertEqual(DayPhase.at(at(3), calendar: calendar), .night)
        XCTAssertEqual(DayPhase.at(at(5), calendar: calendar), .dawn)
        XCTAssertEqual(DayPhase.at(at(12), calendar: calendar), .day)
        XCTAssertEqual(DayPhase.at(at(17, 29), calendar: calendar), .day)
        XCTAssertEqual(DayPhase.at(at(17, 30), calendar: calendar), .dusk)
        XCTAssertEqual(DayPhase.at(at(19, 30), calendar: calendar), .night)
        XCTAssertTrue(DayPhase.night.lightsOn)
        XCTAssertFalse(DayPhase.day.lightsOn)
    }

    func testLateNight() {
        XCTAssertTrue(TownSnapshot.isLateNight(at(23, 10), calendar: calendar))
        XCTAssertTrue(TownSnapshot.isLateNight(at(2), calendar: calendar))
        XCTAssertFalse(TownSnapshot.isLateNight(at(21), calendar: calendar))
    }
}
