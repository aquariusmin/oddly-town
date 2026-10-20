import Foundation

/// Maps a bundle identifier to an `ActivityCategory`.
///
/// Lookup order: user overrides → exact defaults → prefix defaults → `.other`.
/// Matching is case-insensitive. Edit the tables below to change default classification;
/// users can override per bundle ID via `AppSettings.categoryOverrides`.
public struct ActivityClassifier: Sendable {
    public static let defaultExact: [String: ActivityCategory] = [
        // Development
        "com.apple.dt.xcode": .development,
        "com.microsoft.vscode": .development,
        "com.microsoft.vscodeinsiders": .development,
        "com.todesktop.230313mzl4w4u92": .development, // Cursor
        "dev.zed.zed": .development,
        "com.sublimetext.4": .development,
        "com.panic.nova": .development,
        "com.apple.terminal": .development,
        "com.googlecode.iterm2": .development,
        "com.github.wez.wezterm": .development,
        "net.kovidgoyal.kitty": .development,
        "dev.warp.warp-stable": .development,
        "com.mitchellh.ghostty": .development,
        "com.github.githubclient": .development,
        "com.axosoft.gitkraken": .development,
        "com.docker.docker": .development,
        "com.postmanlabs.mac": .development,
        "com.tinyapp.tableplus": .development,

        // Creative
        "com.figma.desktop": .creative,
        "com.bohemiancoding.sketch3": .creative,
        "com.pixelmatorteam.pixelmator.x": .creative,
        "com.pixelmatorteam.pixelmator.pro": .creative,
        "com.apple.photos": .creative,
        "com.apple.finalcut": .creative,
        "com.apple.logic10": .creative,
        "com.apple.garageband10": .creative,
        "com.apple.imovieapp": .creative,
        "com.blackmagic-design.davinciresolve": .creative,
        "org.blenderfoundation.blender": .creative,
        "com.lunarg.aseprite": .creative,
        "com.aseprite.aseprite": .creative,

        // Productivity
        "com.adobe.acrobat.pro": .productivity,
        "com.adobe.reader": .productivity,
        "com.microsoft.word": .productivity,
        "com.microsoft.excel": .productivity,
        "com.microsoft.powerpoint": .productivity,
        "com.microsoft.outlook": .productivity,
        "com.microsoft.onenote.mac": .productivity,
        "com.microsoft.teams2": .productivity,
        "notion.id": .productivity,
        "md.obsidian": .productivity,
        "com.apple.notes": .productivity,
        "com.apple.mail": .productivity,
        "com.apple.ical": .productivity,
        "com.apple.reminders": .productivity,
        "com.apple.preview": .productivity,
        "com.tinyspeck.slackmacgap": .productivity,
        "us.zoom.xos": .productivity,
        "com.culturedcode.thingsmac": .productivity,
        "com.linear": .productivity,
        "com.readdle.smartemail-mac": .productivity,

        // Entertainment
        "com.apple.music": .entertainment,
        "com.apple.tv": .entertainment,
        "com.apple.podcasts": .entertainment,
        "com.spotify.client": .entertainment,
        "com.valvesoftware.steam": .entertainment,
        "com.hnc.discord": .entertainment,
        "com.colliderli.iina": .entertainment,
        "org.videolan.vlc": .entertainment,
        "com.epicgames.epicgameslauncher": .entertainment,
    ]

    public static let defaultPrefixes: [(prefix: String, category: ActivityCategory)] = [
        ("com.apple.dt.", .development),
        ("com.jetbrains.", .development),
        ("com.adobe.", .creative),
        ("com.seriflabs.", .creative),
        ("com.apple.iwork.", .productivity),
        ("com.blizzard.", .entertainment),
        ("com.riotgames.", .entertainment),
    ]

    private let overrides: [String: ActivityCategory]

    public init(overrides: [String: ActivityCategory] = [:]) {
        var lowered: [String: ActivityCategory] = [:]
        for (key, value) in overrides { lowered[key.lowercased()] = value }
        self.overrides = lowered
    }

    public func category(forBundleID bundleID: String?) -> ActivityCategory {
        guard let id = bundleID?.lowercased(), !id.isEmpty else { return .other }
        if let category = overrides[id] { return category }
        if let category = Self.defaultExact[id] { return category }
        for rule in Self.defaultPrefixes where id.hasPrefix(rule.prefix) {
            return rule.category
        }
        return .other
    }
}
