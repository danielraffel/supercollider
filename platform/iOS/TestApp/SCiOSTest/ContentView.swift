import SwiftUI

enum IPadTab: Hashable {
    case editor, files
}

struct ContentView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedIPadTab: IPadTab? = .editor

    init() {
        // Make tab bar opaque so content doesn't bleed through
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.black
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        // Post Window — global overlay (session-scoped)
        .sheet(isPresented: $app.showPost) {
            PostOverlayView()
                .environmentObject(app)
        }
        // Settings — global sheet
        .sheet(isPresented: $app.showSettings) {
            SettingsView()
                .environmentObject(app)
        }
    }

    // MARK: - iPad Layout

    var iPadLayout: some View {
        NavigationSplitView {
            List(selection: $selectedIPadTab) {
                Label("Editor", systemImage: "chevron.left.forwardslash.chevron.right")
                    .tag(IPadTab.editor)
                Label("Files", systemImage: "folder")
                    .tag(IPadTab.files)
            }
            .navigationTitle("SuperCollider")
        } detail: {
            switch selectedIPadTab {
            case .editor, .none:
                EditorView()
                    .navigationBarHidden(true)
            case .files:
                NavigationStack {
                    FileBrowserView()
                        .navigationTitle("Files")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }

    // MARK: - iPhone Layout

    var iPhoneLayout: some View {
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
