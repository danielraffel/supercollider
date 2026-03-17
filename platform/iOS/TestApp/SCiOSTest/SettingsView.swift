import SwiftUI

/// Settings sheet — replaces the old Server tab.
/// Accessible from gear icon in document browser or transport toolbar.
struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @AppStorage("sc_scroll_to_selection") private var scrollToSelection: Bool = false
    @AppStorage("sc_always_edit_mode") private var alwaysEditMode: Bool = false
    @AppStorage("sc_auto_load_synthdefs") private var autoLoadSynthDefs: Bool = true

    var body: some View {
        NavigationView {
            List {
                Section("Server") {
                    HStack {
                        Circle()
                            .fill(app.serverRunning ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        Text(app.serverRunning ? "Running" : "Stopped")
                        Spacer()
                        if app.serverRunning {
                            Text(String(format: "%.0f Hz", app.sampleRate))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                    }

                    LabeledContent("Avg CPU", value: app.serverRunning ? String(format: "%.1f%%", app.avgCPU) : "--")
                    LabeledContent("Peak CPU", value: app.serverRunning ? String(format: "%.1f%%", app.peakCPU) : "--")
                    LabeledContent("Synths", value: app.serverRunning ? "\(app.numSynths)" : "--")
                    LabeledContent("UGens", value: app.serverRunning ? "\(app.numUGens)" : "--")
                }

                Section("Editor") {
                    Toggle("Always open in Edit mode", isOn: $alwaysEditMode)
                    Toggle("Auto-load SynthDefs on file open", isOn: $autoLoadSynthDefs)
                    Toggle("Scroll to show full selection", isOn: $scrollToSelection)
                }

                Section("Gestures") {
                    gestureRow("Long-press", "Select code block")
                    gestureRow("2-finger tap", "Evaluate")
                    gestureRow("3-finger tap", "Stop all")
                    gestureRow("Hold + drag number", "Value scrub")
                }

                Section("Actions") {
                    Button("Recompile Class Library") {
                        app.recompile()
                    }
                    .disabled(!app.sclangReady)

                    Button("Clear Post Window") {
                        app.clearPost()
                    }

                    Button("Stop All Sound", role: .destructive) {
                        app.stopAll()
                    }
                }

                Section("Info") {
                    LabeledContent("Version", value: "SC 3.15.0-dev")
                    LabeledContent("Plugins", value: "26 modules")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            // Swipe down to dismiss (no X button)
        }
    }

    private func gestureRow(_ gesture: String, _ action: String) -> some View {
        HStack {
            Text(gesture)
                .font(.subheadline)
            Spacer()
            Text(action)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}
