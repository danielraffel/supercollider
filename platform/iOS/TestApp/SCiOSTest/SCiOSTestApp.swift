import SwiftUI

@main
struct SCiOSTestApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ShakeDetectorView {
                appState.stopAll()
            }
            .overlay {
                ContentView()
                    .environmentObject(appState)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    appState.bootSystem()
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

/// Detects shake gesture and calls the action
struct ShakeDetectorView: UIViewControllerRepresentable {
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeViewController {
        let vc = ShakeViewController()
        vc.onShake = onShake
        return vc
    }

    func updateUIViewController(_ uiViewController: ShakeViewController, context: Context) {
        uiViewController.onShake = onShake
    }

    class ShakeViewController: UIViewController {
        var onShake: (() -> Void)?

        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            if motion == .motionShake {
                onShake?()
            }
        }

        override var canBecomeFirstResponder: Bool { true }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            becomeFirstResponder()
        }
    }
}
