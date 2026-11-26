import SpriteKit

/// Frames for one resident. Frames are drawn 7 px wide with the body centred on column 3,
/// then get a 1 px outline (9 px wide, body on column 4), so switching frames never
/// shifts the character.
struct ResidentFrames {
    let idle, sit, crouch, talk, cheer: SKTexture
    let walk, work, read: [SKTexture]
}

struct ResidentLook {
    let name: String
    let shirt: UInt32
    let hair: UInt32
    let trousers: UInt32
}

extension TownArt {
    static let residentLooks = [
        ResidentLook(name: "Mori", shirt: 0xE07A5F, hair: 0x4A3326, trousers: 0x3D405B),
        // Pip's sage and Juno's sand shirts used to blend into the grass and the path.
        ResidentLook(name: "Pip", shirt: 0x4FA3C7, hair: 0xC0703A, trousers: 0x5A4A42),
        ResidentLook(name: "Juno", shirt: 0xB86FA8, hair: 0x2B2D42, trousers: 0x4A4E69),
    ]

    private static let head: [String] = ["..nnn..", ".nnheh.", "..hhh.."]
    private static let body: [String] = [".sssss.", ".hsssh.", "..sss.."]
    private static let legs: [String] = ["..k.k..", "..k.k.."]

    // Explicitly typed pieces keep this literal quick to type-check.
    static let residentRows: [String: [String]] = [
        "idle": head + body + legs,
        "walkA": head + body + ["..k.k..", ".k...k."],
        "walkB": head + body + ["...k...", "...k..."],
        "sit": head + body + ["..kkkk."],
        "crouch": head + [".hssss.", "..sss..", ".kk.k.."],
        "talk": head + [".ssssh.", ".hsss..", "..sss.."] + legs,
        "cheer": ["h.nnn.h", "hnnhehh", "..hhh.."] + body + legs,
        "workA": ["..nnn..", ".nnhehS", "..hhh.m", ".ssssh.", ".hsss..", "..sss.."] + legs,
        "workB": head + [".sssssh", ".hsss.m", "..sss.S"] + legs,
        "readA": head + [".sssbb.", ".hssbb.", "..sss.."] + legs,
        "readB": head + [".sssbc.", ".hssbb.", "..sss.."] + legs,
    ]

    static func residentFrames(_ look: ResidentLook) -> ResidentFrames {
        let colors: [Character: UInt32] = [
            "n": look.hair, "h": 0xF1C7A0, "s": look.shirt, "k": look.trousers,
            "S": 0x6F747C, "m": 0xB57D4C, "b": 0x5B8FD0, "c": 0xFFFFFF,
            "e": 0x2A1F26, "o": 0x2A1F26,
        ]
        func frame(_ key: String) -> SKTexture {
            tex("resident-\(look.name.lowercased())-\(key)", outlined(residentRows[key] ?? []), palette: colors)
        }
        return ResidentFrames(
            idle: frame("idle"), sit: frame("sit"), crouch: frame("crouch"), talk: frame("talk"), cheer: frame("cheer"),
            walk: [frame("walkA"), frame("walkB")],
            work: [frame("workA"), frame("workB")],
            read: [frame("readA"), frame("readB")]
        )
    }

    /// Adds a 1 px dark outline ('o') around the outside of a sprite so residents stay
    /// readable against grass, path and buildings. Pads one column each side and one row
    /// on top; the feet row stays on the ground line. Gaps enclosed by the body (between
    /// the legs) are left open.
    static func outlined(_ rows: [String]) -> [String] {
        let width = (rows.map(\.count).max() ?? 0) + 2
        var grid: [[Character]] = [Array(repeating: ".", count: width)]
        grid += rows.map { Array("." + $0.padding(toLength: width - 2, withPad: ".", startingAt: 0) + ".") }
        let h = grid.count
        func opaque(_ x: Int, _ y: Int) -> Bool { grid[y][x] != "." }
        // Transparent cells reachable from the top/left/right border are "outside".
        var outside = Array(repeating: Array(repeating: false, count: width), count: h)
        var stack: [(Int, Int)] = []
        for x in 0..<width { stack.append((x, 0)) }
        for y in 0..<h { stack.append((0, y)); stack.append((width - 1, y)) }
        while let cell = stack.popLast() {
            let (x, y) = cell
            guard x >= 0, x < width, y >= 0, y < h, !outside[y][x], !opaque(x, y) else { continue }
            outside[y][x] = true
            stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
        }
        var out = grid
        for y in 0..<h {
            for x in 0..<width where outside[y][x] {
                let touches = (x > 0 && opaque(x - 1, y)) || (x < width - 1 && opaque(x + 1, y))
                    || (y < h - 1 && opaque(x, y + 1)) || (y > 0 && opaque(x, y - 1))
                if touches { out[y][x] = "o" }
            }
        }
        return out.map { String($0) }
    }

    // MARK: Visitors

    /// Traveler with a wide hat and a backpack.
    static func travelerFrames() -> (idle: SKTexture, walk: [SKTexture]) {
        let colors: [Character: UInt32] = ["M": 0x8A5A34, "h": 0xF1C7A0, "s": 0x6B8F71, "k": 0x4A3F35]
        let top = ["..MMM..", ".MMMMM.", "..hhh..", "Msssss.", "Mhsssh.", "..sss.."]
        return (
            tex("traveler-idle", top + ["..k.k..", "..k.k.."], palette: colors),
            [tex("traveler-walkA", top + ["..k.k..", ".k...k."], palette: colors),
             tex("traveler-walkB", top + ["...k...", "...k..."], palette: colors)]
        )
    }

    /// Orange stray cat, facing right.
    static func catFrames() -> (walk: [SKTexture], sit: SKTexture) {
        let colors: [Character: UInt32] = ["k": 0xE59A4F, "e": 0x3B2A33]
        return (
            [tex("cat-walkA", ["k....k.k", ".k...kek", "..kkkkkk", "..k.k.k."], palette: colors),
             tex("cat-walkB", ["k....k.k", ".k...kek", "..kkkkkk", "...k.k.k"], palette: colors)],
            tex("cat-sit", [".....k.k", "k....kek", ".k.kkkk.", "..kkkkk."], palette: colors)
        )
    }

    /// Tiny "…" shown now and then while residents chat. Deliberately small.
    static var chatDots: SKTexture {
        tex("chat-dots", ["ccccccc", "ckckckc", "ccccccc", ".c....."], palette: ["c": 0xFFFFFF, "k": 0x3B2A33])
    }

    /// Small arrow above whatever is selected in Town Mode.
    static var selectionArrow: SKTexture {
        tex("selection-arrow", ["kkkkk", ".kYk.", "..k.."], palette: ["k": 0x3B2A33, "Y": 0xF6D55C])
    }
}
