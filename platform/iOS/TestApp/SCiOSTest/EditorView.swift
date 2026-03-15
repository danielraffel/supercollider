import SwiftUI

/// SC code editor with monospaced font and evaluation support
struct EditorView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar at top
            toolbar

            Divider()

            // Code editor takes all remaining space
            CodeTextView(
                text: $app.codeText,
                onEvaluate: { app.evaluateSelection() },
                onEvaluateCode: { code in app.evaluateCode(code) },
                onStop: { app.stopAll() },
                onSelectionChanged: { selected in app.lastSelection = selected }
            )
            .layoutPriority(1)
        }
        .background(Color.black)
    }

    var toolbar: some View {
        HStack(spacing: 8) {
            Button(action: { app.evaluateSelection() }) {
                Image(systemName: "play.fill")
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        app.sclangReady
                            ? (app.isPlaying ? Color.orange : Color.green)
                            : Color.gray
                    )
                    .clipShape(Circle())
                    .overlay(
                        app.isPlaying
                            ? Circle()
                                .stroke(Color.orange.opacity(0.5), lineWidth: 3)
                                .scaleEffect(1.3)
                            : nil
                    )
            }
            .disabled(!app.sclangReady)
            .keyboardShortcut(.return, modifiers: .command)

            Button(action: { app.stopAll() }) {
                Image(systemName: "stop.fill")
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.red.opacity(0.8))
                    .clipShape(Circle())
            }
            .keyboardShortcut(".", modifiers: .command)

            if !app.sclangReady {
                Text("compiling...")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Spacer()

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
    }
}
