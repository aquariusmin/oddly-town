import SwiftUI
import OddlyTownCore

struct StatusView: View {
    @ObservedObject var model: AppModel

    private var status: TownStatus { model.status }
    private var progress: GrowthProgress { status.progress }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Level \(progress.level)").font(.title2.bold())
                Text("of \(progress.maxLevel)").foregroundStyle(.secondary)
                Spacer()
                if status.isDemo {
                    Text("DEMO").font(.caption.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.orange.opacity(0.25), in: Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: progress.fractionToNext)
                if let remaining = progress.secondsToNext {
                    Text("About \(DurationText.short(remaining)) of town time until Level \(progress.level + 1)")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Text("Fully grown for this version.").font(.callout).foregroundStyle(.secondary)
                }
                if let today = status.remainingToday, !status.isDemo {
                    Text(today > 0
                         ? "Growth left today: \(DurationText.short(today))"
                         : "The town is resting until tomorrow — no need to stay on.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Divider()

            Text("In town").font(.headline)
            let unlocked = TownFeature.allCases.filter { status.features.contains($0) }
            if unlocked.isEmpty {
                Text("A cottage, two trees and one resident. More will appear with time.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Text(unlocked.map(\.displayName).joined(separator: " · ")).font(.callout)
            }

            Divider()

            Text("Activity").font(.headline)
            if model.settings.activityTrackingEnabled {
                Text("Estimated time each kind of app was in front. Not a measure of focus or productivity.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(ActivityCategory.allCases, id: \.self) { category in
                    HStack {
                        Text(category.displayName)
                        Spacer()
                        Text(DurationText.short(status.activitySeconds[category] ?? 0))
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
                ForEach(hints, id: \.self) { hint in
                    Label(hint, systemImage: "sparkle").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("Activity tracking is off. The town still grows with time. Turn it on in Settings to let the kinds of apps you use shape the town.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 340)
    }

    private var hints: [String] {
        model.rules.activityUnlocks.compactMap { unlock in
            guard !status.features.contains(unlock.feature) else { return nil }
            let have = status.activitySeconds[unlock.category] ?? 0
            let need = max(0, unlock.requiredSeconds - have)
            var hint = "\(unlock.category.displayName) apps → \(unlock.feature.displayName)"
            if need > 0 { hint += " (\(DurationText.short(need)) more)" }
            if progress.level < unlock.minimumLevel { hint += ", from Level \(unlock.minimumLevel)" }
            return hint
        }
    }
}
