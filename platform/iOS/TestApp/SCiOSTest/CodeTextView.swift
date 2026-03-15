import SwiftUI
import UIKit

/// UITextView wrapper with SC syntax highlighting
struct CodeTextView: UIViewRepresentable {
    @Binding var text: String
    var onEvaluate: (() -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        textView.backgroundColor = .clear
        textView.textColor = .label
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.keyboardDismissMode = .interactive
        textView.alwaysBounceVertical = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)

        // Add key commands for external keyboard
        // ⌘+Return handled by SwiftUI keyboard shortcut
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            let selectedRange = textView.selectedRange
            textView.text = text
            // Apply syntax highlighting
            context.coordinator.applyHighlighting(textView)
            // Restore cursor
            if selectedRange.location <= text.count {
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
            let font = textView.font ?? UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
            let selectedRange = textView.selectedRange
            let scrollOffset = textView.contentOffset

            let highlighted = SCSyntaxHighlighter.shared.highlight(textView.text, font: font)
            textView.attributedText = highlighted
            textView.selectedRange = selectedRange
            textView.setContentOffset(scrollOffset, animated: false)
        }
    }
}
