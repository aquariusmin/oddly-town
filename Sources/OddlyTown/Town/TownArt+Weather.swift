import SpriteKit

/// Weather sprites (see `TownScene.applyWeather`).
extension TownArt {
    static let raindropRows = ["b", "b"]
    static let snowflakeRows = ["c"]
    /// Held above a resident's head in the rain.
    static let umbrellaRows = [
        "..kkk..",
        ".kYYYk.",
        "kYoYoYk",
        "kkkkkkk",
        "...k...",
    ]

    static var raindrop: SKTexture { tex("raindrop", raindropRows, palette: ["b": 0xB7D3EE]) }
    static var snowflake: SKTexture { tex("snowflake", snowflakeRows, palette: ["c": 0xFFFFFF]) }
    static var umbrella: SKTexture { tex("umbrella", umbrellaRows) }
}
