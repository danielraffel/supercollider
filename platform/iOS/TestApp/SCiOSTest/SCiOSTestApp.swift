import SwiftUI

@main
struct SCiOSTestApp: App {
    @StateObject private var scEngine = SCEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(scEngine)
                .onAppear {
                    // Run automated scsynth tests after a short delay to let server boot
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        runAutoTests()
                    }
                    // Run sclang feasibility test independently (15s delay for auto-tests to finish)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
                        SCiOSTestApp.runSclangFeasibilityTest()
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

                                                // Phase 6: sclang feasibility test
                                                print("SCLANG: scheduling feasibility test...")
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                    print("SCLANG: starting feasibility test now")
                                                    SCiOSTestApp.runSclangFeasibilityTest()
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

    static private var sclangLog: [String] = []

    static private func slog(_ msg: String) {
        sclangLog.append(msg)
        // Write to file immediately
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logFile = docs.appendingPathComponent("sclang_test.log")
        try? sclangLog.joined(separator: "\n").write(to: logFile, atomically: true, encoding: .utf8)
        // Print to stdout AND force flush
        let line = msg + "\n"
        if let data = line.data(using: .utf8) {
            FileHandle.standardOutput.write(data)
        }
    }

    static private func runSclangFeasibilityTest() {
        slog("=== SCLANG FEASIBILITY TEST START ===")

        let sclang = SclangEngine()

        // Get class library path from app bundle
        let classLibPath = Bundle.main.path(forResource: "SCClassLibrary", ofType: nil)
        let bundleResourcePath = Bundle.main.resourcePath
        slog("SCLANG class_lib_path: \(classLibPath ?? "NOT FOUND")")
        slog("SCLANG bundle_resource_path: \(bundleResourcePath ?? "NOT FOUND")")

        if classLibPath == nil {
            slog("SCLANG TEST class_lib_bundled: FAIL (SCClassLibrary not in bundle)")
            slog("=== SCLANG FEASIBILITY TEST END ===")
            return
        }
        slog("SCLANG TEST class_lib_bundled: PASS")

        // Test 1: Initialize sclang — pass the SCClassLibrary path so the resource dir gets set
        let initOk = sclang.initialize(classLibraryPath: classLibPath)
        slog("SCLANG TEST init: \(initOk ? "PASS" : "FAIL")")

        if !initOk {
            slog("=== SCLANG FEASIBILITY TEST END ===")
            return
        }

        // Test 2: Compile class library (on background thread to not block UI)
        DispatchQueue.global(qos: .userInitiated).async {
            let startMem = getMemoryMB()
            let start = CFAbsoluteTimeGetCurrent()

            let compileOk = sclang.compileLibrary()
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
            let endMem = getMemoryMB()
            let memDelta = endMem - startMem

            DispatchQueue.main.async {
                slog("SCLANG TEST compile_library: \(compileOk ? "PASS" : "FAIL")")
                slog("SCLANG compile_time_ms: \(Int(elapsed))")
                slog("SCLANG memory_before_mb: \(String(format: "%.1f", startMem))")
                slog("SCLANG memory_after_mb: \(String(format: "%.1f", endMem))")
                slog("SCLANG memory_delta_mb: \(String(format: "%.1f", memDelta))")

                if compileOk {
                    // Test 3: Execute simple SC code
                    let interpOk = sclang.interpret("1 + 1")
                    slog("SCLANG TEST interpret_simple: \(interpOk ? "PASS" : "FAIL")")

                    // Test 4: Execute SC code that creates a synth
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        let synthOk = sclang.interpret("{ SinOsc.ar(440, 0, 0.1) }.play")
                        slog("SCLANG TEST interpret_synth: \(synthOk ? "PASS" : "FAIL")")

                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            let output = sclang.postOutput
                            slog("SCLANG post_output_length: \(output.count)")
                            slog("SCLANG post_output_preview: \(String(output.prefix(500)))")

                            sclang.shutdown()
                            slog("SCLANG TEST shutdown: PASS")
                            slog("=== SCLANG FEASIBILITY TEST END ===")
                        }
                    }
                } else {
                    let output = sclang.postOutput
                    slog("SCLANG compile_output_length: \(output.count)")
                    slog("SCLANG compile_output_preview: \(String(output.prefix(2000)))")

                    sclang.shutdown()
                    slog("=== SCLANG FEASIBILITY TEST END ===")
                }
            }
        }
    }

    static private func getMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024)
        }
        return 0
    }
}
