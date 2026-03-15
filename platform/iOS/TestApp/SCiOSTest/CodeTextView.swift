import SwiftUI
import UIKit

/// Callback for code evaluation from text view context menu
var scEvaluateCallback: ((String) -> Void)?
var scStopCallback: (() -> Void)?

/// Custom UITextView subclass with SC-specific menu actions
class SCCodeTextView: UITextView {

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // Add our custom actions alongside standard ones
        if action == #selector(evaluateSelection(_:)) || action == #selector(stopAllSound(_:)) {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)

        // Add SC actions to the context menu
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
            // No selection: evaluate all text
            scEvaluateCallback?(text ?? "")
        }
    }

    @objc func stopAllSound(_ sender: Any?) {
        scStopCallback?()
    }
}

/// UITextView wrapper with SC syntax highlighting
struct CodeTextView: UIViewRepresentable {
    @Binding var text: String
    var onEvaluate: (() -> Void)?

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
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)

        // Make it fill available space
        textView.setContentHuggingPriority(.defaultLow, for: .vertical)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        return textView
    }

    func updateUIView(_ textView: SCCodeTextView, context: Context) {
        // Wire up callbacks
        scEvaluateCallback = { code in
            context.coordinator.evaluateCode?(code)
        }
        scStopCallback = context.coordinator.stopAll

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
        private var highlightTimer: Timer?

        init(text: Binding<String>, onEvaluate: (() -> Void)?) {
            self.text = text
            self.onEvaluate = onEvaluate
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text

            // Debounce syntax highlighting
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
