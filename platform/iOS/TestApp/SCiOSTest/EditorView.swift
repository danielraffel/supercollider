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
            CodeTextView(text: $app.codeText, onEvaluate: {
                app.evaluateSelection()
            })
            .layoutPriority(1)
        }
        .background(Color.black)
        .onAppear {
            scEvaluateCallback = { [weak app] code in
                app?.evaluateCode(code)
            }
            scStopCallback = { [weak app] in
                app?.stopAll()
            }
        }
    }

    var toolbar: some View {
        HStack(spacing: 8) {
            Button(action: { app.evaluateSelection() }) {
                Image(systemName: "play.fill")
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(app.sclangReady ? Color.green : Color.gray)
                    .clipShape(Circle())
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
