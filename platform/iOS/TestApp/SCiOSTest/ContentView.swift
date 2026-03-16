import SwiftUI

enum IPadTab: Hashable {
    case editor, post, server, files
}

struct ContentView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedTab = 0
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
    }

    // MARK: - iPad Layout

    var iPadLayout: some View {
        NavigationSplitView {
            List(selection: $selectedIPadTab) {
                Label("Editor", systemImage: "chevron.left.forwardslash.chevron.right")
                    .tag(IPadTab.editor)
                Label("Post", systemImage: "text.alignleft")
                    .tag(IPadTab.post)
                Label("Server", systemImage: "server.rack")
                    .tag(IPadTab.server)
                Label("Files", systemImage: "folder")
                    .tag(IPadTab.files)
            }
            .navigationTitle("SuperCollider")
        } detail: {
            switch selectedIPadTab {
            case .editor, .none:
                EditorView()
            case .post:
                PostView()
            case .server:
                ServerView()
            case .files:
                FileBrowserView()
            }
        }
    }

    // MARK: - iPhone Layout

    var iPhoneLayout: some View {
        TabView(selection: $selectedTab) {
            EditorView()
                .tabItem {
                    Label("Editor", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .tag(0)

            PostView()
                .tabItem {
                    Label("Post", systemImage: "text.alignleft")
                }
                .tag(1)

            ServerView()
                .tabItem {
                    Label("Server", systemImage: "server.rack")
                }
                .tag(2)

            FileBrowserView()
                .tabItem {
                    Label("Files", systemImage: "folder")
                }
                .tag(3)
        }
    }
}
