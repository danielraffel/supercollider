import SwiftUI

/// Re-enables interactive back swipe when nav bar is hidden
struct EnableSwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        DispatchQueue.main.async {
            vc.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            vc.navigationController?.interactivePopGestureRecognizer?.delegate = nil
        }
        return vc
    }
    func updateUIViewController(_ vc: UIViewController, context: Context) {}
}

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
                onDoubleTap: { app.isEditing = true },
                onScrubStart: { range, value, rect in
                    app.scrubRange = range
                    app.scrubOriginalValue = value
                    app.scrubValue = Double(value) ?? 0
                    app.scrubPopupRect = rect
                    app.isScrubbing = true
                },
                onScrubUpdate: { delta in
                    guard let original = Double(app.scrubOriginalValue) else { return }
                    // Determine step size based on value type
                    let step: Double
                    if original == floor(original) && original > 1 {
                        step = 1.0  // Integer: 1 per point
                    } else if original >= 0 && original <= 1 {
                        step = 0.001  // 0-1 range: fine
                    } else {
                        step = 0.1  // Float: medium
                    }
                    let newValue = original + (delta * step)
                    app.scrubValue = newValue

                    // Update the code text with the new value
                    if let range = app.scrubRange {
                        let nsText = app.codeText as NSString
                        let formatted: String
                        if original == floor(original) && original > 1 {
                            formatted = "\(Int(newValue))"
                        } else {
                            formatted = String(format: "%.3g", newValue)
                        }
                        let newText = nsText.replacingCharacters(in: range, with: formatted)
                        // Update range for new string length
                        app.scrubRange = NSRange(location: range.location, length: formatted.count)
                        app.codeText = newText
                    }
                },
                onScrubEnd: {
                    app.isScrubbing = false
                }
            )
            .layoutPriority(1)
        }
        .background(Color.black)
        .overlay(alignment: .bottom) {
            if app.isScrubbing || app.scrubRange != nil {
                scrubBar
            } else {
                toastView
            }
        }
        .overlay {
            if !app.serverRunning || !app.sclangReady {
                bootOverlay
            }
        }
        .overlay {
            if app.isScrubbing {
                scrubPopup
            }
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
        .background(EnableSwipeBack())
        .onAppear {
            if alwaysEditMode { app.isEditing = true }
        }
    }

    private func saveCurrentFile() {
        guard app.currentFile != nil else {
            app.showToast("No file to save", isError: true)
            return
        }
        app.saveToFile()
        app.showToast("Saved", isError: false)
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

    // MARK: - Value Scrub UI

    var scrubPopup: some View {
        VStack(spacing: 6) {
            // Current value
            Text(formattedScrubValue)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.orange)

            // Original value
            Text("was \(app.scrubOriginalValue)")
                .font(.caption)
                .foregroundColor(.secondary)

            // Speed hint
            HStack(spacing: 16) {
                Text("1-finger: fine")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
                Text("2-finger: coarse")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray5))
                .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        )
        .transition(.scale.combined(with: .opacity))
    }

    var scrubBar: some View {
        HStack(spacing: 12) {
            Button {
                // Apply: re-evaluate the enclosing block
                app.isScrubbing = false
                app.evaluateSelection()
                app.scrubRange = nil
                app.showToast("Applied", isError: false)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.caption)
                    Text("Apply")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button {
                // Revert to original value
                if let range = app.scrubRange {
                    let nsText = app.codeText as NSString
                    app.codeText = nsText.replacingCharacters(in: range, with: app.scrubOriginalValue)
                }
                app.isScrubbing = false
                app.scrubRange = nil
            } label: {
                Text("Revert")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground).opacity(0.95))
    }

    private var formattedScrubValue: String {
        let original = Double(app.scrubOriginalValue) ?? 0
        if original == floor(original) && abs(original) > 1 {
            return "\(Int(app.scrubValue))"
        } else {
            return String(format: "%.3g", app.scrubValue)
        }
    }

    // MARK: - Boot Overlay

    var bootOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.orange)
                .scaleEffect(1.5)

            Text(app.serverRunning ? "Compiling class library..." : "Starting audio engine...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7))
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

            // Filename + unsaved indicator
            HStack(spacing: 4) {
                if app.hasUnsavedChanges {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                }
                Text(currentFileName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

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

            if app.isScrubbing {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption2)
                    Text("Scrubbing")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.2))
                .clipShape(Capsule())
            } else if !app.sclangReady {
                ProgressView()
                    .tint(.orange)
                    .scaleEffect(0.8)
            } else if app.isRecording {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text("REC")
                    .font(.caption2.bold())
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
