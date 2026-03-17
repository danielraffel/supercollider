import SwiftUI

/// Re-enables interactive back swipe when nav bar is hidden
struct EnableSwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = SwipeBackVC()
        return vc
    }
    func updateUIViewController(_ vc: UIViewController, context: Context) {
        // Re-enable on every update in case nav controller changed
        DispatchQueue.main.async {
            vc.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            vc.navigationController?.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}

class SwipeBackVC: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }
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
                onSelectionRangeChanged: { range in app.lastSelectionRange = range },
                onDoubleTap: { app.isEditing = true },
                isScrubbing: app.isScrubbing,
                onScrubStart: { range, value, rect in
                    app.scrubRange = range
                    app.scrubOriginalValue = value
                    app.scrubValue = Double(value) ?? 0
                    app.scrubPopupRect = rect
                    // Initialize scrub history
                    app.scrubHistory = [Double(value) ?? 0]
                    app.scrubHistoryIndex = 0
                    app.isScrubbing = true
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
                // Tap background to dismiss (reverts to original)
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Revert to original value
                        if let range = app.scrubRange {
                            let nsText = app.codeText as NSString
                            if range.location + range.length <= nsText.length {
                                app.codeText = nsText.replacingCharacters(in: range, with: app.scrubOriginalValue)
                            }
                        }
                        stopLiveNdef()
                        liveMode = false
                        app.isScrubbing = false
                        app.scrubRange = nil
                        app.scrubHistory = []
                        app.scrubHistoryIndex = -1
                    }
                    .allowsHitTesting(true)

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

    @State private var liveMode = false
    @State private var liveNdefActive = false

    var scrubPopup: some View {
        VStack(spacing: 12) {
            // Context description
            Text(scrubContextDescription)
                .font(.caption.weight(.medium))
                .foregroundColor(.orange.opacity(0.7))
                .lineLimit(1)

            // Value display
            Text(formattedScrubValue)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(.orange)

            HStack(spacing: 12) {
                Text("was \(app.scrubOriginalValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Undo
                Button {
                    scrubUndo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.caption.weight(.medium))
                        .foregroundColor(canScrubUndo ? .white : .white.opacity(0.2))
                }
                .disabled(!canScrubUndo)

                // Redo
                Button {
                    scrubRedo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.caption.weight(.medium))
                        .foregroundColor(canScrubRedo ? .white : .white.opacity(0.2))
                }
                .disabled(!canScrubRedo)

                // Reset to original
                Button {
                    app.scrubValue = Double(app.scrubOriginalValue) ?? 0
                    pushScrubHistory(app.scrubValue)
                    updateCodeWithScrubValue()
                    if liveMode { liveApply() }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.orange.opacity(0.7))
                }
            }

            // Slider
            let original = Double(app.scrubOriginalValue) ?? 0
            let range = scrubRange(for: original)
            Slider(value: $app.scrubValue, in: range) { editing in
                    if !editing {
                        // Push to history when user finishes dragging slider
                        pushScrubHistory(app.scrubValue)
                    }
                }
                .tint(.orange)
                .onChange(of: app.scrubValue) { _, _ in
                    updateCodeWithScrubValue()
                    if liveMode {
                        liveApply()
                    }
                }

            // Range labels
            HStack {
                Text(formatNumber(range.lowerBound))
                    .font(.caption2).foregroundColor(.white.opacity(0.3))
                Spacer()
                Text(formatNumber(range.upperBound))
                    .font(.caption2).foregroundColor(.white.opacity(0.3))
            }

            // +/- buttons
            HStack(spacing: 20) {
                Button {
                    app.scrubValue -= fineStep(for: original)
                    pushScrubHistory(app.scrubValue)
                    updateCodeWithScrubValue()
                    if liveMode { liveApply() }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2).foregroundColor(.secondary)
                }
                Button {
                    app.scrubValue += fineStep(for: original)
                    pushScrubHistory(app.scrubValue)
                    updateCodeWithScrubValue()
                    if liveMode { liveApply() }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2).foregroundColor(.secondary)
                }
            }

            Divider()

            // Action buttons
            HStack(spacing: 10) {
                // Live toggle
                Button {
                    liveMode.toggle()
                    if liveMode {
                        liveApply()
                    } else {
                        stopLiveNdef()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(liveMode ? Color.red : Color.gray)
                            .frame(width: 8, height: 8)
                        Text("Live")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(liveMode ? .red : .secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(liveMode ? Color.red.opacity(0.15) : Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Apply (stop + re-evaluate)
                Button {
                    app.isScrubbing = false
                    liveMode = false
                    app.stopAll()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        app.evaluateSelection()
                    }
                    app.scrubRange = nil
                    app.scrubHistory = []
                    app.scrubHistoryIndex = -1
                    app.showToast("Applied", isError: false)
                } label: {
                    Text("Apply")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // X button removed — tap background to dismiss
            }
        }
        .padding(20)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray5))
                .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
        )
        .transition(.scale.combined(with: .opacity))
    }

    /// Live apply: stop current synth and re-evaluate the block with new value.
    /// Throttled to avoid flooding the server.
    /// Smart live apply: wraps {}.play blocks in Ndef for smooth crossfade updates.
    /// Ndef blocks are re-evaluated directly. Patterns use stop+re-evaluate.
    private func liveApply() {
        // Get the code that would be evaluated.
        // During scrubbing, codeText has the updated value but lastSelection is stale.
        // Re-read the selection range from the current codeText to get the scrubbed value.
        let code: String
        if let range = app.lastSelectionRange {
            let nsText = app.codeText as NSString
            if range.location + range.length <= nsText.length {
                code = nsText.substring(with: range)
            } else {
                code = app.codeText
            }
        } else if let snapshot = scSnapshotSelection?(), !snapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            code = snapshot
        } else if !app.lastSelection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            code = app.lastSelection
        } else {
            code = app.codeText
        }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)

        // If already using Ndef, just re-evaluate — it cross-fades automatically
        if trimmed.contains("Ndef(") {
            app.evaluate(trimmed)
            liveNdefActive = true
            return
        }

        // If it's a {}.play block, wrap it in Ndef for smooth live updates
        if trimmed.contains(".play") && (trimmed.hasPrefix("{") || trimmed.hasPrefix("(")) {
            // Extract the function body: find the { ... } and wrap in Ndef
            let ndefCode = "Ndef(\\scrub, " + trimmed
                .replacingOccurrences(of: ".play;", with: "")
                .replacingOccurrences(of: ".play", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                // Remove outer ( ) if present
                .replacingOccurrences(of: "^\\(\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s*\\)$", with: "", options: .regularExpression)
            + ").play;"

            app.evaluate(ndefCode)
            liveNdefActive = true
            return
        }

        // Fallback: stop and re-evaluate (for patterns, etc.)
        app.stopAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            app.evaluateSelection()
        }
    }

    /// Clean up Ndef when turning off live mode
    private func stopLiveNdef() {
        if liveNdefActive {
            app.evaluate("Ndef(\\scrub).stop(0.5);")
            liveNdefActive = false
        }
    }

    // MARK: - Scrub Undo/Redo

    private var canScrubUndo: Bool {
        app.scrubHistoryIndex > 0
    }

    private var canScrubRedo: Bool {
        app.scrubHistoryIndex < app.scrubHistory.count - 1
    }

    private func pushScrubHistory(_ value: Double) {
        // Trim any redo history beyond current index
        if app.scrubHistoryIndex < app.scrubHistory.count - 1 {
            app.scrubHistory = Array(app.scrubHistory.prefix(app.scrubHistoryIndex + 1))
        }
        // Don't push duplicate values
        if let last = app.scrubHistory.last, abs(last - value) < 0.0001 { return }
        app.scrubHistory.append(value)
        app.scrubHistoryIndex = app.scrubHistory.count - 1
    }

    private func scrubUndo() {
        guard canScrubUndo else { return }
        app.scrubHistoryIndex -= 1
        app.scrubValue = app.scrubHistory[app.scrubHistoryIndex]
        updateCodeWithScrubValue()
        if liveMode { liveApply() }
    }

    private func scrubRedo() {
        guard canScrubRedo else { return }
        app.scrubHistoryIndex += 1
        app.scrubValue = app.scrubHistory[app.scrubHistoryIndex]
        updateCodeWithScrubValue()
        if liveMode { liveApply() }
    }

    // scrubBar is no longer needed — buttons are inline in the popup
    var scrubBar: some View {
        EmptyView()
    }

    private func updateCodeWithScrubValue() {
        guard let range = app.scrubRange else { return }
        let nsText = app.codeText as NSString
        let formatted = formatScrubNumber(app.scrubValue, original: Double(app.scrubOriginalValue) ?? 0)
        let newText = nsText.replacingCharacters(in: range, with: formatted)
        app.scrubRange = NSRange(location: range.location, length: formatted.count)
        app.codeText = newText
    }

    private var formattedScrubValue: String {
        formatScrubNumber(app.scrubValue, original: Double(app.scrubOriginalValue) ?? 0)
    }

    private func formatScrubNumber(_ value: Double, original: Double) -> String {
        if original == floor(original) && abs(original) > 1 {
            return "\(Int(value))"
        } else if abs(original) <= 1 {
            return String(format: "%.2f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func formatNumber(_ value: Double) -> String {
        if value == floor(value) { return "\(Int(value))" }
        return String(format: "%.1f", value)
    }

    private func scrubRange(for original: Double) -> ClosedRange<Double> {
        if original == floor(original) && abs(original) > 1 {
            // Integer (likely frequency)
            return 20...20000
        } else if original >= 0 && original <= 1 {
            // Amplitude / mix
            return 0...1
        } else {
            // General float
            return 0...max(abs(original) * 4, 10)
        }
    }

    /// Analyzes the code around the scrubbed number to describe what it controls
    private var scrubContextDescription: String {
        guard let range = app.scrubRange else { return "" }
        let code = app.codeText as NSString
        // Get ~80 chars before the number for context
        let contextStart = max(0, range.location - 80)
        let contextLen = range.location - contextStart
        let before = code.substring(with: NSRange(location: contextStart, length: contextLen))

        // Pattern match common SC UGen arguments
        if before.contains("SinOsc.ar(") || before.contains("Saw.ar(") || before.contains("Pulse.ar(") {
            let original = Double(app.scrubOriginalValue) ?? 0
            if original > 20 && original < 20000 { return "Frequency — Oscillator" }
            if original >= 0 && original <= 1 { return "Amplitude — Oscillator" }
        }
        if before.contains("LPF.ar(") || before.contains("HPF.ar(") || before.contains("RLPF.ar(") {
            return "Cutoff Frequency — Filter"
        }
        if before.contains("FreeVerb.ar(") {
            let original = Double(app.scrubOriginalValue) ?? 0
            if original >= 0 && original <= 1 { return "Mix/Room/Damp — Reverb" }
        }
        if before.contains("Env.perc(") || before.contains("Env.adsr(") {
            return "Envelope Time"
        }
        if before.contains("CombL.ar(") || before.contains("CombN.ar(") {
            return "Delay Time/Decay"
        }
        if before.contains("\\amp") || before.contains("amp,") {
            return "Amplitude"
        }
        if before.contains("\\freq") || before.contains("freq,") {
            return "Frequency"
        }
        if before.contains("\\dur") || before.contains("dur,") {
            return "Duration"
        }
        if before.contains("Dust.kr(") || before.contains("Impulse.kr(") {
            return "Trigger Rate"
        }
        if before.contains(".range(") {
            return "Range Parameter"
        }
        if before.contains("GrainSin") || before.contains("GrainFM") || before.contains("GrainBuf") {
            return "Granular Parameter"
        }

        let original = Double(app.scrubOriginalValue) ?? 0
        if original > 20 && original < 20000 { return "Frequency (Hz)" }
        if original >= 0 && original <= 1 { return "Amplitude / Mix (0–1)" }
        return "Parameter"
    }

    private func fineStep(for original: Double) -> Double {
        if original == floor(original) && abs(original) > 1 { return 1 }
        if original >= 0 && original <= 1 { return 0.01 }
        return 0.1
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
