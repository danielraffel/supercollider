import SwiftUI

struct ContentView: View {
    @EnvironmentObject var app: AppState

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.black
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $app.selectedTab) {
            EditorView()
                .tabItem {
                    Label("Editor", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .tag(0)

            NavigationStack {
                FileBrowserView()
                    .navigationTitle("Files")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Files", systemImage: "folder")
            }
            .tag(1)
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
