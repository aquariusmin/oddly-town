import SpriteKit

/// All placeholder art for v0.1, drawn as original ASCII pixel maps.
/// To swap in real art, drop `<name>.png` into Resources/Art (see README);
/// `PixelArt.override(named:)` picks it up at launch.
enum TownArt {
    static let palette: [Character: UInt32] = [
        "k": 0x3B2A33, // outline
        "r": 0xD0644A, "R": 0x9C3D2E, // red roof
        "w": 0xF3E6C8, "W": 0xDCC7A2, // walls
        "d": 0x7A4B2A, // door
        "y": 0x9CCBE8, // window glass (day)
        "Y": 0xF6D55C, // yellow
        "g": 0x63A84C, "G": 0x3F7A3A, "l": 0x93CF63, // leaves
        "t": 0x7A4B2A, // trunk
        "s": 0xA4A9AE, "S": 0x6F747C, // stone
        "m": 0xB57D4C, "M": 0x8A5A34, // wood
        "o": 0xF2A541, "p": 0xF29AB5, "v": 0x9B6BD3, "b": 0x5B8FD0, // flower / paint colours
        "c": 0xFFFFFF, "C": 0xE1EAF3, // cloud
        "P": 0xE4C48F, // path
    ]

    static func tex(_ name: String, _ rows: [String], palette: [Character: UInt32] = TownArt.palette) -> SKTexture {
        PixelArt.override(named: name) ?? PixelArt.texture(rows, palette: palette)
    }

    static func recolored(_ changes: [Character: UInt32]) -> [Character: UInt32] {
        palette.merging(changes) { _, new in new }
    }

    /// Window-light overlay: only the glass pixels, in warm yellow.
    static func lights(_ rows: [String]) -> SKTexture {
        PixelArt.texture(rows, palette: ["y": 0xFFD36E], only: ["y"])
    }

    // MARK: Buildings

    static let cottageRows = [
        "......kkkk......",
        ".....krrrrk.....",
        "....krrrrrrk....",
        "...krrrrrrrrk...",
        "..krrrrrrrrrrk..",
        ".krrrrrrrrrrrrk.",
        "kRRRRRRRRRRRRRRk",
        ".kwwwwwwwwwwwwk.",
        ".kwyywwwwwwyywk.",
        ".kwyywwkkwwyywk.",
        ".kwwwwwddwwwwwk.",
        ".kWWWWWddWWWWWk.",
        ".kwwwwwddwwwwwk.",
        ".kSSSSSSSSSSSSk.",
    ]
    static let blueRoof = recolored(["r": 0x5B7FC4, "R": 0x3F5E9A])

    static let workshopRows = [
        ".............kk...",
        ".............SS...",
        "..kkkkkkkkkkkSSkk.",
        ".kMMMMMMMMMMMMMMMk",
        "kMMMMMMMMMMMMMMMMk",
        ".kmmmmmmmmmmmmmmk.",
        ".kmoooommmmmyymmk.",
        ".kmoSSommmmmyymmk.",
        ".kmoooommkkmmmmmk.",
        ".kmmmmmmmddmmmmmk.",
        ".kMMMMMMMddMMMMMk.",
        ".kmmmmmmmddmmmmmk.",
        ".kSSSSSSSSSSSSSSk.",
    ]

    static let readingNookRows = [
        "......kk......",
        ".....kBBk.....",
        "....kBBBBk....",
        "...kBBBBBBk...",
        "..kBBBBBBBBk..",
        ".kBBBBBBBBBBk.",
        "kbbbbbbbbbbbbk",
        ".kwwwwwwwwwwk.",
        ".kwpYvowwyywk.",
        ".kwpYvowwyywk.",
        ".kwwwwkkwwwwk.",
        ".kWWWWddWWWWk.",
        ".kwwwwddwwwwk.",
        ".kSSSSSSSSSSk.",
    ]
    static let tealRoof = recolored(["B": 0x2F7F7A, "b": 0x4FA89F])

    static let wellRows = [
        ".MMMMMMM.",
        "MmmmmmmmM",
        ".m.....m.",
        ".m..k..m.",
        ".m..S..m.",
        ".m.....m.",
        "sSsSsSsSs",
        "sssssssss",
        "SsSsSsSsS",
        "sssssssss",
    ]

    static let pathBranchRows = Array(repeating: "PP", count: 6)

    // MARK: Nature

    static let treeRows = [
        "...GGGGG...",
        "..GgggggG..",
        ".GgglllggG.",
        "GgglllllggG",
        "GggllgggggG",
        "GgggggggggG",
        ".GgggggggG.",
        "GGgggggggGG",
        "GgggggggGgG",
        ".GGgggggGG.",
        "...GtttG...",
        "....ttt....",
        "....ttt....",
        "...ttttt...",
    ]

    static let youngTreeRows = [
        "..GGG..",
        ".GgllG.",
        "GgllggG",
        "GggggGG",
        ".GgggG.",
        "..GtG..",
        "...t...",
        "...t...",
        "..ttt..",
    ]

    static let cloudRows = [
        "....cccc......",
        "..cccccccc.cc.",
        ".ccccccccccccc",
        "cccccccccccccc",
        ".CCCCCCCCCCCC.",
    ]

    static let smallCloudRows = [
        "..ccc....",
        ".ccccccc.",
        "ccccccccc",
        ".CCCCCCC.",
    ]

    static let wildflowerRows = [
        "p...Y....v...p...Y...v",
        "g...g....g...g...g...g",
    ]

    static let flowerBedRows = [
        ".p.Y.v.p.o.Y.v..",
        "pgpYgYvgvpgpoYgo",
        "gGgGgGgGgGgGgGgG",
        "MMMMMMMMMMMMMMMM",
    ]

    static let rockRows = [
        ".sss.",
        "sssSs",
        "SSSSS",
    ]

    // MARK: Props

    static let mailboxRows = [".rr", "rrr", "rRr", ".m.", ".m.", ".m."]

    static let lamppostRows = ["kkk", "kYk", "kkk", ".k.", ".k.", ".k.", ".k.", ".k.", ".k.", ".k.", "kkk"]

    static let fenceRows = [
        "w.w.w.w.w.w",
        "wwwwwwwwwww",
        "w.w.w.w.w.w",
        "WWWWWWWWWWW",
        "w.w.w.w.w.w",
    ]

    static let easelRows = [
        "kkkkkkk",
        "kpYbvok",
        "kYbvpok",
        "kbvpYok",
        "kkkkkkk",
        ".m...m.",
        ".m.m.m.",
        "m..m..m",
        "m..m..m",
        "m.....m",
    ]

    static let poleRows = ["kk"] + Array(repeating: "MM", count: 23)

    static let sunRows = ["..YYY..", ".YYYYY.", "YYYYYYY", "YYYYYYY", "YYYYYYY", ".YYYYY.", "..YYY.."]
    static let moonRows = ["..ccc..", ".ccc...", "ccc....", "ccc....", "ccc....", ".ccc...", "..ccc.."]
    static let moonPalette: [Character: UInt32] = ["c": 0xF4F1DE]

    // MARK: Residents

    static func residentFrames(shirt: UInt32, hair: UInt32) -> (idle: SKTexture, walk: [SKTexture]) {
        let colors: [Character: UInt32] = ["n": hair, "h": 0xF1C7A0, "s": shirt, "k": 0x3D405B]
        let top = [".nnn.", "nnhhh", ".hhh.", "sssss", "hsssh", ".sss."]
        let idle = PixelArt.texture(top + [".k.k.", ".k.k."], palette: colors)
        let a = PixelArt.texture(top + [".k.k.", "k...k"], palette: colors)
        let b = PixelArt.texture(top + ["..k..", "..k.."], palette: colors)
        return (idle, [a, b])
    }

    // MARK: Generated pieces

    /// Floating grass island with a dirt underside and a path band. 140 × 17 px.
    static func groundRows(width: Int = 140) -> [String] {
        let height = 17
        let insets = [2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 3, 6]
        return (0..<height).map { r in
            let inset = insets[r]
            return String((0..<width).map { x -> Character in
                if x < inset || x >= width - inset { return "." }
                if x == inset || x == width - inset - 1 { return "k" }
                if r >= 14 { return (x + r) % 5 == 0 ? "m" : "M" }
                if r == 0 { return "l" }
                if (8...11).contains(r) { return (x * 7 + r * 3) % 23 == 0 ? "s" : "P" }
                return (x * 13 + r * 5) % 37 == 0 ? "G" : "g"
            })
        }
    }

    /// String of pennants with a gentle sag; `frame` 1 flips the tails for a flutter.
    static func buntingTexture(width: Int, frame: Int) -> SKTexture {
        let height = 7
        let colors: [UInt32] = [0xD0644A, 0xF6D55C, 0x5B8FD0, 0xF29AB5, 0xF2A541, 0x9B6BD3]
        let mid = Double(width - 1) / 2
        func sag(_ x: Int) -> Int { Int(((1 - pow((Double(x) - mid) / mid, 2)) * 3).rounded()) }
        return PixelArt.make(width: width, height: height) { x, y in
            if y == sag(x) { return (0x3B2A33, 1) }
            let slot = x / 7, offset = x % 7
            guard (1...3).contains(offset) else { return nil }
            let anchorY = sag(slot * 7 + 2)
            let color = colors[slot % colors.count]
            if y == anchorY + 1 { return (color, 1) }
            let tail = frame == 0 ? 2 : (slot % 2 == 0 ? 1 : 3)
            if y == anchorY + 2 && offset == tail { return (color, 1) }
            return nil
        }
    }
}
