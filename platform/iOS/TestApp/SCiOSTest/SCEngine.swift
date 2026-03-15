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
        }

        return started
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
