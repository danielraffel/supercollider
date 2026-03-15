import SwiftUI

struct ServerView: View {
    @EnvironmentObject var app: AppState

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

                Button("Check Server Status") {
                    app.evaluate("""
                        "Server running: ".post; Server.internal.serverRunning.postln;
                        "Sample rate: ".post; Server.internal.sampleRate.postln;
                    """)
                }
                .disabled(!app.sclangReady)
            }

            Section("Info") {
                LabeledContent("Version", value: "SC 3.15.0-dev")
                LabeledContent("Plugins", value: "26 modules")
            }
        }
        .listStyle(.insetGrouped)
    }
}
