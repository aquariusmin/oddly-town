import SpriteKit
import OddlyTownCore

extension TownArt {
    /// Front-row slot positions (left edge, baseline) for Town Mode decorations.
    static let decorSlots: [CGPoint] = [
        CGPoint(x: 30, y: 2), CGPoint(x: 50, y: 2), CGPoint(x: 88, y: 2), CGPoint(x: 100, y: 2),
    ]

    static func decorRows(_ item: DecorItem) -> [String] {
        switch item {
        case .bench:
            return ["MMMMMMMM", "mmmmmmmm", "M......M", "M......M"]
        case .flowerBox:
            return [".p.Y.v.", "pgYgvgp", "MMMMMMM", ".M...M."]
        case .signpost:
            return ["mmmmm.", "mmmmmm", "mmmmm.", "..M...", "..M...", "..M...", ".MMM.."]
        case .sapling:
            return youngTreeRows
        case .lantern:
            return ["kkk", "kYk", "kYk", "kkk", ".k.", ".k.", "kkk"]
        case .birdbath:
            return ["sbbbbbs", ".sssss.", "..sss..", "..sss..", ".SSSSS."]
        case .pumpkins:
            return [".G...G..", "oOo.oOo.", "oOo.oOo."]
        case .mushrooms:
            return [".rr.r.", "rwrrwr", ".w..w."]
        }
    }

    static let decorPalette = recolored(["O": 0xC9772E])

    static func decorTexture(_ item: DecorItem) -> SKTexture {
        tex("decor-\(item.rawValue)", decorRows(item), palette: decorPalette)
    }

    /// Dotted outline marking an empty slot (Town Mode only).
    static var emptySlotMarker: SKTexture {
        tex("decor-empty-slot", ["k.k.k.k.k", ".........", "k.k.k.k.k"], palette: ["k": 0xFFFFFF])
    }
}
