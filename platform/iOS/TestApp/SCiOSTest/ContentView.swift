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
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                iPadLayout
            } else {
                iPhoneLayout
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

    // MARK: - iPad: NavigationStack (Files → Editor push)

    var iPadLayout: some View {
        NavigationStack {
            FileBrowserView()
                .navigationTitle("SuperCollider")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(isPresented: $app.showEditor) {
                    EditorView()
                        .navigationBarBackButtonHidden(true)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button {
                                    app.showEditor = false
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.left")
                                        Text("Files")
                                    }
                                }
                            }
                        }
                }
        }
    }

    // MARK: - iPhone: TabView (bottom bar)

    var iPhoneLayout: some View {
        tabContent
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
