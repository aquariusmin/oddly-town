import SwiftUI
import AppKit
import OddlyTownCore

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Town window") {
                LabeledContent("Size") {
                    HStack {
                        Slider(value: $model.settings.windowWidth,
                               in: AppSettings.minWidth...AppSettings.maxWidth, step: 20)
                        Text("\(Int(model.settings.windowWidth)) × \(Int(model.settings.windowHeight))")
                            .monospacedDigit().foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .trailing)
                    }
                }
                Picker("Position", selection: $model.settings.corner) {
                    ForEach(cornerChoices, id: \.self) { Text($0.displayName).tag($0) }
                }
                Button("Reset Position") { model.onResetPosition?() }
                Toggle("Show town", isOn: $model.settings.townVisible)
                Toggle("Float above other windows", isOn: $model.settings.floatAboveWindows)
                Toggle("Also show over full-screen apps", isOn: $model.settings.showOverFullScreenApps)
                Toggle("Click-through (clicks pass to apps underneath)", isOn: $model.settings.clickThrough)
                Toggle("Animations", isOn: $model.settings.animationsEnabled)
            }

            Section("Activity") {
                Toggle("Let the apps I use shape the town", isOn: trackingBinding)
                Text("""
                When on, Oddly Town notes which app is in front and sorts it into Development, \
                Creative, Productivity, Entertainment or Other. Only the total time per category \
                is saved, on this Mac. It never reads window contents, websites, keystrokes or the screen, \
                and nothing is sent anywhere.
                """)
                .font(.caption).foregroundStyle(.secondary)
                Button("Reset Activity History…") { model.onResetActivity?() }
            }

            Section("Data") {
                LabeledContent("Stored in") {
                    Text(model.dataDirectory.path).font(.caption).textSelection(.enabled)
                }
                HStack {
                    Button("Show in Finder") { NSWorkspace.shared.open(model.dataDirectory) }
                    Button("Reset Town…") { model.onResetTown?() }
                }
            }

            Section {
                Text("Oddly Town \(OddlyTownVersion.current)\(model.isDeveloper ? " · developer mode" : "")")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 640)
    }

    private var cornerChoices: [ScreenCorner] {
        ScreenCorner.allCases.filter { $0 != .custom || model.settings.corner == .custom }
    }

    /// Turning tracking on goes through the controller so it can ask for consent first.
    private var trackingBinding: Binding<Bool> {
        Binding(
            get: { model.settings.activityTrackingEnabled },
            set: { model.onRequestTracking?($0) }
        )
    }
}
