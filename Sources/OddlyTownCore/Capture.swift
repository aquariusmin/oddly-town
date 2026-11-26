import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// Capture Studio: a clean, UI-free view of the town for screen recording.
// This file holds the parts that are pure maths and data (framing, integer scales,
// pixel-snapped camera, scene presets) so they can be unit-tested without AppKit.

/// Shape of the capture window. Canvases are in art pixels; the 140 × 60 town fits
/// every canvas at zoom 1.
public enum CaptureFraming: String, CaseIterable, Sendable {
    case wide, vertical, square

    public var canvas: CGSize {
        switch self {
        case .wide: return CGSize(width: 160, height: 90)      // 16:9
        case .vertical: return CGSize(width: 144, height: 256) // 9:16 (Reels, Shorts)
        case .square: return CGSize(width: 150, height: 150)
        }
    }

    public var displayName: String {
        switch self {
        case .wide: return "16:9"
        case .vertical: return "9:16"
        case .square: return "1:1"
        }
    }
}

/// Backdrop behind the town in Capture Studio.
public enum CaptureBackground: String, CaseIterable, Sendable {
    /// Stepped sky gradient that follows the time of day.
    case sky
    /// Flat #FF00FF for chroma keying (no art pixel uses magenta).
    case key
    /// Calm dark gradient for product shots.
    case studio
}

/// What the camera keeps centred.
public enum CaptureFocus: Equatable, Sendable {
    case town
    case point(x: Double, y: Double)
    case resident(Int)
}

/// Integer-only scale and camera maths. Everything returned here lands on whole device
/// pixels, so nearest-neighbour art never resamples unevenly.
public enum CaptureLayout {
    public static let world = CGSize(width: 140, height: 60)
    public static let townCentre = CGPoint(x: 70, y: 30)
    /// Points per art pixel. On a Retina display each point is 2 device pixels.
    public static let pointScales = [2, 3, 4]
    /// Close-up zoom on top of the point scale.
    public static let zooms = [1, 2, 3, 4]

    /// The largest allowed point scale ≤ `requested` whose window fits in `available`
    /// (points). Falls back to the smallest scale if nothing fits.
    public static func pointScale(requested: Int, framing: CaptureFraming, fitting available: CGSize) -> Int {
        let candidates = pointScales.filter { $0 <= requested }.sorted(by: >)
        for scale in candidates {
            let size = viewSize(framing: framing, pointScale: scale)
            if size.width <= available.width && size.height <= available.height { return scale }
        }
        return pointScales.min() ?? 1
    }

    public static func viewSize(framing: CaptureFraming, pointScale: Int) -> CGSize {
        CGSize(width: framing.canvas.width * CGFloat(pointScale), height: framing.canvas.height * CGFloat(pointScale))
    }

    /// Position (points, bottom-left origin) of the world node so that the art point
    /// `focus` sits at the view centre at `worldScale` points per art pixel.
    ///
    /// When the town is narrower/shorter than the view it stays fully on screen;
    /// when it's larger (close-ups) the view never runs past its edges.
    /// The result is snapped to whole device pixels.
    public static func worldOrigin(focus: CGPoint, viewSize: CGSize, worldScale: Int,
                                   devicePixelsPerPoint: CGFloat = 2) -> CGPoint {
        let s = CGFloat(max(1, worldScale))
        let w = world.width * s, h = world.height * s
        func axis(_ focus: CGFloat, view: CGFloat, size: CGFloat) -> CGFloat {
            let wanted = view / 2 - focus * s
            return size <= view
                ? min(max(wanted, 0), view - size) // keep the whole town in view
                : min(max(wanted, view - size), 0) // never show past the town's edge
        }
        return snapped(CGPoint(x: axis(focus.x, view: viewSize.width, size: w),
                               y: axis(focus.y, view: viewSize.height, size: h)),
                       devicePixelsPerPoint: devicePixelsPerPoint)
    }

    /// Rounds to the nearest whole device pixel.
    public static func snapped(_ p: CGPoint, devicePixelsPerPoint: CGFloat) -> CGPoint {
        let d = max(1, devicePixelsPerPoint)
        return CGPoint(x: (p.x * d).rounded() / d, y: (p.y * d).rounded() / d)
    }
}

/// A ready-to-record town state: one key press sets level, time, buildings,
/// decorations, what residents do, and the framing.
public struct CapturePreset: Equatable, Sendable {
    public let key: String
    public let title: String
    public let level: Int
    public let phase: DayPhase
    /// Activity buildings to show on top of the level's own features.
    public let extras: Set<TownFeature>
    public let decor: DecorLayout
    /// nil = residents live normally.
    public let residents: ResidentActivity?
    public let zoom: Int
    public let focus: CaptureFocus
    /// nil = the real calendar's season.
    public let season: Season?

    public init(key: String, title: String, level: Int, phase: DayPhase, extras: Set<TownFeature>,
                decor: DecorLayout, residents: ResidentActivity?, zoom: Int, focus: CaptureFocus,
                season: Season? = nil) {
        self.key = key
        self.title = title
        self.level = level
        self.phase = phase
        self.extras = extras
        self.decor = decor
        self.residents = residents
        self.zoom = zoom
        self.focus = focus
        self.season = season
    }

    public static let activityFeatures: Set<TownFeature> = [.workshop, .artGarden, .readingNook, .festivalBunting]

    public static let all: [CapturePreset] = [
        CapturePreset(key: "1", title: "Town", level: 3, phase: .day, extras: [.workshop],
                      decor: DecorLayout(slots: [.bench, .signpost, .flowerBox, .lantern]),
                      residents: nil, zoom: 1, focus: .town),
        CapturePreset(key: "2", title: "Residents", level: 3, phase: .day, extras: [.workshop],
                      decor: DecorLayout(slots: [.bench, .signpost, .flowerBox, .lantern]),
                      residents: .socializing, zoom: 3, focus: .point(x: 70, y: 14)),
        CapturePreset(key: "3", title: "Night", level: 3, phase: .night, extras: [.workshop, .readingNook],
                      decor: DecorLayout(slots: [.lantern, .bench, .flowerBox, .lantern]),
                      residents: nil, zoom: 1, focus: .town),
        CapturePreset(key: "4", title: "Decorations", level: 3, phase: .day, extras: [],
                      decor: DecorLayout(slots: [.bench, .flowerBox, .pumpkins, .birdbath]),
                      residents: .sitting, zoom: 2, focus: .point(x: 64, y: 12)),
        CapturePreset(key: "5", title: "Fully grown", level: 3, phase: .day, extras: activityFeatures,
                      decor: DecorLayout(slots: [.bench, .flowerBox, .lantern, .mushrooms]),
                      residents: .celebrating, zoom: 1, focus: .town),
        CapturePreset(key: "6", title: "Winter night", level: 3, phase: .night, extras: [.workshop],
                      decor: DecorLayout(slots: [.lantern, .bench, .sapling, .lantern]),
                      residents: nil, zoom: 1, focus: .town, season: .winter),
    ]

    /// Decoration sets the O key cycles through.
    public static let decorSets: [DecorLayout] = [
        .standard,
        DecorLayout(slots: [.bench, .signpost, .flowerBox, .lantern]),
        DecorLayout(slots: [.bench, .flowerBox, .pumpkins, .birdbath]),
        DecorLayout(slots: [.lantern, .mushrooms, .sapling, .pumpkins]),
        DecorLayout(slots: []),
    ]
}

extension CaseIterable where Self: Equatable, AllCases.Index == Int {
    /// The next case, wrapping around (for "press again to cycle" shortcuts).
    public var next: Self {
        let all = Self.allCases
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + 1) % all.count]
    }
}
