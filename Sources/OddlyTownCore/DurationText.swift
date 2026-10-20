import Foundation

public enum DurationText {
    /// "<1m", "45m", "2h 5m".
    public static func short(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 60 else { return "<1m" }
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        return hours > 0 ? "\(hours)h \(minutes % 60)m" : "\(minutes)m"
    }
}
