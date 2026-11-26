import SwiftUI
import AppKit
import OddlyTownCore

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Open at login", isOn: openAtLoginBinding)
                    .disabled(model.loginItem == .unavailable)
                Text(loginItemNote)
                    .font(.caption).foregroundStyle(.secondary)
                if model.loginItem == .needsApproval {
                    Button("Open Login Items Settings…") { model.onOpenLoginItemsSettings?() }
                }
            }

            Section("Town window") {
                LabeledContent("Size") {
                    HStack {
                        // Whole-number steps (2×–6×) keep the pixel art sharp.
                        Slider(value: $model.settings.windowWidth,
                               in: AppSettings.minWidth...AppSettings.maxWidth, step: AppSettings.artWidth)
                        Text("\(model.settings.pixelScale)× · \(Int(model.settings.windowWidth)) × \(Int(model.settings.windowHeight))")
                            .monospacedDigit().foregroundStyle(.secondary)
                            .frame(width: 120, alignment: .trailing)
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
                if model.reducesMotion {
                    Text("Reduce Motion is on in System Settings, so clouds, trees, smoke and fireflies hold still. Residents still go about their day.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Double-click the town, or use the menu bar, to open Town Mode for a closer look and decorating.")
                    .font(.caption).foregroundStyle(.secondary)
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
        .frame(width: 460, height: 720)
    }

    private var cornerChoices: [ScreenCorner] {
        ScreenCorner.allCases.filter { $0 != .custom || model.settings.corner == .custom }
    }

    private var openAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.loginItem == .on || model.loginItem == .needsApproval },
            set: { model.onSetOpenAtLogin?($0) }
        )
    }

    private var loginItemNote: String {
        switch model.loginItem {
        case .on: return "The town starts with your Mac, so it keeps growing without you having to open it."
        case .off: return "Start Oddly Town automatically when you log in, so the town keeps growing without you having to open it."
        case .needsApproval: return "Waiting for your OK in System Settings → General → Login Items."
        case .unavailable: return "Available when running Oddly Town.app (not swift run)."
        }
    }

    /// Turning tracking on goes through the controller so it can ask for consent first.
    private var trackingBinding: Binding<Bool> {
        Binding(
            get: { model.settings.activityTrackingEnabled },
            set: { model.onRequestTracking?($0) }
        )
    }
}
