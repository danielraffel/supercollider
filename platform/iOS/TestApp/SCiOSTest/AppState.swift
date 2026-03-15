import Foundation
import Combine

/// Central app state managing scsynth + sclang lifecycle
/// Architecture:
/// 1. Boot scsynth via C API (SCiOSServerCreate → World_New) — reliable on device
/// 2. Init sclang, compile class library
/// 3. Connect sclang to the already-running server via SCiOSSclangConnectToServer
/// 4. User code evaluated via sclang, which sends OSC to the connected server
class AppState: ObservableObject {
    @Published var serverRunning = false
    @Published var sclangReady = false
    @Published var sampleRate: Double = 0
    @Published var avgCPU: Float = 0
    @Published var peakCPU: Float = 0
    @Published var numSynths: Int = 0
    @Published var numUGens: Int = 0
    @Published var postOutput = ""
    @Published var currentFile: String? = nil
    @Published var codeText = "// SuperCollider for iOS\n// Select code, then tap Evaluate\n\n{ SinOsc.ar(440, 0, 0.3) }.play;\n"

    private var server: SCiOSServerRef?
    private var statusTimer: Timer?
    let sclang = SclangEngine()

    private let autosaveKey = "sc_autosave_code"
    private let lastFileKey = "sc_last_file"

    init() {
        if let saved = UserDefaults.standard.string(forKey: autosaveKey), !saved.isEmpty {
            codeText = saved
        }
        currentFile = UserDefaults.standard.string(forKey: lastFileKey)
    }

    // MARK: - Boot

    func bootSystem() {
        appendPost("=== SuperCollider for iOS ===\n")

        // Step 1: Boot scsynth via C API
        appendPost("Step 1: Booting audio engine...\n")
        var config = SCiOSServerConfigDefault()
        config.sampleRate = 48000
        config.numInputChannels = 0  // No mic — avoids permission prompt
        config.numOutputChannels = 2
        config.verbose = true

        var errorBuf = [CChar](repeating: 0, count: 256)
        server = SCiOSServerCreate(&config, &errorBuf, 256)

        guard server != nil else {
            let err = String(cString: errorBuf)
            appendPost("ERROR: Audio engine failed: \(err)\n")
            return
        }

        let started = SCiOSServerStart(server)
        if started {
            serverRunning = true
            startCAPIStatusUpdates()
            appendPost("Audio engine running ✓\n")
        } else {
            appendPost("ERROR: Audio engine failed to start\n")
            return
        }

        // Step 2: Init sclang
        appendPost("Step 2: Initializing sclang...\n")
        let classLibPath = Bundle.main.path(forResource: "SCClassLibrary", ofType: nil)
        guard classLibPath != nil else {
            appendPost("ERROR: SCClassLibrary not in bundle\n")
            return
        }

        sclang.postCallback = { [weak self] text in
            DispatchQueue.main.async {
                self?.appendPost(text)
            }
        }

        let ok = sclang.initialize(classLibraryPath: classLibPath)
        if !ok {
            appendPost("ERROR: sclang init failed\n")
            return
        }

        // Step 3: Compile class library
        appendPost("Step 3: Compiling class library...\n")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let compiled = self?.sclang.compileLibrary() ?? false
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.sclangReady = compiled
                if compiled {
                    // Step 4: Connect sclang to the running server
                    self.connectSclangToServer()
                } else {
                    self.appendPost("ERROR: class library failed\n")
                }
            }
        }
    }

    /// Connect sclang's gInternalSynthServer.mWorld to the C API's World
    private func connectSclangToServer() {
        guard let server = server else { return }
        let worldPtr = SCiOSServerGetWorld(server)
        guard worldPtr != nil else {
            appendPost("ERROR: no World pointer\n")
            return
        }

        appendPost("Step 4: Connecting sclang to server...\n")
        SCiOSSclangConnectToServer(worldPtr)

        // Tell sclang the server is running via updateRunningState
        let _ = sclang.interpret("""
            var s = Server.internal;
            s.statusWatcher.notified = true;
            s.statusWatcher.updateRunningState(true);
            ("Server.internal.serverRunning = " ++ s.serverRunning).postln;
            "sclang connected to server ✓".postln;
        """)

        // Run a self-test after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.runSelfTest()
        }
    }

    /// Automated self-test: play a sustained tone to verify audio pipeline
    private func runSelfTest() {
        appendPost("Running audio self-test...\n")

        // Use the C API to send a direct OSC /s_new for the default synth
        // This bypasses sclang entirely to test the audio pipeline
        let sineDef = SynthDefBuilder.simpleSine(name: "sc_test_tone")
        let _ = sendOSC(OSCMessage.dRecv(sineDef))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            // Create a test synth via C API OSC
            let msg = OSCMessage.sNew("sc_test_tone", nodeID: 9999, addAction: 1, targetID: 0,
                                       args: ["freq", Float(880.0), "amp", Float(0.2)])
            let _ = self.sendOSC(msg)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let synths = self.numSynths
                let ugens = self.numUGens
                if synths > 0 {
                    self.appendPost("C API audio test PASSED ✓ (synths: \(synths), ugens: \(ugens))\n")
                    // Free the test synth after 1 second
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        let _ = self.sendOSC(OSCMessage.nFree(9999))
                        self.appendPost("Test tone freed.\n")
                    }
                } else {
                    self.appendPost("C API audio test: synths=\(synths) ugens=\(ugens)\n")
                    self.appendPost("⚠ Audio may not be working\n")
                }

                // Now test sclang evaluation path
                self.appendPost("Testing sclang path...\n")
                let ok = self.sclang.interpret("""
                    "sclang interpret works ✓".postln;
                    // Try to create a synth via sclang
                    x = { SinOsc.ar(660, 0, 0.2) }.play;
                    "sclang synth created".postln;
                """)
                if !ok {
                    self.appendPost("⚠ sclang interpret failed\n")
                }

                // Check synth count after sclang creates synth
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let s2 = self.numSynths
                    self.appendPost("After sclang play: synths=\(s2)\n")
                    if s2 > 0 {
                        self.appendPost("🎉 AUDIO WORKS via sclang! 🎉\n")
                        // Free the test synths
                        let _ = self.sclang.interpret("x.free;")
                        let _ = self.sendOSC(OSCMessage.nFree(9999))
                    }
                    self.appendPost("Ready! Select code and tap Evaluate.\n")
                }
            }
        }
    }

    // MARK: - OSC Send (for C API direct sends)

    func sendOSC(_ data: Data) -> Bool {
        guard let server = server else { return false }
        return data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Bool in
            guard let base = ptr.baseAddress else { return false }
            return SCiOSServerSendOSC(server, base.assumingMemoryBound(to: UInt8.self), Int32(data.count))
        }
    }

    // MARK: - C API Status Updates

    private func startCAPIStatusUpdates() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.updateCAPIStatus()
        }
    }

    private func updateCAPIStatus() {
        guard let server = server else { return }
        sampleRate = SCiOSServerActualSampleRate(server)
        avgCPU = SCiOSServerAvgCPU(server)
        peakCPU = SCiOSServerPeakCPU(server)
        numSynths = Int(SCiOSServerNumSynths(server))
        numUGens = Int(SCiOSServerNumUGens(server))
        serverRunning = SCiOSServerIsRunning(server)
    }

    // MARK: - Code Evaluation

    func evaluate(_ code: String) {
        guard sclangReady else {
            appendPost("⚠ sclang not ready\n")
            return
        }
        guard serverRunning else {
            appendPost("⚠ server not running\n")
            return
        }
        let ok = sclang.interpret(code)
        if !ok {
            appendPost("⚠ interpret failed\n")
        }
    }

    func evaluateSelection() {
        // Play button evaluates ALL text — this may cause errors with multi-block files.
        // For multi-block files, user should select specific blocks and use Evaluate from menu.
        evaluate(codeText)
    }

    func evaluateCode(_ code: String) {
        evaluate(code)
    }

    func stopAll() {
        guard sclangReady else { return }
        let _ = sclang.interpret("CmdPeriod.run;")
        appendPost("⏹ stopped\n")
    }

    func recompile() {
        sclangReady = false
        appendPost("Recompiling...\n")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let ok = SCiOSSclangRecompileLibrary()
            DispatchQueue.main.async {
                self?.sclangReady = ok
                if ok {
                    self?.connectSclangToServer()
                }
            }
        }
    }

    // MARK: - Autosave

    func autosave() {
        UserDefaults.standard.set(codeText, forKey: autosaveKey)
        UserDefaults.standard.set(currentFile, forKey: lastFileKey)
    }

    // MARK: - Post Window

    func appendPost(_ text: String) {
        postOutput += text
        if postOutput.count > 50000 {
            postOutput = String(postOutput.suffix(40000))
        }
        // Also write to file for debugging
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logFile = docs.appendingPathComponent("sc_post_log.txt")
        try? postOutput.write(to: logFile, atomically: true, encoding: .utf8)
    }

    func clearPost() {
        postOutput = ""
    }

    deinit {
        statusTimer?.invalidate()
        if let server = server {
            SCiOSServerStop(server)
            SCiOSServerDestroy(server)
        }
        sclang.shutdown()
    }
}
