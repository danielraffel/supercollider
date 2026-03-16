import Foundation
import Combine

/// Central app state managing scsynth + sclang lifecycle
class AppState: ObservableObject {
    @Published var serverRunning = false
    @Published var sclangReady = false
    @Published var sampleRate: Double = 0
    @Published var avgCPU: Float = 0
    @Published var peakCPU: Float = 0
    @Published var numSynths: Int = 0
    @Published var numUGens: Int = 0
    @Published var isPlaying: Bool = false
    @Published var isRecording: Bool = false
    @Published var postOutput = ""
    @Published var currentFile: String? = nil
    @Published var codeText = "{ SinOsc.ar(440, 0, 0.3) }.play;\n"
    /// Last known text selection (saved before text view loses focus)
    @Published var lastSelection: String = ""

    private var server: SCiOSServerRef?
    private var statusTimer: Timer?
    let sclang = SclangEngine()

    private let autosaveKey = "sc_autosave_code"
    private let lastFileKey = "sc_last_file"

    private static let currentVersion = 2  // Bump to reset autosave after breaking changes

    init() {
        let savedVersion = UserDefaults.standard.integer(forKey: "sc_autosave_version")
        if savedVersion == Self.currentVersion,
           let saved = UserDefaults.standard.string(forKey: autosaveKey), !saved.isEmpty {
            codeText = saved
        }
        // Save current version so future launches restore normally
        UserDefaults.standard.set(Self.currentVersion, forKey: "sc_autosave_version")
        currentFile = UserDefaults.standard.string(forKey: lastFileKey)
    }

    // MARK: - Boot

    func bootSystem() {
        appendPost("=== SuperCollider for iOS ===\n")

        // Step 1: Boot scsynth via C API
        appendPost("Booting audio engine...\n")
        var config = SCiOSServerConfigDefault()
        config.sampleRate = 48000
        config.numInputChannels = 0
        config.numOutputChannels = 2
        config.verbose = true

        var errorBuf = [CChar](repeating: 0, count: 256)
        server = SCiOSServerCreate(&config, &errorBuf, 256)

        guard server != nil else {
            appendPost("ERROR: \(String(cString: errorBuf))\n")
            return
        }

        let started = SCiOSServerStart(server)
        if started {
            serverRunning = true
            startCAPIStatusUpdates()
            appendPost("Audio engine running ✓\n")
            // Default Group 1 is created automatically in World_New on iOS
        } else {
            appendPost("ERROR: Audio engine failed to start\n")
            return
        }

        // Step 2: Init sclang and compile
        appendPost("Initializing sclang...\n")
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

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let compiled = self?.sclang.compileLibrary() ?? false
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.sclangReady = compiled
                if compiled {
                    self.connectSclangToServer()
                } else {
                    self.appendPost("ERROR: class library failed\n")
                }
            }
        }
    }

    private func connectSclangToServer() {
        guard let server = server else { return }
        let worldPtr = SCiOSServerGetWorld(server)
        guard worldPtr != nil else {
            appendPost("ERROR: no World pointer\n")
            return
        }

        SCiOSSclangConnectToServer(worldPtr)

        // Tell sclang the server is running
        let _ = sclang.interpret("""
            var s = Server.internal;
            s.statusWatcher.notified = true;
            s.statusWatcher.updateRunningState(true);
            "Server connected ✓".postln;
        """)

        appendPost("Ready! Select code and tap Evaluate.\n")
    }

    // MARK: - Status Updates

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
        isPlaying = numSynths > 0
    }

    // MARK: - Code Evaluation

    func evaluate(_ code: String) {
        guard sclangReady else {
            appendPost("⚠ sclang not ready\n")
            return
        }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            appendPost("⚠ empty code\n")
            return
        }
        // Log what we're evaluating (first 80 chars)
        let preview = String(trimmed.prefix(80)).replacingOccurrences(of: "\n", with: "↵")
        appendPost("▶ \(preview)\(trimmed.count > 80 ? "..." : "")\n")
        let ok = sclang.interpret(trimmed)
        if !ok {
            appendPost("⚠ interpret returned false\n")
        }
    }

    func evaluateSelection() {
        // Try to snapshot the current selection from the text view
        // (this works even if the text view is about to lose focus)
        if let snapshot = scSnapshotSelection?(), !snapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            evaluate(snapshot)
            lastSelection = ""
            return
        }
        // Fall back to lastSelection (saved on selection change)
        let sel = lastSelection.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sel.isEmpty {
            evaluate(lastSelection)
            lastSelection = ""
        } else {
            // No selection — check if file is safe to evaluate as a whole
            let trimmed = codeText.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasMultipleBlocks = trimmed.components(separatedBy: "\n").filter {
                $0.trimmingCharacters(in: .whitespaces) == "("
            }.count > 1

            if hasMultipleBlocks {
                appendPost("⚠ Multi-block file — select a block first (long-press)\n")
            } else {
                evaluate(codeText)
            }
        }
    }

    func evaluateCode(_ code: String) {
        evaluate(code)
    }

    /// Auto-evaluate all SynthDef blocks in the current code
    /// Called when a file is opened so patterns "just work"
    func autoLoadSynthDefs() {
        guard sclangReady else { return }
        let text = codeText
        let nsText = text as NSString
        let totalLength = nsText.length
        guard totalLength > 0 else { return }

        // Find all ( ... ) blocks that contain SynthDef
        var pos = 0
        var defsFound = 0
        while pos < totalLength {
            let lineRange = nsText.lineRange(for: NSRange(location: pos, length: 0))
            let lineContent = nsText.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)

            if lineContent == "(" {
                // Found a block start — scan forward for matching )
                var depth = 1
                var blockEnd = lineRange.location + lineRange.length
                while blockEnd < totalLength && depth > 0 {
                    let nextLine = nsText.lineRange(for: NSRange(location: blockEnd, length: 0))
                    let nextContent = nsText.substring(with: nextLine).trimmingCharacters(in: .whitespacesAndNewlines)
                    if nextContent == "(" { depth += 1 }
                    else if nextContent == ")" { depth -= 1 }
                    blockEnd = nextLine.location + nextLine.length
                }

                // Check if block contains SynthDef
                let blockRange = NSRange(location: lineRange.location, length: blockEnd - lineRange.location)
                let blockText = nsText.substring(with: blockRange)
                if blockText.contains("SynthDef") && blockText.contains(".add") {
                    let _ = sclang.interpret(blockText)
                    defsFound += 1
                }
            }

            let nextPos = lineRange.location + lineRange.length
            if nextPos <= pos { break }
            pos = nextPos
        }

        if defsFound > 0 {
            appendPost("Auto-loaded \(defsFound) SynthDef block(s)\n")
        }
    }

    func stopAll() {
        if isRecording {
            let _ = sclang.interpret("Server.internal.stopRecording;")
            isRecording = false
            appendPost("⏺ Recording saved\n")
        }
        if sclangReady {
            let _ = sclang.interpret("CmdPeriod.run;")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                let _ = self?.sclang.interpret("Server.internal.sendMsg(\"/g_new\", 1, 0, 0);")
            }
        }
        appendPost("⏹ stopped\n")
    }

    func toggleRecording() {
        guard sclangReady else { return }
        if isRecording {
            let _ = sclang.interpret("Server.internal.stopRecording;")
            isRecording = false
            appendPost("⏺ Recording saved to Documents/\n")
        } else {
            let _ = sclang.interpret("Server.internal.record;")
            isRecording = true
            appendPost("⏺ Recording...\n")
        }
    }

    func recompile() {
        // Stop all sound first
        stopAll()
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

    // MARK: - OSC Send

    func sendOSC(_ data: Data) -> Bool {
        guard let server = server else { return false }
        return data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Bool in
            guard let base = ptr.baseAddress else { return false }
            return SCiOSServerSendOSC(server, base.assumingMemoryBound(to: UInt8.self), Int32(data.count))
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
