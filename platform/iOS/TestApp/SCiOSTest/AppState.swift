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
    @Published var postOutput = ""
    @Published var currentFile: String? = nil
    @Published var codeText = "// SuperCollider for iOS\n// Press ⌘+Return to evaluate\n\n{ SinOsc.ar(440, 0, 0.3) }.play;\n"

    private var server: SCiOSServerRef?
    private var statusTimer: Timer?
    private let sclang = SclangEngine()

    private let autosaveKey = "sc_autosave_code"
    private let lastFileKey = "sc_last_file"

    init() {
        // Restore last session
        if let saved = UserDefaults.standard.string(forKey: autosaveKey), !saved.isEmpty {
            codeText = saved
        }
        currentFile = UserDefaults.standard.string(forKey: lastFileKey)
    }

    // MARK: - Server Lifecycle

    func bootServer() -> Bool {
        var config = SCiOSServerConfigDefault()
        config.sampleRate = 48000
        config.numInputChannels = 0  // No mic input by default (avoids permission prompt blocking boot)
        config.numOutputChannels = 2
        config.verbose = true

        var errorBuf = [CChar](repeating: 0, count: 256)
        server = SCiOSServerCreate(&config, &errorBuf, 256)

        guard server != nil else {
            let err = String(cString: errorBuf)
            appendPost("ERROR: Server failed to start: \(err)\n")
            appendPost("This may be an audio session issue. Try rebooting the app.\n")
            return false
        }

        let started = SCiOSServerStart(server)
        if started {
            serverRunning = true
            startStatusUpdates()
            appendPost("Server booted: 48000 Hz, 2 out\n")
        }
        return started
    }

    func stopServer() {
        statusTimer?.invalidate()
        statusTimer = nil
        if let server = server {
            SCiOSServerStop(server)
        }
        serverRunning = false
        appendPost("Server stopped\n")
    }

    // MARK: - sclang Lifecycle

    func initSclang() -> Bool {
        let classLibPath = Bundle.main.path(forResource: "SCClassLibrary", ofType: nil)
        guard classLibPath != nil else {
            appendPost("ERROR: SCClassLibrary not found in bundle\n")
            return false
        }

        // Set post callback
        sclang.postCallback = { [weak self] text in
            DispatchQueue.main.async {
                self?.appendPost(text)
            }
        }

        let ok = sclang.initialize(classLibraryPath: classLibPath)
        if !ok {
            appendPost("ERROR: sclang init failed\n")
            return false
        }

        // Compile class library on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let compiled = self?.sclang.compileLibrary() ?? false
            DispatchQueue.main.async {
                self?.sclangReady = compiled
                if compiled {
                    self?.appendPost("sclang ready\n")
                } else {
                    self?.appendPost("ERROR: class library compilation failed\n")
                }
            }
        }
        return true
    }

    // MARK: - Code Evaluation

    func evaluate(_ code: String) {
        guard sclangReady else {
            appendPost("ERROR: sclang not ready\n")
            return
        }
        let _ = sclang.interpret(code)
    }

    func evaluateSelection() {
        // If text is selected in the editor, evaluate that; otherwise evaluate all
        evaluate(codeText)
    }

    func evaluateCode(_ code: String) {
        // Evaluate a specific piece of code (from selection context menu)
        evaluate(code)
    }

    func stopAll() {
        evaluate("CmdPeriod.run;")
        appendPost("CmdPeriod\n")
    }

    func recompile() {
        sclangReady = false
        appendPost("Recompiling class library...\n")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let ok = SCiOSSclangRecompileLibrary()
            DispatchQueue.main.async {
                self?.sclangReady = ok
                if ok {
                    self?.appendPost("Recompile complete\n")
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
        // Keep bounded
        if postOutput.count > 50000 {
            postOutput = String(postOutput.suffix(40000))
        }
    }

    func clearPost() {
        postOutput = ""
    }

    // MARK: - OSC Send

    func sendOSC(_ data: Data) -> Bool {
        guard let server = server else { return false }
        return data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Bool in
            guard let base = ptr.baseAddress else { return false }
            return SCiOSServerSendOSC(server, base.assumingMemoryBound(to: UInt8.self), Int32(data.count))
        }
    }

    // MARK: - Private

    private func startStatusUpdates() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
    }

    private func updateStatus() {
        guard let server = server else { return }
        sampleRate = SCiOSServerActualSampleRate(server)
        avgCPU = SCiOSServerAvgCPU(server)
        peakCPU = SCiOSServerPeakCPU(server)
        numSynths = Int(SCiOSServerNumSynths(server))
        numUGens = Int(SCiOSServerNumUGens(server))
        serverRunning = SCiOSServerIsRunning(server)
    }

    deinit {
        stopServer()
        sclang.shutdown()
        if let server = server {
            SCiOSServerDestroy(server)
        }
    }
}
