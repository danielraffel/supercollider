import SwiftUI

/// Server status and control panel
struct ServerView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        List {
            Section("Server") {
                HStack {
                    Circle()
                        .fill(app.serverRunning ? Color.green : Color.orange)
                        .frame(width: 12, height: 12)
                    Text(app.serverRunning ? "Running" : "Booting...")
                }

                HStack {
                    Circle()
                        .fill(app.sclangReady ? Color.green : Color.orange)
                        .frame(width: 12, height: 12)
                    Text(app.sclangReady ? "sclang ready" : "sclang compiling...")
                }
            }

            Section("Actions") {
                Button("Play Test Tone") {
                    app.evaluate("{ SinOsc.ar(440, 0, 0.3) }.play;")
                }
                .disabled(!app.sclangReady)

                Button("Stop All Sound") {
                    app.stopAll()
                }
                .foregroundColor(.red)

                Button("Recompile Class Library") {
                    app.recompile()
                }
                .disabled(!app.sclangReady)

                Button("Check Server Status") {
                    app.evaluate("""
                        var s = Server.internal;
                        ("Running: " ++ s.serverRunning).postln;
                        ("SR: " ++ s.sampleRate).postln;
                        ("Synths: " ++ s.numSynths).postln;
                        ("UGens: " ++ s.numUGens).postln;
                    """)
                }
                .disabled(!app.sclangReady)
            }

            Section("Info") {
                LabeledContent("Version", value: "SC 3.15.0-dev")
                LabeledContent("Plugins", value: "26 modules")
                LabeledContent("Platform", value: "iOS arm64")
            }
        }
        .listStyle(.insetGrouped)
    }
}
