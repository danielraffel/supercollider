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
                        print("=== SC iOS AUTO-TEST END ===")
                    }
                }
            }
        }
    }
}
