import SwiftUI

struct ContentView: View {
    @EnvironmentObject var engine: SCEngine
    @State private var frequency: Double = 440
    @State private var isPlaying = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status Dashboard
                GroupBox("Server Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(engine.isRunning ? Color.green : Color.red)
                                .frame(width: 12, height: 12)
                            Text(engine.isRunning ? "Running" : "Stopped")
                        }
                        LabeledContent("Sample Rate", value: String(format: "%.0f Hz", engine.sampleRate))
                        LabeledContent("Avg CPU", value: String(format: "%.1f%%", engine.avgCPU))
                        LabeledContent("Peak CPU", value: String(format: "%.1f%%", engine.peakCPU))
                        LabeledContent("Synths", value: "\(engine.numSynths)")
                        LabeledContent("UGens", value: "\(engine.numUGens)")
                    }
                    .font(.system(.body, design: .monospaced))
                }

                // Sine Wave Control
                GroupBox("Sine Wave") {
                    VStack {
                        Text(String(format: "%.0f Hz", frequency))
                            .font(.title2.monospacedDigit())

                        Slider(value: $frequency, in: 100...2000, step: 1)
                            .onChange(of: frequency) { newValue in
                                if isPlaying {
                                    engine.setNodeControl(1000, "freq", Float(newValue))
                                }
                            }

                        Button(isPlaying ? "Stop" : "Play") {
                            toggleSine()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                // Boot/Stop Controls
                HStack(spacing: 20) {
                    Button("Boot Server") {
                        let _ = engine.boot()
                    }
                    .buttonStyle(.bordered)
                    .disabled(engine.isRunning)

                    Button("Stop Server") {
                        engine.stop()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!engine.isRunning)
                }

                Spacer()

                Text("SuperCollider iOS — scsynth \(String(cString: SCiOSServerVersion()))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("SC iOS Test")
        }
        .onAppear {
            let _ = engine.boot()
        }
    }

    private func toggleSine() {
        if isPlaying {
            engine.freeNode(1000)
        } else {
            engine.playSine(freq: Float(frequency), amp: 0.3, nodeID: 1000)
        }
        isPlaying.toggle()
    }
}
