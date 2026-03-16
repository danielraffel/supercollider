import SwiftUI

struct ServerView: View {
    @EnvironmentObject var app: AppState
    @AppStorage("sc_scroll_to_selection") private var scrollToSelection: Bool = false

    var body: some View {
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

                HStack {
                    Circle()
                        .fill(app.sclangReady ? Color.green : Color.orange)
                        .frame(width: 12, height: 12)
                    Text(app.sclangReady ? "sclang ready" : "sclang compiling...")
                }
            }

            Section("Status") {
                LabeledContent("Avg CPU", value: app.serverRunning ? String(format: "%.1f%%", app.avgCPU) : "—")
                LabeledContent("Peak CPU", value: app.serverRunning ? String(format: "%.1f%%", app.peakCPU) : "—")
                LabeledContent("Synths", value: app.serverRunning ? "\(app.numSynths)" : "—")
                LabeledContent("UGens", value: app.serverRunning ? "\(app.numUGens)" : "—")
            }
            .font(.system(.body, design: .monospaced))

            Section("Actions") {
                Button("Play Test Tone") {
                    app.evaluate("{ SinOsc.ar(440, 0, 0.3) }.play;")
                }
                .disabled(!app.sclangReady || !app.serverRunning)

                Button("Stop All Sound") { app.stopAll() }
                    .foregroundColor(.red)

                Button("Recompile Class Library") { app.recompile() }
                    .disabled(!app.sclangReady)
            }

            Section("Gestures") {
                VStack(alignment: .leading, spacing: 8) {
                    gestureRow("Long-press", "Select code block (( ) aware)")
                    gestureRow("2-finger tap", "▶ Play selected code (or all)")
                    gestureRow("3-finger tap", "■ Stop all sound")
                    gestureRow("Play ▶", "Evaluate selection or whole file")
                    gestureRow("Stop ■", "Stop all sound (CmdPeriod)")
                }
                .font(.caption)
            }

            Section("Editor Settings") {
                Toggle("Scroll to show full selection", isOn: $scrollToSelection)
            }

            Section("Info") {
                LabeledContent("Version", value: "SC 3.15.0-dev")
                LabeledContent("Plugins", value: "26 modules")
            }
        }
        .listStyle(.insetGrouped)
    }

    private func gestureRow(_ gesture: String, _ action: String) -> some View {
        HStack {
            Text(gesture)
                .fontWeight(.medium)
                .frame(width: 140, alignment: .leading)
            Text(action)
                .foregroundColor(.secondary)
        }
    }
}
