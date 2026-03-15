import SwiftUI

@main
struct SCiOSTestApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    bootSystem()
                }
                .preferredColorScheme(.dark)
        }
    }

    private func bootSystem() {
        // Boot scsynth
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let _ = appState.bootServer()

            // Init sclang after server boots
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let _ = appState.initSclang()
            }
        }
    }
}
