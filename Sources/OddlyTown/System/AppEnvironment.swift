import Foundation

/// Launch-time configuration.
///
/// Developer mode (`ODDLY_DEV=1`, `--dev`, or `defaults write <bundle id> OTDeveloperMode -bool YES`)
/// shows the Developer menu, uses a separate data folder so real progress is never touched,
/// ticks every 5 s and speeds time up (`ODDLY_TIME_SCALE`, default 60×).
struct AppEnvironment {
    let isDeveloper: Bool
    let timeScale: Double
    let tickInterval: TimeInterval
    let dataDirectory: URL

    static func current() -> AppEnvironment {
        let env = ProcessInfo.processInfo.environment
        let isDeveloper = env["ODDLY_DEV"] == "1"
            || CommandLine.arguments.contains("--dev")
            || UserDefaults.standard.bool(forKey: "OTDeveloperMode")
        let scale = isDeveloper ? max(1, Double(env["ODDLY_TIME_SCALE"] ?? "") ?? 60) : 1
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = isDeveloper ? "OddlyTown-Dev" : "OddlyTown"
        return AppEnvironment(
            isDeveloper: isDeveloper,
            timeScale: scale,
            tickInterval: isDeveloper ? 5 : 60,
            dataDirectory: base.appendingPathComponent(folder, isDirectory: true)
        )
    }
}
