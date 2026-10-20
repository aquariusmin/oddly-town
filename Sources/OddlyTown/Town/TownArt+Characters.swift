import SpriteKit

/// Frames for one resident. All frames are 7 px wide with the body centred on column 3,
/// so switching frames never shifts the character.
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
        ResidentLook(name: "Pip", shirt: 0x81B29A, hair: 0xC0703A, trousers: 0x5A4A42),
        ResidentLook(name: "Juno", shirt: 0xF2CC8F, hair: 0x2B2D42, trousers: 0x6D597A),
    ]

    private static let head = ["..nnn..", ".nnhhh.", "..hhh.."]
    private static let body = [".sssss.", ".hsssh.", "..sss.."]
    private static let legs = ["..k.k..", "..k.k.."]

    static let residentRows: [String: [String]] = [
        "idle": head + body + legs,
        "walkA": head + body + ["..k.k..", ".k...k."],
        "walkB": head + body + ["...k...", "...k..."],
        "sit": head + body + ["..kkkk."],
        "crouch": head + [".hssss.", "..sss..", ".kk.k.."],
        "talk": head + [".ssssh.", ".hsss..", "..sss.."] + legs,
        "cheer": ["h.nnn.h", "hnnhhhh", "..hhh.."] + body + legs,
        "workA": ["..nnn..", ".nnhhhS", "..hhh.m", ".ssssh.", ".hsss..", "..sss.."] + legs,
        "workB": head + [".sssssh", ".hsss.m", "..sss.S"] + legs,
        "readA": head + [".sssbb.", ".hssbb.", "..sss.."] + legs,
        "readB": head + [".sssbc.", ".hssbb.", "..sss.."] + legs,
    ]

    static func residentFrames(_ look: ResidentLook) -> ResidentFrames {
        let colors: [Character: UInt32] = [
            "n": look.hair, "h": 0xF1C7A0, "s": look.shirt, "k": look.trousers,
            "S": 0x6F747C, "m": 0xB57D4C, "b": 0x5B8FD0, "c": 0xFFFFFF,
        ]
        func frame(_ key: String) -> SKTexture {
            tex("resident-\(look.name.lowercased())-\(key)", residentRows[key] ?? [], palette: colors)
        }
        return ResidentFrames(
            idle: frame("idle"), sit: frame("sit"), crouch: frame("crouch"), talk: frame("talk"), cheer: frame("cheer"),
            walk: [frame("walkA"), frame("walkB")],
            work: [frame("workA"), frame("workB")],
            read: [frame("readA"), frame("readB")]
        )
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
