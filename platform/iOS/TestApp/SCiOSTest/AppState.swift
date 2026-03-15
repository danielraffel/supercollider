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

            // Create default group (Group 1) — required for /s_new to work
            // /g_new groupID=1 addAction=0 targetID=0 (add to head of root)
            let _ = sendOSC(OSCMessage.build("/g_new", [Int32(1), Int32(0), Int32(0)]))
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

    /// Quick self-test: verify audio works
    private func runSelfTest() {
        appendPost("Self-test: playing test tone...\n")

        // Test via sclang — simple one-liner that won't cause parse errors
        let _ = sclang.interpret("x = { SinOsc.ar(880, 0, 0.2) }.play;")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            let synths = self.numSynths
            if synths > 0 {
                self.appendPost("✓ Audio works! (synths: \(synths))\n")
            } else {
                self.appendPost("Self-test: synths=\(synths) — check Post for errors\n")
            }

            // Free test tone after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let _ = self.sclang.interpret("x.free;")
            }
            self.appendPost("Ready! Select code and tap Evaluate.\n")
        }
    }

    // MARK: - OSC Send (C API direct)

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
        // Free all synths via sclang CmdPeriod
        if sclangReady {
            let _ = sclang.interpret("CmdPeriod.run;")
        }
        // Also free all nodes in default group via C API OSC
        // /g_freeAll groupID=1 (free all children of default group)
        let _ = sendOSC(OSCMessage.build("/g_freeAll", [Int32(1)]))
        // Recreate default group in case it was freed
        let _ = sendOSC(OSCMessage.build("/clearSched", []))
        let _ = sendOSC(OSCMessage.build("/g_new", [Int32(1), Int32(0), Int32(0)]))
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
