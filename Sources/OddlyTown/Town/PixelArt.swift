import AppKit
import SpriteKit

/// Builds crisp SKTextures from ASCII pixel maps: one character = one pixel,
/// `palette` maps characters to 0xRRGGBB, unmapped characters are transparent.
/// Ragged rows are padded, so a miscounted row shifts art instead of crashing.
enum PixelArt {
    static func texture(_ rows: [String], palette: [Character: UInt32], only: Set<Character>? = nil) -> SKTexture {
        let height = rows.count
        let width = rows.map(\.count).max() ?? 0
        let grid = rows.map(Array.init)
        return make(width: width, height: height) { x, y in
            guard x < grid[y].count else { return nil }
            let ch = grid[y][x]
            if let only, !only.contains(ch) { return nil }
            guard let rgb = palette[ch] else { return nil }
            return (rgb, 1)
        }
    }

    /// Stepped radial glow, drawn in pixels so it matches the art style.
    static func glow(radius: Int, rgb: UInt32) -> SKTexture {
        let size = radius * 2
        return make(width: size, height: size) { x, y in
            let dx = Double(x) + 0.5 - Double(radius)
            let dy = Double(y) + 0.5 - Double(radius)
            let d = (dx * dx + dy * dy).squareRoot() / Double(radius)
            switch d {
            case ..<0.35: return (rgb, 0.45)
            case ..<0.7: return (rgb, 0.28)
            case ..<1.0: return (rgb, 0.12)
            default: return nil
            }
        }
    }

    /// Shifts rows in `range` right by `offset` pixels (used for the 2-frame tree sway).
    static func shiftRows(_ rows: [String], _ range: Range<Int>, by offset: Int) -> [String] {
        rows.enumerated().map { index, row in
            guard range.contains(index) else { return row }
            return String(repeating: ".", count: offset) + row.dropLast(offset)
        }
    }

    /// `pixel(x, y)` with y = 0 at the top row. Returns (0xRRGGBB, alpha) or nil for transparent.
    static func make(width: Int, height: Int, pixel: (Int, Int) -> (UInt32, Double)?) -> SKTexture {
        guard width > 0, height > 0 else { return SKTexture() }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                guard let (rgb, alpha) = pixel(x, y) else { continue }
                let a = min(max(alpha, 0), 1)
                let i = (y * width + x) * 4
                // Premultiplied alpha.
                bytes[i] = UInt8(Double((rgb >> 16) & 0xFF) * a)
                bytes[i + 1] = UInt8(Double((rgb >> 8) & 0xFF) * a)
                bytes[i + 2] = UInt8(Double(rgb & 0xFF) * a)
                bytes[i + 3] = UInt8(255 * a)
            }
        }
        guard
            let provider = CGDataProvider(data: Data(bytes) as CFData),
            let image = CGImage(
                width: width, height: height,
                bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
            )
        else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }

    /// Lets a real PNG (Contents/Resources/Art/<name>.png) replace a generated texture.
    static func override(named name: String) -> SKTexture? {
        guard
            let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Art"),
            let image = NSImage(contentsOf: url)
        else { return nil }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }
}
