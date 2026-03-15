import SwiftUI

struct PostView: View {
    @EnvironmentObject var app: AppState
    @State private var showCopied = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Post")
                    .font(.headline)
                Spacer()

                if showCopied {
                    Text("Copied!")
                        .font(.caption)
                        .foregroundColor(.green)
                        .transition(.opacity)
                }

                Button {
                    UIPasteboard.general.string = app.postOutput
                    withAnimation {
                        showCopied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            showCopied = false
                        }
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Clear") {
                    app.clearPost()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    Text(app.postOutput.isEmpty ? "Ready." : app.postOutput)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(.label))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)
                        .id("postBottom")
                }
                .layoutPriority(1)
                .background(Color(.secondarySystemBackground))
                .onChange(of: app.postOutput) { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("postBottom", anchor: .bottom)
                    }
                }
            }
        }
        .background(Color(.secondarySystemBackground))
    }
}
