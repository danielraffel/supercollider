import SwiftUI
import UIKit

/// Global callbacks for code evaluation
var scEvaluateCallback: ((String) -> Void)?
var scStopCallback: (() -> Void)?
/// Closure to get current selected text (or all text if no selection)
var scGetSelectedText: (() -> String)?

/// Custom UITextView subclass with SC-specific menu actions and long-press line selection
class SCCodeTextView: UITextView {

    // Tracks whether a long-press is active for line-based selection
    private var longPressActive = false
    // The character range of the anchor line when long-press started
    private var longPressAnchorLineRange: NSRange?

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupLongPressGesture()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLongPressGesture()
    }

    private func setupLongPressGesture() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.4
        // Allow simultaneous recognition with the built-in pan/selection gestures
        longPress.delegate = self
        addGestureRecognizer(longPress)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: self)

        switch gesture.state {
        case .began:
            longPressActive = true
            // Try to find enclosing ( ... ) block first
            if let blockRange = findEnclosingBlock(at: location) {
                selectedRange = blockRange
                longPressAnchorLineRange = blockRange
            } else {
                // No block found — select current line
                let anchorRange = lineRange(at: location)
                longPressAnchorLineRange = anchorRange
                if let r = anchorRange {
                    selectedRange = r
                }
            }

        case .changed:
            guard longPressActive, let anchor = longPressAnchorLineRange else { return }
            let currentRange = lineRange(at: location)
            guard let current = currentRange else { return }

            let start = min(anchor.location, current.location)
            let end = max(
                anchor.location + anchor.length,
                current.location + current.length
            )
            selectedRange = NSRange(location: start, length: end - start)

        case .ended, .cancelled, .failed:
            longPressActive = false
            longPressAnchorLineRange = nil

        default:
            break
        }
    }

    /// Find the enclosing ( ... ) block around the touch point.
    /// In SC, `(` on its own line starts a block and `)` on its own line ends it.
    private func findEnclosingBlock(at point: CGPoint) -> NSRange? {
        guard let fullText = text as NSString? else { return nil }
        let totalLength = fullText.length
        guard totalLength > 0 else { return nil }

        // Find character index at touch point
        let adjustedPoint = CGPoint(
            x: max(textContainerInset.left, min(point.x, bounds.width - textContainerInset.right)),
            y: max(textContainerInset.top, min(point.y, contentSize.height - 1))
        )
        let glyphIndex = layoutManager.glyphIndex(for: adjustedPoint, in: textContainer, fractionOfDistanceThroughGlyph: nil)
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let idx = min(charIndex, totalLength - 1)

        let str = fullText as String

        // Scan backwards for `(` at the start of a line (possibly with whitespace)
        var blockStart: String.Index? = nil
        let startSearchIdx = str.index(str.startIndex, offsetBy: min(idx, str.count))
        var scanIdx = startSearchIdx
        while scanIdx > str.startIndex {
            // Find start of this line
            let lineStart = str[...scanIdx].lastIndex(of: "\n").map { str.index(after: $0) } ?? str.startIndex
            let lineContent = str[lineStart...scanIdx].trimmingCharacters(in: .whitespaces)
            if lineContent.hasPrefix("(") && lineContent.count <= 2 {
                blockStart = lineStart
                break
            }
            if lineStart == str.startIndex { break }
            scanIdx = str.index(before: lineStart)
        }

        guard let bStart = blockStart else { return nil }

        // Scan forwards for `)` at the start of a line
        var blockEnd: String.Index? = nil
        scanIdx = startSearchIdx
        while scanIdx < str.endIndex {
            let lineEnd = str[scanIdx...].firstIndex(of: "\n") ?? str.endIndex
            let lineContent = str[scanIdx..<lineEnd].trimmingCharacters(in: .whitespaces)
            if lineContent == ")" {
                blockEnd = lineEnd
                break
            }
            if lineEnd == str.endIndex { break }
            scanIdx = str.index(after: lineEnd)
        }

        guard let bEnd = blockEnd else { return nil }

        let nsStart = str.distance(from: str.startIndex, to: bStart)
        let nsEnd = str.distance(from: str.startIndex, to: bEnd)
        return NSRange(location: nsStart, length: nsEnd - nsStart)
    }

    /// Returns the NSRange of the full line (including newline) that contains the given point.
    private func lineRange(at point: CGPoint) -> NSRange? {
        guard let fullText = text as NSString? else { return nil }
        let totalLength = fullText.length
        guard totalLength > 0 else { return nil }

        // Clamp point inside content bounds so edges still pick a line
        let adjustedPoint = CGPoint(
            x: max(textContainerInset.left, min(point.x, bounds.width - textContainerInset.right)),
            y: max(textContainerInset.top, min(point.y, contentSize.height - 1))
        )

        // Closest character index to the touch point
        let glyphIndex = layoutManager.glyphIndex(
            for: adjustedPoint,
            in: textContainer,
            fractionOfDistanceThroughGlyph: nil
        )
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let clampedIndex = min(charIndex, totalLength - 1)

        // Expand to full line range
        let lineRange = fullText.lineRange(for: NSRange(location: clampedIndex, length: 0))
        return lineRange
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(evaluateSelection(_:)) || action == #selector(stopAllSound(_:)) {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)

        let evalAction = UIAction(title: "Evaluate", image: UIImage(systemName: "play.fill")) { [weak self] _ in
            self?.evaluateSelection(nil)
        }
        let stopAction = UIAction(title: "Stop All", image: UIImage(systemName: "stop.fill")) { _ in
            scStopCallback?()
        }
        let scMenu = UIMenu(title: "", options: .displayInline, children: [evalAction, stopAction])
        builder.insertSibling(scMenu, afterMenu: .standardEdit)
    }

    @objc func evaluateSelection(_ sender: Any?) {
        if let range = selectedTextRange, !range.isEmpty {
            let selected = text(in: range) ?? ""
            scEvaluateCallback?(selected)
        } else {
            scEvaluateCallback?(text ?? "")
        }
    }

    @objc func stopAllSound(_ sender: Any?) {
        scStopCallback?()
    }

    /// Returns selected text, or empty string if nothing selected
    func getSelectedText() -> String {
        if let range = selectedTextRange, !range.isEmpty {
            return text(in: range) ?? ""
        }
        return ""  // Nothing selected
    }
}

// MARK: - UIGestureRecognizerDelegate
extension SCCodeTextView: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Allow long-press to coexist with the built-in text-view gestures
        return true
    }
}

/// UITextView wrapper with SC syntax highlighting
struct CodeTextView: UIViewRepresentable {
    @Binding var text: String
    /// Mirrors AppState.lastSelection so updateUIView can detect when it is cleared after evaluation
    var lastSelection: String = ""
    var onEvaluate: (() -> Void)?
    var onEvaluateCode: ((String) -> Void)?
    var onStop: (() -> Void)?
    var onSelectionChanged: ((String) -> Void)?

    func makeUIView(context: Context) -> SCCodeTextView {
        let textView = SCCodeTextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.backgroundColor = UIColor.black
        textView.textColor = .label
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.keyboardDismissMode = .interactive
        textView.alwaysBounceVertical = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 16, right: 4)
        textView.setContentHuggingPriority(.defaultLow, for: .vertical)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        // Wire up the get-selected-text closure
        scGetSelectedText = { [weak textView] in
            textView?.getSelectedText() ?? ""
        }

        // Keyboard inset adjustments
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak textView] notification in
            guard let textView = textView else { return }
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let keyboardHeight = keyboardFrame.height
            let safeAreaBottom = textView.window?.safeAreaInsets.bottom ?? 0
            let inset = max(0, keyboardHeight - safeAreaBottom)
            textView.contentInset.bottom = inset
            textView.verticalScrollIndicatorInsets.bottom = inset
        }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak textView] _ in
            guard let textView = textView else { return }
            textView.contentInset.bottom = 16
            textView.verticalScrollIndicatorInsets.bottom = 0
        }

        return textView
    }

    func updateUIView(_ textView: SCCodeTextView, context: Context) {
        // Keep coordinator callbacks up to date on every SwiftUI update
        context.coordinator.evaluateCode = onEvaluateCode
        context.coordinator.stopAll = onStop
        context.coordinator.onEvaluate = onEvaluate
        context.coordinator.onSelectionChanged = onSelectionChanged

        // When AppState.lastSelection is cleared (after evaluation), reset the dedup
        // tracker so the user can re-select the same text and have it register again.
        if lastSelection.isEmpty {
            context.coordinator.resetSelectionTracking()
        }

        // Wire the global UIKit callbacks so SCCodeTextView can reach them
        scEvaluateCallback = { code in
            context.coordinator.evaluateCode?(code)
        }
        scStopCallback = {
            context.coordinator.stopAll?()
        }

        scGetSelectedText = { [weak textView] in
            textView?.getSelectedText() ?? ""
        }

        if textView.text != text {
            let selectedRange = textView.selectedRange
            textView.text = text
            context.coordinator.applyHighlighting(textView)
            if selectedRange.location <= (text as NSString).length {
                textView.selectedRange = selectedRange
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onEvaluate: onEvaluate)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        var onEvaluate: (() -> Void)?
        var evaluateCode: ((String) -> Void)?
        var stopAll: (() -> Void)?
        /// Callback to save selection to AppState.lastSelection
        var onSelectionChanged: ((String) -> Void)?
        private var highlightTimer: Timer?
        /// Tracks the last reported selection to avoid spurious updates during scrolling
        private var lastReportedSelection: String = ""

        init(text: Binding<String>, onEvaluate: (() -> Void)?) {
            self.text = text
            self.onEvaluate = onEvaluate
        }

        /// Called when AppState.lastSelection is cleared so the same text can be re-selected
        func resetSelectionTracking() {
            lastReportedSelection = ""
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            // Only update lastSelection when there is a non-empty selection.
            // Do NOT clear it when the selection becomes empty (e.g. on focus loss or
            // after the keyboard dismisses) so the Play button can still use it.
            guard let range = textView.selectedTextRange, !range.isEmpty else { return }
            let selected = textView.text(in: range) ?? ""
            // Skip if the selected text hasn't actually changed (fires constantly during scroll)
            guard selected != lastReportedSelection else { return }
            lastReportedSelection = selected
            onSelectionChanged?(selected)
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text

            highlightTimer?.invalidate()
            highlightTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                self?.applyHighlighting(textView)
            }
        }

        func applyHighlighting(_ textView: UITextView) {
            let font = textView.font ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            let selectedRange = textView.selectedRange
            let scrollOffset = textView.contentOffset

            let highlighted = SCSyntaxHighlighter.shared.highlight(textView.text, font: font)
            textView.attributedText = highlighted
            textView.selectedRange = selectedRange
            textView.setContentOffset(scrollOffset, animated: false)
        }
    }
}
