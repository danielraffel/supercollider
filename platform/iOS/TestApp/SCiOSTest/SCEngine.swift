import Foundation
import Combine

/// Swift wrapper around the SuperCollider iOS C API
class SCEngine: ObservableObject {
    @Published var isRunning = false
    @Published var sampleRate: Double = 0
    @Published var avgCPU: Float = 0
    @Published var peakCPU: Float = 0
    @Published var numSynths: Int = 0
    @Published var numUGens: Int = 0

    private var server: SCiOSServerRef?
    private var statusTimer: Timer?

    init() {}

    deinit {
        stop()
        destroy()
    }

    func boot() -> Bool {
        var config = SCiOSServerConfigDefault()
        config.sampleRate = 48000
        config.numInputChannels = 1
        config.numOutputChannels = 2
        config.verbose = true

        var errorBuf = [CChar](repeating: 0, count: 256)
        server = SCiOSServerCreate(&config, &errorBuf, 256)

        guard server != nil else {
            let error = String(cString: errorBuf)
            print("SC: failed to create server: \(error)")
            return false
        }

        let started = SCiOSServerStart(server)
        if started {
            isRunning = true
            startStatusUpdates()
            loadBuiltinSynthDefs()
        }

        return started
    }

    /// Load built-in SynthDefs that don't require sclang compilation
    private func loadBuiltinSynthDefs() {
        let sineDef = SynthDefBuilder.simpleSine(name: "sc_sine")
        let _ = sendOSC(OSCMessage.dRecv(sineDef))
        print("SC: loaded built-in SynthDef 'sc_sine'")
    }

    func stop() {
        statusTimer?.invalidate()
        statusTimer = nil

        if let server = server {
            SCiOSServerStop(server)
        }
        isRunning = false
    }

    func destroy() {
        stop()
        if let server = server {
            SCiOSServerDestroy(server)
            self.server = nil
        }
    }

    func sendOSC(_ data: Data) -> Bool {
        guard let server = server else { return false }
        return data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Bool in
            guard let base = ptr.baseAddress else { return false }
            return SCiOSServerSendOSC(server, base.assumingMemoryBound(to: UInt8.self), Int32(data.count))
        }
    }

    private func startStatusUpdates() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
    }

    // MARK: - Synth Control

    /// Create a default sine wave synth using only built-in UGens (no SynthDef needed)
    /// Sends a /d_recv with an inline SynthDef binary, then /s_new
    @discardableResult
    func playSine(freq: Float = 440, amp: Float = 0.3, nodeID: Int32 = 1000) -> Bool {
        let msg = OSCMessage.sNew("sc_sine", nodeID: nodeID, addAction: 1, targetID: 0,
                                   args: ["freq", freq, "amp", amp])
        return sendOSC(msg)
    }

    func setNodeControl(_ nodeID: Int32, _ control: String, _ value: Float) -> Bool {
        return sendOSC(OSCMessage.nSet(nodeID, control, value))
    }

    func freeNode(_ nodeID: Int32) -> Bool {
        return sendOSC(OSCMessage.nFree(nodeID))
    }

    func sendStatus() -> Bool {
        return sendOSC(OSCMessage.status)
    }

    /// Create multiple simultaneous synths for stress testing
    func stressTest(count: Int = 64) {
        for i in 0..<count {
            let freq = Float(200 + i * 20)
            let amp = Float(0.3) / Float(count)
            let nodeID = Int32(2000 + i)
            let msg = OSCMessage.sNew("sc_sine", nodeID: nodeID, addAction: 1, targetID: 0,
                                       args: ["freq", freq, "amp", amp])
            let _ = sendOSC(msg)
        }
    }

    /// Free all stress test synths
    func freeStressTest(count: Int = 64) {
        for i in 0..<count {
            let _ = freeNode(Int32(2000 + i))
        }
    }

    private func updateStatus() {
        guard let server = server else { return }
        DispatchQueue.main.async { [weak self] in
            self?.sampleRate = SCiOSServerActualSampleRate(server)
            self?.avgCPU = SCiOSServerAvgCPU(server)
            self?.peakCPU = SCiOSServerPeakCPU(server)
            self?.numSynths = Int(SCiOSServerNumSynths(server))
            self?.numUGens = Int(SCiOSServerNumUGens(server))
            self?.isRunning = SCiOSServerIsRunning(server)
        }
    }
}
