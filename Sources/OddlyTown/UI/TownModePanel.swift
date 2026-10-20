import SwiftUI
import OddlyTownCore

/// The strip under the big town in Town Mode: progress, what's selected, decorations.
/// Kept to one short row so the town stays the focus.
struct TownModePanel: View {
    static let height: CGFloat = 196

    @ObservedObject var model: AppModel

    private var progress: GrowthProgress { model.status.progress }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            progressColumn.frame(width: 170, alignment: .leading)
            Divider()
            selectionColumn.frame(width: 250, alignment: .leading)
            Divider()
            decorColumn.frame(width: 190, alignment: .leading)
            Divider()
            showColumn.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(width: TownModeWindowController.townSize.width, height: Self.height, alignment: .topLeading)
    }

    private var progressColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Level \(progress.level)").font(.title3.bold())
                if model.status.isDemo {
                    Text("DEMO").font(.caption2.bold())
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.orange.opacity(0.25), in: Capsule())
                }
            }
            ProgressView(value: progress.fractionToNext)
            if let remaining = progress.secondsToNext {
                Text("≈ \(DurationText.short(remaining)) of town time to Level \(progress.level + 1)")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Fully grown for this version.").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button("Back to Ambient") { model.onCloseTownMode?() }
                .keyboardShortcut(.cancelAction)
        }
    }

    private var selectionColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.selection?.title ?? "Look around").font(.headline)
            Text(model.selection?.detail
                 ?? "Click a resident, a building or one of the four decoration spots along the front of town.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let slot = model.selection?.slot {
                decorPicker(slot: slot, label: "Decoration")
            }
        }
    }

    private var decorColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Decoration spots").font(.headline)
            ForEach(0..<DecorLayout.slotCount, id: \.self) { slot in
                decorPicker(slot: slot, label: "Spot \(slot + 1)")
            }
        }
    }

    private var showColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Show").font(.headline)
            let hideable = TownFeature.allCases.filter {
                DecorLayout.hideableFeatures.contains($0) && model.status.unlocked.contains($0)
            }
            if hideable.isEmpty {
                Text("Fences, flowers and lamps from Level 2 can be hidden here.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(hideable, id: \.self) { feature in
                Toggle(feature.displayName, isOn: shownBinding(feature)).font(.callout)
            }
        }
    }

    private func decorPicker(slot: Int, label: String) -> some View {
        Picker(label, selection: slotBinding(slot)) {
            Text("Empty").tag(DecorItem?.none)
            ForEach(DecorItem.allCases, id: \.self) { item in
                let locked = item.minimumLevel > progress.level
                Text(locked ? "\(item.displayName) (Level \(item.minimumLevel))" : item.displayName)
                    .tag(Optional(item))
            }
        }
        .pickerStyle(.menu)
        .font(.callout)
    }

    private func slotBinding(_ slot: Int) -> Binding<DecorItem?> {
        Binding(
            get: { model.decor.item(inSlot: slot) },
            set: { model.onPlaceDecor?(slot, $0) }
        )
    }

    private func shownBinding(_ feature: TownFeature) -> Binding<Bool> {
        Binding(
            get: { !model.decor.hiddenFeatures.contains(feature) },
            set: { model.onSetFeatureHidden?(feature, !$0) }
        )
    }
}
