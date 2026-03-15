import SwiftUI

struct ContentView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad: split view
                iPadLayout
            } else {
                // iPhone: tab layout
                iPhoneLayout
            }
        }
    }

    // MARK: - iPad Layout

    var iPadLayout: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: .constant(0)) {
                NavigationLink(destination: ServerView()) {
                    Label("Server", systemImage: "server.rack")
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
            NavigationStack {
                EditorView()
                    .navigationTitle("Editor")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Editor", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .tag(0)

            NavigationStack {
                PostView()
                    .navigationTitle("Post")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Post", systemImage: "text.alignleft")
            }
            .tag(1)

            NavigationStack {
                ServerView()
            }
            .tabItem {
                Label("Server", systemImage: "server.rack")
            }
            .tag(2)

            NavigationStack {
                FileBrowserView()
            }
            .tabItem {
                Label("Files", systemImage: "folder")
            }
            .tag(3)
        }
    }
}
