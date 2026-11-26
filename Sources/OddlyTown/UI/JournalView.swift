import SwiftUI
import OddlyTownCore

/// A few days of the town journal, newest first. Used by Town Status and Town Mode.
struct JournalView: View {
    let days: [JournalDay]
    /// Lines shown per day (the newest ones).
    var linesPerDay = Journal.everydayLimit + 2
    var font: Font = .callout
    var showsDayTitles = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(days, id: \.day) { day in
                VStack(alignment: .leading, spacing: 2) {
                    if showsDayTitles {
                        Text(Self.title(for: day.day)).font(.caption.bold()).foregroundStyle(.secondary)
                    }
                    ForEach(Array(day.entries.suffix(linesPerDay).enumerated()), id: \.offset) { _, entry in
                        Text("· \(entry.text)")
                            .font(font)
                            .fontWeight(entry.isMilestone ? .semibold : .regular)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    /// "Today", "Yesterday", or e.g. "Mon 24 Nov".
    static func title(for day: String, now: Date = Date(), calendar: Calendar = .current) -> String {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
        else { return day }
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        return shortDate.string(from: date)
    }

    private static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return formatter
    }()
}
