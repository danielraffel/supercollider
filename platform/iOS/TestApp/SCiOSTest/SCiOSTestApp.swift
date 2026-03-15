import SwiftUI

@main
struct SCiOSTestApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        appState.bootSystem()
                    }
                }
                .preferredColorScheme(.dark)
        }
    }
}
