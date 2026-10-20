import Foundation

/// Swift Testing (not XCTest) so tests run with only the Command Line Tools installed,
/// as well as on Linux.
enum TestSupport {
    static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    static func date(day: Int, hour: Int, minute: Int = 0) -> Date {
        utc.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    static func isClose(_ a: Double, _ b: Double, _ accuracy: Double = 0.001) -> Bool {
        abs(a - b) <= accuracy
    }

    /// A fresh temp directory, removed when `body` returns.
    static func withTempDirectory<T>(_ body: (URL) throws -> T) throws -> T {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("oddlytown-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url) }
        return try body(url)
    }
}
