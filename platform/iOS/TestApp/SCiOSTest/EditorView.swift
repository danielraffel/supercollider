import SwiftUI

struct EditorView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            CodeTextView(
                text: $app.codeText,
                lastSelection: app.lastSelection,
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
        HStack(spacing: 12) {
            // Play button
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
            }
            .disabled(!app.sclangReady)
            .keyboardShortcut(.return, modifiers: .command)

            // Stop button
            Button(action: { app.stopAll() }) {
                Image(systemName: "stop.fill")
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.red.opacity(0.8))
                    .clipShape(Circle())
            }
            .keyboardShortcut(".", modifiers: .command)

            // Record button
            Button(action: { app.toggleRecording() }) {
                Image(systemName: app.isRecording ? "record.circle.fill" : "record.circle")
                    .foregroundColor(app.isRecording ? .red : .white)
                    .frame(width: 36, height: 36)
                    .background(app.isRecording ? Color.red.opacity(0.3) : Color.gray.opacity(0.5))
                    .clipShape(Circle())
            }
            .disabled(!app.sclangReady || !app.serverRunning)

            if !app.sclangReady {
                Text("compiling...")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if app.isRecording {
                Text("REC")
                    .font(.caption.bold())
                    .foregroundColor(.red)
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
