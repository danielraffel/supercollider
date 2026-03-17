import SwiftUI

struct EditorView: View {
    @EnvironmentObject var app: AppState
    @AppStorage("sc_always_edit_mode") private var alwaysEditMode = false

    var body: some View {
        VStack(spacing: 0) {
            navBar
            transportBar
            Divider()
            CodeTextView(
                text: $app.codeText,
                lastSelection: app.lastSelection,
                isEditable: app.isEditing,
                onEvaluate: { app.evaluateSelection() },
                onEvaluateCode: { code in app.evaluateCode(code) },
                onStop: { app.stopAll() },
                onSelectionChanged: { selected in app.lastSelection = selected },
                onDoubleTap: { app.isEditing = true }
            )
            .layoutPriority(1)
        }
        .background(Color.black)
        .overlay(alignment: .bottom) {
            toastView
        }
        // Keyboard shortcut: Cmd+E toggles Edit mode
        // Hidden keyboard shortcuts
        .background(
            Group {
                // Cmd+E: toggle Edit mode
                Button("") {
                    app.isEditing.toggle()
                    if !app.isEditing {
                        app.autosave()
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                .keyboardShortcut("e", modifiers: .command)

                // Cmd+S: save current file
                Button("") {
                    saveCurrentFile()
                }
                .keyboardShortcut("s", modifiers: .command)
            }
            .hidden()
        )
        .onAppear {
            if alwaysEditMode { app.isEditing = true }
        }
    }

    private func saveCurrentFile() {
        guard let path = app.currentFile else {
            app.showToast("No file to save", isError: true)
            return
        }
        do {
            try app.codeText.write(toFile: path, atomically: true, encoding: .utf8)
            app.autosave()
            app.showToast("Saved", isError: false)
        } catch {
            app.showToast("Save failed", isError: true)
        }
    }

    var currentFileName: String {
        if let file = app.currentFile {
            return (file as NSString).lastPathComponent
        }
        return "Untitled"
    }

    // MARK: - Toast

    @ViewBuilder
    var toastView: some View {
        if let toast = app.toastMessage {
            let isError = app.toastIsError
            HStack(spacing: 8) {
                Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundColor(isError ? .red : .green)
                Text(toast)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(isError ? .red : .green)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background((isError ? Color.red : Color.green).opacity(0.15))
            .clipShape(Capsule())
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Nav Bar (Read/Edit toggle)

    var navBar: some View {
        HStack(spacing: 8) {
            if app.isEditing {
                // Edit mode: Done button
                Button(action: {
                    app.isEditing = false
                    app.autosave()
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }) {
                    Text("Done")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
            } else {
                // Read mode: Back to Files
                Button(action: {
                    app.autosave()
                    app.showEditor = false
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.medium))
                        Text("Files")
                    }
                    .foregroundColor(.accentColor)
                }
            }

            Spacer()

            // Filename
            Text(currentFileName)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            if app.isEditing {
                // Undo/Redo (placeholders — UITextView handles internally)
                HStack(spacing: 12) {
                    Image(systemName: "arrow.uturn.backward")
                        .foregroundColor(.accentColor.opacity(0.5))
                    Image(systemName: "arrow.uturn.forward")
                        .foregroundColor(.accentColor.opacity(0.3))
                }
            } else {
                // Read mode: Edit button
                Button(action: { app.isEditing = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.caption)
                        Text("Edit")
                            .font(.subheadline)
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Transport Toolbar

    var transportBar: some View {
        HStack(spacing: 8) {
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

            // Post Window button
            Button(action: { app.showPost = true }) {
                Image(systemName: "terminal")
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }

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

            HStack(spacing: 6) {
                Circle()
                    .fill(app.serverRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                if app.serverRunning {
                    Text(String(format: "%.1f%%", app.avgCPU))
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                    Text("\(app.numSynths) syn")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                } else {
                    Text("off")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
