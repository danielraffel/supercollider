import SwiftUI

struct ContentView: View {
    @EnvironmentObject var app: AppState

    init() {
        // Force classic bottom tab bar style
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.black
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        // On iPadOS 18+, prevent the new sidebar-style tab bar
        if #available(iOS 18.0, *) {
            UITabBar.appearance().isHidden = false
        }
    }

    var body: some View {
        tabContent
            .sheet(isPresented: $app.showPost) {
                PostOverlayView()
                    .environmentObject(app)
            }
            .sheet(isPresented: $app.showSettings) {
                SettingsView()
                    .environmentObject(app)
            }
    }

    @ViewBuilder
    var tabContent: some View {
        if #available(iOS 18.0, *) {
            TabView(selection: $app.selectedTab) {
                Tab("Editor", systemImage: "chevron.left.forwardslash.chevron.right", value: 0) {
                    EditorView()
                }
                Tab("Files", systemImage: "folder", value: 1) {
                    NavigationStack {
                        FileBrowserView()
                            .navigationTitle("Files")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }
            .tabViewStyle(.tabBarOnly)
        } else {
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
        }
    }
}
