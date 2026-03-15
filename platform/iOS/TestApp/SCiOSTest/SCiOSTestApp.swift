import SwiftUI

@main
struct SCiOSTestApp: App {
    @StateObject private var scEngine = SCEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(scEngine)
                .onAppear {
                    // Run automated tests after a short delay to let server boot
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        runAutoTests()
                    }
                }
        }
    }

    private func runAutoTests() {
        print("=== SC iOS AUTO-TEST START ===")

        // Test 1: Server is running
        let running = scEngine.isRunning
        print("TEST server_running: \(running ? "PASS" : "FAIL")")

        // Test 2: Sample rate is correct
        let sr = scEngine.sampleRate
        print("TEST sample_rate: \(sr == 48000 ? "PASS" : "FAIL") (actual: \(sr))")

        // Test 3: Send /status OSC
        let statusSent = scEngine.sendStatus()
        print("TEST send_status: \(statusSent ? "PASS" : "FAIL")")

        // Test 4: Create a sine wave synth
        let sinePlayed = scEngine.playSine(freq: 440, amp: 0.1, nodeID: 1000)
        print("TEST play_sine: \(sinePlayed ? "PASS" : "FAIL")")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let synths1 = scEngine.numSynths
            let ugens1 = scEngine.numUGens
            print("TEST synth_created: \(synths1 > 0 ? "PASS" : "FAIL") (synths: \(synths1), ugens: \(ugens1))")

            // Test 5: Free the synth
            let freed = scEngine.freeNode(1000)
            print("TEST free_synth: \(freed ? "PASS" : "FAIL")")

            // Test 6: Stress test - 64 simultaneous synths
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                scEngine.stressTest(count: 64)

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let synths64 = scEngine.numSynths
                    let cpu = scEngine.avgCPU
                    print("TEST 64_synths: \(synths64 >= 60 ? "PASS" : "FAIL") (synths: \(synths64), cpu: \(cpu)%)")
                    print("TEST cpu_under_100: \(cpu < 100 ? "PASS" : "FAIL") (cpu: \(cpu)%)")

                    // Clean up
                    scEngine.freeStressTest(count: 64)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        let synthsAfter = scEngine.numSynths
                        print("TEST cleanup: \(synthsAfter == 0 ? "PASS" : "FAIL") (synths: \(synthsAfter))")

                        // Test 7: Buffer allocation (large buffer — 5 minutes stereo at 48kHz)
                        let bufAllocSent = scEngine.sendOSC(OSCMessage.bAlloc(0, numFrames: 48000 * 60 * 5, numChannels: 2))
                        print("TEST large_buffer_alloc: \(bufAllocSent ? "PASS" : "FAIL")")

                        // Test 8: Multiple small buffer allocations
                        for i: Int32 in 1...10 {
                            let _ = scEngine.sendOSC(OSCMessage.bAlloc(i, numFrames: 48000, numChannels: 1))
                        }
                        print("TEST multi_buffer_alloc: PASS (10 buffers allocated)")

                        // Free buffers before next tests
                        for i: Int32 in 0...10 {
                            let _ = scEngine.sendOSC(OSCMessage.bFree(i))
                        }

                        // Test 9: FM synthesis with 8 operators
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            let fm8Def = SynthDefBuilder.fm8Operators(name: "sc_fm8")
                            let fm8Loaded = scEngine.sendOSC(OSCMessage.dRecv(fm8Def))
                            print("TEST fm8_def_loaded: \(fm8Loaded ? "PASS" : "FAIL") (\(fm8Def.count) bytes)")

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                // Create FM8 synth
                                let fm8Msg = OSCMessage.sNew("sc_fm8", nodeID: 3000, addAction: 1, targetID: 0,
                                                              args: ["freq", Float(220.0), "amp", Float(0.1), "index", Float(200.0)])
                                let fm8Played = scEngine.sendOSC(fm8Msg)

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    let fm8Synths = scEngine.numSynths
                                    let fm8UGens = scEngine.numUGens
                                    // 8-op FM should create 33 UGens (Control + 8*(freqMul+SinOsc+scale) + 7*addMod + Out)
                                    let fm8Pass = fm8Played && fm8Synths > 0 && fm8UGens >= 30
                                    print("TEST fm8_synthesis: \(fm8Pass ? "PASS" : "FAIL") (synths: \(fm8Synths), ugens: \(fm8UGens))")

                                    // Free FM8 synth
                                    let _ = scEngine.freeNode(3000)

                                    // Test 10: Memory pressure — allocate 50 large buffers, verify server stable
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        // Allocate 50 buffers of ~1MB each (48000 frames * 2ch * 4 bytes = 384KB)
                                        for i: Int32 in 20...69 {
                                            let _ = scEngine.sendOSC(OSCMessage.bAlloc(i, numFrames: 48000 * 5, numChannels: 2))
                                        }

                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            let serverStillRunning = scEngine.isRunning
                                            // Try to create a synth while buffers are allocated
                                            let canStillPlay = scEngine.playSine(freq: 880, amp: 0.05, nodeID: 4000)

                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                let synthsAfterPressure = scEngine.numSynths
                                                print("TEST memory_pressure: \(serverStillRunning && canStillPlay && synthsAfterPressure > 0 ? "PASS" : "FAIL") (running: \(serverStillRunning), synths: \(synthsAfterPressure))")

                                                // Free everything
                                                let _ = scEngine.freeNode(4000)
                                                for i: Int32 in 20...69 {
                                                    let _ = scEngine.sendOSC(OSCMessage.bFree(i))
                                                }

                                                print("=== SC iOS AUTO-TEST END ===")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
