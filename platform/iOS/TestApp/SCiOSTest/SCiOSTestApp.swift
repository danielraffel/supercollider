import SwiftUI

@main
struct SCiOSTestApp: App {
    @StateObject private var scEngine = SCEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(scEngine)
        }
    }
}
