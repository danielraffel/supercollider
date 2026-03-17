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
                // If there's a last-opened file, go straight to editor
                if appState.currentFile != nil && !appState.codeText.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        appState.showEditor = true
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

/// Detects shake gesture and calls the action.
/// Note: When the code editor's keyboard is active, SCCodeTextView (which IS first
/// responder) handles shake directly via its own motionEnded override.  This view
/// controller acts as a secondary fallback for when the keyboard is dismissed.
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
            } else {
                super.motionEnded(motion, with: event)
            }
        }

        override var canBecomeFirstResponder: Bool { true }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            becomeFirstResponder()
        }

        // Re-assert first responder whenever the window's keyboard disappears
        // (i.e. when the code editor resigns first responder)
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardDidHide),
                name: UIResponder.keyboardDidHideNotification,
                object: nil
            )
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidHideNotification, object: nil)
        }

        @objc private func keyboardDidHide() {
            becomeFirstResponder()
        }
    }
}
