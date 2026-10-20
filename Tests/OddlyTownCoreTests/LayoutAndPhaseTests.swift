import Foundation
#if canImport(CoreGraphics)
import CoreGraphics // CGRect geometry (minX, contains, …) lives here on macOS
#endif
import Testing
@testable import OddlyTownCore

@Suite struct OverlayLayoutTests {
    let screen = CGRect(x: 0, y: 80, width: 1512, height: 870) // visible frame minus Dock

    @Test func bottomRightIsDefaultCorner() {
        let frame = OverlayLayout.frame(corner: .bottomRight, size: CGSize(width: 420, height: 180), in: screen)
        #expect(frame.maxX == screen.maxX - OverlayLayout.margin)
        #expect(frame.minY == screen.minY + OverlayLayout.margin)
    }

    @Test func topLeft() {
        let frame = OverlayLayout.frame(corner: .topLeft, size: CGSize(width: 420, height: 180), in: screen)
        #expect(frame.minX == OverlayLayout.margin)
        #expect(frame.maxY == screen.maxY - OverlayLayout.margin)
    }

    @Test func clampPullsOffscreenWindowBack() {
        let off = CGRect(x: 5000, y: -400, width: 420, height: 180)
        #expect(screen.contains(OverlayLayout.clamp(off, into: screen)))
    }

    @Test func bestScreenFallsBackToFirst() {
        let second = CGRect(x: 1512, y: 0, width: 1920, height: 1050)
        let onSecond = CGRect(x: 2000, y: 100, width: 420, height: 180)
        #expect(OverlayLayout.bestScreenIndex(for: onSecond, visibleFrames: [screen, second]) == 1)
        let nowhere = CGRect(x: -9000, y: 0, width: 10, height: 10)
        #expect(OverlayLayout.bestScreenIndex(for: nowhere, visibleFrames: [screen, second]) == 0)
        #expect(OverlayLayout.bestScreenIndex(for: nowhere, visibleFrames: []) == nil)
    }
}

@Suite struct DayPhaseTests {
    let calendar = TestSupport.utc

    func at(_ hour: Int, _ minute: Int = 0) -> Date {
        TestSupport.date(day: 21, hour: hour, minute: minute)
    }

    @Test func phases() {
        #expect(DayPhase.at(at(3), calendar: calendar) == .night)
        #expect(DayPhase.at(at(5), calendar: calendar) == .dawn)
        #expect(DayPhase.at(at(12), calendar: calendar) == .day)
        #expect(DayPhase.at(at(17, 29), calendar: calendar) == .day)
        #expect(DayPhase.at(at(17, 30), calendar: calendar) == .dusk)
        #expect(DayPhase.at(at(19, 30), calendar: calendar) == .night)
        #expect(DayPhase.night.lightsOn)
        #expect(!DayPhase.day.lightsOn)
    }

    @Test func lateNight() {
        #expect(TownSnapshot.isLateNight(at(23, 10), calendar: calendar))
        #expect(TownSnapshot.isLateNight(at(2), calendar: calendar))
        #expect(!TownSnapshot.isLateNight(at(21), calendar: calendar))
    }
}
