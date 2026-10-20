import Foundation

public enum OddlyTownVersion {
    public static let current = "0.2.0-alpha"
}

/// Coarse buckets for "what kind of app is in front". Only these buckets are stored —
/// never app names, window titles, URLs or input.
public enum ActivityCategory: String, Codable, CaseIterable, CodingKeyRepresentable, Sendable {
    case development
    case creative
    case productivity
    case entertainment
    case other

    public var displayName: String {
        switch self {
        case .development: return "Development"
        case .creative: return "Creative"
        case .productivity: return "Productivity"
        case .entertainment: return "Entertainment"
        case .other: return "Other"
        }
    }
}
