import SwiftUI

struct ContentView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedTab = 0

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
            List(selection: .constant(0)) {
                NavigationLink(destination: ServerView()) {
                    Label("Server", systemImage: "server.rack")
                }
                NavigationLink(destination: FileBrowserView()) {
                    Label("Files", systemImage: "folder")
                }
            }
            .navigationTitle("SuperCollider")
        } content: {
            EditorView()
        } detail: {
            PostView()
        }
    }

    // MARK: - iPhone Layout

    var iPhoneLayout: some View {
        TabView(selection: $selectedTab) {
            EditorView()
                .toolbarBackground(.hidden, for: .tabBar)
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
