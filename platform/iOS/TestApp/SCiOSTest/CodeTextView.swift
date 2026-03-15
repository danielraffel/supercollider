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
            let anchorRange = lineRange(at: location)
            longPressAnchorLineRange = anchorRange
            // Select the entire anchor line
            if let r = anchorRange {
                selectedRange = r
            }

        case .changed:
            guard longPressActive, let anchor = longPressAnchorLineRange else { return }
            let currentRange = lineRange(at: location)
            guard let current = currentRange else { return }

            // Extend selection to cover anchor + current line, spanning both directions
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

        return textView
    }

    func updateUIView(_ textView: SCCodeTextView, context: Context) {
        // Keep coordinator callbacks up to date on every SwiftUI update
        context.coordinator.evaluateCode = onEvaluateCode
        context.coordinator.stopAll = onStop
        context.coordinator.onEvaluate = onEvaluate
        context.coordinator.onSelectionChanged = onSelectionChanged

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

        init(text: Binding<String>, onEvaluate: (() -> Void)?) {
            self.text = text
            self.onEvaluate = onEvaluate
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            // Save current selection so Play button can use it even after focus lost
            if let range = textView.selectedTextRange, !range.isEmpty {
                let selected = textView.text(in: range) ?? ""
                onSelectionChanged?(selected)
            } else {
                onSelectionChanged?("")
            }
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
