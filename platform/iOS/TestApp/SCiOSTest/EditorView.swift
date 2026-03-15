import SwiftUI

/// SC code editor with monospaced font and evaluation support
struct EditorView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                Button(action: { app.evaluateSelection() }) {
                    Image(systemName: "play.fill")
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.green)
                        .clipShape(Circle())
                }
                .keyboardShortcut(.return, modifiers: .command)

                Button(action: { app.stopAll() }) {
                    Image(systemName: "stop.fill")
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.red.opacity(0.8))
                        .clipShape(Circle())
                }
                .keyboardShortcut(".", modifiers: .command)

                Spacer()

                // Server status
                HStack(spacing: 4) {
                    Circle()
                        .fill(app.serverRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(app.serverRunning ? "\(Int(app.avgCPU))%" : "off")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                    Text("\(app.numSynths)s")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Code editor with syntax highlighting
            CodeTextView(text: $app.codeText, onEvaluate: {
                app.evaluateSelection()
            })
            .ignoresSafeArea(.keyboard)
        }
    }
}
