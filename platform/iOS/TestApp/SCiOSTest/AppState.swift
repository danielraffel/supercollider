import Foundation
import Combine

/// Central app state managing scsynth + sclang lifecycle
/// Architecture: sclang boots the internal server via World_New.
/// We do NOT use the C API (SCiOSServerCreate) because that would
/// create a second server competing for the audio unit.
class AppState: ObservableObject {
    @Published var serverRunning = false
    @Published var sclangReady = false
    @Published var sampleRate: Double = 48000
    @Published var avgCPU: Float = 0
    @Published var peakCPU: Float = 0
    @Published var numSynths: Int = 0
    @Published var numUGens: Int = 0
    @Published var postOutput = ""
    @Published var currentFile: String? = nil
    @Published var codeText = "// SuperCollider for iOS\n// Select code, then tap Evaluate\n\n{ SinOsc.ar(440, 0, 0.3) }.play;\n"

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
        appendPost("Initializing sclang...\n")

        let classLibPath = Bundle.main.path(forResource: "SCClassLibrary", ofType: nil)
        guard classLibPath != nil else {
            appendPost("ERROR: SCClassLibrary not in app bundle\n")
            return
        }

        sclang.postCallback = { [weak self] text in
            DispatchQueue.main.async {
                self?.appendPost(text)
                // Parse server status from sclang output
                self?.parseServerStatus(text)
            }
        }

        let ok = sclang.initialize(classLibraryPath: classLibPath)
        if !ok {
            appendPost("ERROR: sclang init failed\n")
            return
        }

        // Compile class library on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let compiled = self?.sclang.compileLibrary() ?? false
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.sclangReady = compiled
                if compiled {
                    // Boot server through sclang (this is the ONLY World_New call)
                    self.bootServerViaSclang()
                } else {
                    self.appendPost("ERROR: class library compilation failed\n")
                }
            }
        }
    }

    private func bootServerViaSclang() {
        appendPost("Booting server...\n")
        let _ = sclang.interpret("""
            s = Server.internal;
            s.options.numOutputBusChannels = 2;
            s.options.numInputBusChannels = 0;
            s.options.memSize = 8192;
            s.options.blockSize = 64;
            s.options.sampleRate = 48000;
            s.waitForBoot({
                "*** SERVER READY ***".postln;
                ("Server: " ++ s.sampleRate ++ " Hz, " ++ s.options.numOutputBusChannels ++ " out").postln;
            }, onFailure: {
                "*** SERVER BOOT FAILED ***".postln;
            });
        """)

        // Start polling for status
        startStatusPolling()
    }

    private func startStatusPolling() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.sclangReady else { return }

            // Check post output for server ready marker
            if self.postOutput.contains("*** SERVER READY ***") && !self.serverRunning {
                self.serverRunning = true
            }

            // Query synth count (result appears in post output)
            if self.serverRunning {
                let _ = self.sclang.interpret("""
                    var s = Server.internal;
                    if(s.serverRunning, {
                        thisProcess.interpreter.postResult = false;
                    });
                """)
            }
        }
    }

    /// Parse server status from sclang post output
    private func parseServerStatus(_ text: String) {
        if text.contains("*** SERVER READY ***") {
            serverRunning = true
        }
        if text.contains("*** SERVER BOOT FAILED ***") {
            appendPost("Try: Go to Server tab and check status\n")
        }
    }

    // MARK: - Code Evaluation

    func evaluate(_ code: String) {
        guard sclangReady else {
            appendPost("⚠ Wait for sclang to compile...\n")
            return
        }
        if !serverRunning {
            appendPost("⚠ Server still booting, trying anyway...\n")
        }
        appendPost("▶ evaluating...\n")
        let ok = sclang.interpret(code)
        if !ok {
            appendPost("⚠ evaluation failed\n")
        }
    }

    func evaluateSelection() {
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
        serverRunning = false
        appendPost("Recompiling...\n")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let ok = SCiOSSclangRecompileLibrary()
            DispatchQueue.main.async {
                self?.sclangReady = ok
                if ok {
                    self?.bootServerViaSclang()
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
    }

    func clearPost() {
        postOutput = ""
    }

    deinit {
        statusTimer?.invalidate()
        sclang.shutdown()
    }
}
