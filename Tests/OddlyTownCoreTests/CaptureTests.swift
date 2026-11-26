import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Testing
@testable import OddlyTownCore

@Suite struct CaptureLayoutTests {
    let laptop = CGSize(width: 1512, height: 900) // visible area of a 14" MacBook Pro
    let big = CGSize(width: 2560, height: 1400)

    @Test func scalesAreWholeNumbers() {
        for framing in CaptureFraming.allCases {
            for scale in CaptureLayout.pointScales {
                let size = CaptureLayout.viewSize(framing: framing, pointScale: scale)
                #expect(size.width == size.width.rounded() && size.height == size.height.rounded())
                #expect(size.width >= CaptureLayout.world.width * CGFloat(scale))
                #expect(size.height >= CaptureLayout.world.height * CGFloat(scale))
            }
        }
    }

    @Test func pointScaleShrinksToFitTheScreen() {
        // 9:16 at 4× is 576 × 1024 pt: too tall for a laptop, so 3× is used.
        #expect(CaptureLayout.pointScale(requested: 4, framing: .vertical, fitting: laptop) == 3)
        #expect(CaptureLayout.pointScale(requested: 4, framing: .vertical, fitting: big) == 4)
        #expect(CaptureLayout.pointScale(requested: 4, framing: .wide, fitting: laptop) == 4)
        #expect(CaptureLayout.pointScale(requested: 2, framing: .wide, fitting: big) == 2)
        #expect(CaptureLayout.pointScale(requested: 4, framing: .vertical, fitting: CGSize(width: 100, height: 100)) == 2)
    }

    @Test func zoomOneShowsTheWholeTown() {
        for framing in CaptureFraming.allCases {
            for scale in CaptureLayout.pointScales {
                let view = CaptureLayout.viewSize(framing: framing, pointScale: scale)
                let o = CaptureLayout.worldOrigin(focus: CaptureLayout.townCentre, viewSize: view, worldScale: scale)
                #expect(o.x >= 0 && o.x + 140 * CGFloat(scale) <= view.width)
                #expect(o.y >= 0 && o.y + 60 * CGFloat(scale) <= view.height)
            }
        }
    }

    @Test func closeUpsNeverShowPastTheTown() {
        let view = CaptureLayout.viewSize(framing: .vertical, pointScale: 3)
        for zoom in CaptureLayout.zooms where zoom > 1 {
            let s = 3 * zoom
            for x in stride(from: -20.0, through: 160, by: 7.5) {
                let o = CaptureLayout.worldOrigin(focus: CGPoint(x: x, y: 10), viewSize: view, worldScale: s)
                if 140 * CGFloat(s) > view.width {
                    #expect(o.x <= 0 && o.x + 140 * CGFloat(s) >= view.width)
                }
            }
        }
    }

    @Test func cameraLandsOnWholeDevicePixels() {
        let view = CaptureLayout.viewSize(framing: .square, pointScale: 3)
        for x in stride(from: 40.0, through: 100, by: 0.37) {
            for d: CGFloat in [1, 2] {
                let o = CaptureLayout.worldOrigin(focus: CGPoint(x: x, y: 12.3), viewSize: view, worldScale: 9,
                                                  devicePixelsPerPoint: d)
                #expect((o.x * d).rounded() == o.x * d)
                #expect((o.y * d).rounded() == o.y * d)
            }
        }
    }

    @Test func focusIsCentredWhenThereIsRoom() {
        let view = CaptureLayout.viewSize(framing: .wide, pointScale: 4) // 640 × 360
        let o = CaptureLayout.worldOrigin(focus: CGPoint(x: 70, y: 14), viewSize: view, worldScale: 12)
        #expect(o.x + 70 * 12 == 320)
    }
}

@Suite struct CapturePresetTests {
    let engine = GrowthEngine(rules: .standard)

    @Test func presetsHaveUniqueKeysAndValidSettings() {
        let keys = CapturePreset.all.map(\.key)
        #expect(Set(keys).count == keys.count)
        for preset in CapturePreset.all {
            #expect((1...engine.rules.maxLevel).contains(preset.level))
            #expect(CaptureLayout.zooms.contains(preset.zoom))
            #expect(preset.extras.isSubset(of: CapturePreset.activityFeatures))
        }
    }

    @Test func presetDecorationsAreAllShownAtThePresetLevel() {
        for preset in CapturePreset.all {
            let snapshot = TownSnapshot.make(level: preset.level,
                                             features: engine.levelFeatures(forLevel: preset.level).union(preset.extras),
                                             decor: preset.decor, phase: preset.phase, lateNight: false)
            let placed = preset.decor.slots.compactMap { $0 }.count
            #expect(snapshot.decor.count == placed, "\(preset.title) places an item its level hides")
        }
    }

    @Test func nightPresetHasLightsOn() {
        let night = CapturePreset.all.first { $0.phase == .night }
        #expect(night?.phase.lightsOn == true)
        #expect(night?.decor.slots.contains(.lantern) == true)
    }

    @Test func cyclingWraps() {
        #expect(CaptureFraming.square.next == .wide)
        #expect(CaptureBackground.sky.next == .key)
    }
}
