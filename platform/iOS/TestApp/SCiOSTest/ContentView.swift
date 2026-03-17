import SwiftUI

struct ContentView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        NavigationStack {
            FileBrowserView()
                .navigationTitle("SuperCollider")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $app.showEditor) {
                    EditorView()
                        .navigationBarBackButtonHidden(true)
                        .toolbar(.hidden, for: .navigationBar)
                }
        }
        .sheet(isPresented: $app.showPost) {
            PostOverlayView()
                .environmentObject(app)
        }
        .sheet(isPresented: $app.showSettings) {
            SettingsView()
                .environmentObject(app)
        }
    }
}
