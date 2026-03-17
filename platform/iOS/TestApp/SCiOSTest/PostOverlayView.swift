import SwiftUI

/// Post Window presented as a global overlay sheet.
/// Session-scoped — shows all sclang output regardless of which document is open.
struct PostOverlayView: View {
    @EnvironmentObject var app: AppState
    @State private var showCopied = false

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(app.postOutput.isEmpty ? "Ready." : app.postOutput)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(.label))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(10)
                        .id("postBottom")
                }
                .background(Color(.systemBackground))
                .onChange(of: app.postOutput) { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("postBottom", anchor: .bottom)
                    }
                }
            }
            .navigationTitle("Post Window")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if showCopied {
                        Text("Copied!")
                            .font(.caption)
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        UIPasteboard.general.string = app.postOutput
                        withAnimation { showCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { showCopied = false }
                        }
                    } label: {
                        Text("Copy")
                    }

                    Button("Clear", role: .destructive) {
                        app.clearPost()
                    }

                    Button {
                        app.showPost = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
