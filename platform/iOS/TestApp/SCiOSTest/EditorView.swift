import SwiftUI

/// SC code editor with monospaced font and evaluation support
struct EditorView: View {
    @EnvironmentObject var app: AppState
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Button(action: { app.evaluateSelection() }) {
                    Label("Run", systemImage: "play.fill")
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.bordered)
                .tint(.green)

                Button(action: { app.stopAll() }) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .keyboardShortcut(".", modifiers: .command)
                .buttonStyle(.bordered)
                .tint(.red)

                Spacer()

                // Server status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(app.serverRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(app.serverRunning ? "\(Int(app.avgCPU))%" : "off")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }

                Text("\(app.numSynths)s \(app.numUGens)u")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground).opacity(0.95))

            Divider()

            // Code editor with syntax highlighting
            CodeTextView(text: $app.codeText, onEvaluate: {
                app.evaluateSelection()
            })
            .background(Color(.systemBackground))
        }
    }
}
