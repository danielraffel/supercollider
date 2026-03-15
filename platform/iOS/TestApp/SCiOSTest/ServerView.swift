import SwiftUI

/// Server status and control panel
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
                    if !app.serverRunning {
                        Button("Boot") { let _ = app.bootServer() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    } else {
                        Button("Stop") { app.stopServer() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }

                HStack {
                    Circle()
                        .fill(app.sclangReady ? Color.green : Color.orange)
                        .frame(width: 12, height: 12)
                    Text(app.sclangReady ? "sclang ready" : "sclang loading...")
                }
            }

            if app.serverRunning {
                Section("Status") {
                    LabeledContent("Sample Rate", value: String(format: "%.0f Hz", app.sampleRate))
                    LabeledContent("Avg CPU", value: String(format: "%.1f%%", app.avgCPU))
                    LabeledContent("Peak CPU", value: String(format: "%.1f%%", app.peakCPU))
                    LabeledContent("Synths", value: "\(app.numSynths)")
                    LabeledContent("UGens", value: "\(app.numUGens)")
                }
                .font(.system(.body, design: .monospaced))

                Section("Actions") {
                    Button("Stop All Sound (⌘.)") {
                        app.stopAll()
                    }
                    .foregroundColor(.red)

                    Button("Recompile Class Library (⌘K)") {
                        app.recompile()
                    }
                    .keyboardShortcut("k", modifiers: .command)
                }
            }

            Section("Info") {
                LabeledContent("Version", value: String(cString: SCiOSServerVersion()))
                LabeledContent("Plugins", value: "26 modules")
                LabeledContent("Platform", value: "iOS arm64")
            }
        }
        .navigationTitle("Server")
    }
}
