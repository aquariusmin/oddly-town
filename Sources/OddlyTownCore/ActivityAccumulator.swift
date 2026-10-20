import Foundation

public struct ActivityCredit: Equatable, Sendable {
    public let category: ActivityCategory
    public let seconds: TimeInterval
}

/// Turns "category X became frontmost at time T" events into estimated seconds per category.
///
/// Each credited span is clamped to `maxCreditPerSpan`, so a missed checkpoint
/// (sleep, a stalled run loop) can never inflate totals by hours. Spans the caller
/// marks as idle earn nothing. Totals are estimates of frontmost time, not focus time.
public struct ActivityAccumulator: Sendable {
    public var maxCreditPerSpan: TimeInterval
    public private(set) var current: ActivityCategory?
    public private(set) var since: Date?

    public init(maxCreditPerSpan: TimeInterval = 180) {
        self.maxCreditPerSpan = maxCreditPerSpan
    }

    /// The frontmost app changed. Credits the previous category and starts a new span.
    public mutating func switchTo(_ category: ActivityCategory?, at date: Date, isIdle: Bool = false) -> ActivityCredit? {
        let credit = checkpoint(at: date, isIdle: isIdle)
        current = category
        since = category == nil ? nil : date
        return credit
    }

    /// Periodic flush: credits the running span up to `date` and restarts it.
    public mutating func checkpoint(at date: Date, isIdle: Bool) -> ActivityCredit? {
        guard let category = current, let start = since else { return nil }
        since = date
        guard !isIdle else { return nil }
        let elapsed = min(max(0, date.timeIntervalSince(start)), maxCreditPerSpan)
        guard elapsed > 0 else { return nil }
        return ActivityCredit(category: category, seconds: elapsed)
    }

    /// Stops measuring (sleep, tracking disabled). Credits what was running.
    public mutating func suspend(at date: Date) -> ActivityCredit? {
        let credit = checkpoint(at: date, isIdle: false)
        since = nil
        return credit
    }

    /// Resumes measuring the last known category from `date`.
    public mutating func resume(at date: Date) {
        if current != nil { since = date }
    }
}
