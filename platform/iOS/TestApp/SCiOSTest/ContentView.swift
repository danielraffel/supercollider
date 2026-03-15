import SwiftUI

struct ContentView: View {
    @EnvironmentObject var engine: SCEngine
    @State private var frequency: Double = 440
    @State private var isPlaying = false
    @State private var showSclangTest = false

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

                // Stress Test
                GroupBox("Stress Test") {
                    HStack {
                        Button("64 Synths") { engine.stressTest(count: 64) }
                            .buttonStyle(.bordered)
                        Button("Free All") { engine.freeStressTest(count: 64) }
                            .buttonStyle(.bordered)
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

                    Button("sclang Test") {
                        showSclangTest = true
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Text("SuperCollider iOS — scsynth \(String(cString: SCiOSServerVersion()))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("SC iOS Test")
            .sheet(isPresented: $showSclangTest) {
                SclangTestView()
            }
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

// MARK: - sclang Feasibility Test View

struct SclangTestView: View {
    @StateObject private var sclang = SclangEngine()
    @State private var codeInput = "1 + 1"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                GroupBox("sclang Status") {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Initialized", value: sclang.isInitialized ? "Yes" : "No")
                        LabeledContent("Library Compiled", value: sclang.isLibraryCompiled ? "Yes" : "No")
                        if sclang.compileTimeMs > 0 {
                            LabeledContent("Compile Time", value: String(format: "%.0f ms", sclang.compileTimeMs))
                            LabeledContent("Memory Delta", value: String(format: "%.1f MB", sclang.memoryUsageMB))
                        }
                    }
                    .font(.system(.body, design: .monospaced))
                }

                HStack(spacing: 12) {
                    Button("Init sclang") {
                        let classLibPath = Bundle.main.path(forResource: "SCClassLibrary", ofType: nil)
                        let _ = sclang.initialize(classLibraryPath: classLibPath)
                    }
                    .buttonStyle(.bordered)
                    .disabled(sclang.isInitialized)

                    Button("Compile Library") {
                        DispatchQueue.global(qos: .userInitiated).async {
                            let _ = sclang.compileLibrary()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!sclang.isInitialized || sclang.isLibraryCompiled)

                    Button("Shutdown") {
                        sclang.shutdown()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!sclang.isInitialized)
                }

                if sclang.isLibraryCompiled {
                    HStack {
                        TextField("SC code", text: $codeInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Button("Run") {
                            let _ = sclang.interpret(codeInput)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                GroupBox("Output") {
                    ScrollView {
                        Text(sclang.postOutput.isEmpty ? "(no output)" : sclang.postOutput)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .padding()
            .navigationTitle("sclang Feasibility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}
