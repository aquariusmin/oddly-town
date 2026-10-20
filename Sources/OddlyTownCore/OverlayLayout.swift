import Foundation

/// Window placement math, kept free of AppKit so it can be unit-tested.
/// Rects use AppKit's bottom-left-origin screen coordinates.
public enum OverlayLayout {
    public static let margin: CGFloat = 12

    public static func frame(corner: ScreenCorner, size: CGSize, in visible: CGRect) -> CGRect {
        let left = visible.minX + margin
        let right = visible.maxX - size.width - margin
        let bottom = visible.minY + margin
        let top = visible.maxY - size.height - margin
        let origin: CGPoint
        switch corner {
        case .bottomRight, .custom: origin = CGPoint(x: right, y: bottom)
        case .bottomLeft: origin = CGPoint(x: left, y: bottom)
        case .topRight: origin = CGPoint(x: right, y: top)
        case .topLeft: origin = CGPoint(x: left, y: top)
        }
        return clamp(CGRect(origin: origin, size: size), into: visible)
    }

    /// Moves `rect` so it lies fully inside `visible` (pinned to the bottom-left if too big).
    public static func clamp(_ rect: CGRect, into visible: CGRect) -> CGRect {
        var r = rect
        r.origin.x = min(max(r.origin.x, visible.minX), max(visible.minX, visible.maxX - r.width))
        r.origin.y = min(max(r.origin.y, visible.minY), max(visible.minY, visible.maxY - r.height))
        return r
    }

    /// Picks the screen whose visible frame contains the rect's center, else the first one.
    public static func bestScreenIndex(for rect: CGRect, visibleFrames: [CGRect]) -> Int? {
        guard !visibleFrames.isEmpty else { return nil }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return visibleFrames.firstIndex { $0.contains(center) } ?? 0
    }
}
