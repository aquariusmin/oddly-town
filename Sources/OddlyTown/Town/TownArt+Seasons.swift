import SpriteKit
import OddlyTownCore

/// How a sprite changes with the seasons.
enum SeasonRole {
    /// The grass island and path pieces: recoloured every season, snow-covered in winter.
    case ground
    /// Tree canopies: blossom, autumn colours, snow-topped evergreen in winter.
    case foliage
    /// Houses and props: unchanged except for snow on top in winter.
    case structure
}

/// Seasonal looks are palette changes plus a generated snow cap, so every season is
/// derived from the same ASCII art. Summer is the base art.
/// (scripts/render-art-preview.py reads these tables; keep the `static let` form.)
extension TownArt {
    static let springGround: [Character: UInt32] = ["g": 0x6DB552, "G": 0x45843D, "l": 0xA6DD72, "L": 0xC9EE8C]
    static let springFoliage: [Character: UInt32] = ["l": 0xF4B6CB]
    static let autumnGround: [Character: UInt32] = ["g": 0x8E9F48, "G": 0x6B7A36, "l": 0xB4B95C, "L": 0xD3C46A]
    static let autumnFoliage: [Character: UInt32] = ["g": 0xE0893A, "G": 0xA94F2B, "l": 0xF4BF4F]
    static let winterGround: [Character: UInt32] = ["g": 0xEDF2F7, "G": 0xC9D5E3, "l": 0xFFFFFF, "L": 0xFFFFFF,
                                                    "P": 0xD8CDB8, "Q": 0xC2B59C]
    static let winterFoliage: [Character: UInt32] = ["g": 0x4E7D5B, "G": 0x33583F, "l": 0x6F9878]

    static func seasonChanges(_ season: Season, _ role: SeasonRole) -> [Character: UInt32] {
        switch (season, role) {
        case (.spring, .ground): return springGround
        case (.spring, .foliage): return springFoliage
        case (.autumn, .ground): return autumnGround
        case (.autumn, .foliage): return autumnFoliage
        case (.winter, .ground): return winterGround
        case (.winter, .foliage): return winterFoliage
        default: return [:]
        }
    }

    /// In winter everything but the ground gets snow on top.
    static func seasonRows(_ rows: [String], _ role: SeasonRole, _ season: Season) -> [String] {
        season == .winter && role != .ground ? PixelArt.snowCapped(rows) : rows
    }

    /// Summer uses the plain name, so existing PNG overrides keep working. Other seasons are
    /// cached, and can be overridden, as "<name>@<season>" (e.g. `cottage@winter.png`).
    static func seasonal(_ name: String, _ rows: [String], palette: [Character: UInt32] = TownArt.palette,
                         role: SeasonRole, season: Season) -> SKTexture {
        guard season != .summer else { return tex(name, rows, palette: palette) }
        let key = "\(name)@\(season.rawValue)"
        return cached(key) {
            PixelArt.override(named: key) ?? PixelArt.texture(
                seasonRows(rows, role, season),
                palette: palette.merging(seasonChanges(season, role)) { _, new in new }
            )
        }
    }
}
