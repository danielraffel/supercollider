import SwiftUI
import UIKit

/// Global callbacks for code evaluation
var scEvaluateCallback: ((String) -> Void)?
var scStopCallback: (() -> Void)?
/// Closure to get current selected text (empty if nothing selected)
var scGetSelectedText: (() -> String)?
/// Closure to snapshot selection before focus is lost (for Play button)
var scSnapshotSelection: (() -> String)?
/// Closure called on double-tap (to enter Edit mode from Read mode)
var scDoubleTapCallback: (() -> Void)?
/// Value scrub callbacks
var scValueScrubStart: ((NSRange, String, CGRect) -> Void)?  // (range, originalValue, rect)
var scValueScrubUpdate: ((Double) -> Void)?  // delta from drag
var scValueScrubEnd: (() -> Void)?

/// Custom UITextView subclass with SC-specific menu actions and long-press line selection
class SCCodeTextView: UITextView {

    /// When false (Read mode), keyboard is suppressed but selection still works
    var readModeActive = false {
        didSet {
            if readModeActive != oldValue {
                reloadInputViews()
            }
        }
    }

    // Cached empty view for keyboard suppression
    private lazy var emptyInputView: UIView = {
        let v = UIView(frame: .zero)
        return v
    }()

    // Override inputView to suppress keyboard in Read mode
    override var inputView: UIView? {
        get { readModeActive ? emptyInputView : nil }
        set { }  // Ignore sets
    }

    // Tracks whether a long-press is active for line-based selection
    private var longPressActive = false
    // The character range of the anchor line when long-press started
    private var longPressAnchorLineRange: NSRange?

    // Value scrub state
    private var scrubActive = false
    private var scrubRange: NSRange?
    private var scrubStartY: CGFloat = 0
    private var scrubOriginalValue: String = ""

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
        longPress.minimumPressDuration = 0.5
        longPress.delegate = self
        longPress.delaysTouchesBegan = true
        longPress.cancelsTouchesInView = false
        addGestureRecognizer(longPress)

        // Two-finger tap → Evaluate selected code (fast, no menu)
        let twoFingerTap = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap(_:)))
        twoFingerTap.numberOfTouchesRequired = 2
        twoFingerTap.delegate = self
        addGestureRecognizer(twoFingerTap)

        // Three-finger tap → Stop (context-aware)
        let threeFingerTap = UITapGestureRecognizer(target: self, action: #selector(handleThreeFingerTap(_:)))
        threeFingerTap.numberOfTouchesRequired = 3
        threeFingerTap.delegate = self
        addGestureRecognizer(threeFingerTap)

        // Double-tap → Enter Edit mode (when in Read mode)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        addGestureRecognizer(doubleTap)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended && readModeActive else { return }

        let location = gesture.location(in: self)
        let touchPosition = closestPosition(to: location) ?? beginningOfDocument
        let charIndex = offset(from: beginningOfDocument, to: touchPosition)

        // Check if tapped on a number — start value scrub
        if let numRange = findNumberAt(charIndex) {
            let nsText = text as NSString
            let valueStr = nsText.substring(with: numRange)
            let rect = rectForRange(numRange)
            let screenRect = convert(rect, to: window)

            // Highlight the number
            let highlight = NSMutableAttributedString(attributedString: attributedText)
            highlight.addAttribute(.backgroundColor, value: UIColor.orange.withAlphaComponent(0.3), range: numRange)
            attributedText = highlight

            scValueScrubStart?(numRange, valueStr, screenRect)
            return
        }

        // Not a number — do nothing in Read mode
        // (Edit mode is entered via the Edit button only, to prevent accidental entry)
    }

    // MARK: - Value Scrub

    /// Find a numeric literal at the given character index
    func findNumberAt(_ charIndex: Int) -> NSRange? {
        let nsText = text as NSString
        guard charIndex >= 0, charIndex < nsText.length else { return nil }

        // Check if char at index is part of a number
        let ch = nsText.character(at: charIndex)
        let isDigitOrDot = (ch >= 0x30 && ch <= 0x39) || ch == 0x2E  // 0-9 or .
        guard isDigitOrDot else { return nil }

        // Expand left
        var start = charIndex
        while start > 0 {
            let prev = nsText.character(at: start - 1)
            let isNum = (prev >= 0x30 && prev <= 0x39) || prev == 0x2E || prev == 0x2D  // 0-9, ., -
            if !isNum { break }
            start -= 1
        }

        // Expand right
        var end = charIndex + 1
        while end < nsText.length {
            let next = nsText.character(at: end)
            let isNum = (next >= 0x30 && next <= 0x39) || next == 0x2E
            if !isNum { break }
            end += 1
        }

        let range = NSRange(location: start, length: end - start)
        let str = nsText.substring(with: range)

        // Validate it's actually a number
        guard Double(str) != nil else { return nil }
        return range
    }

    /// Get the bounding rect for a character range
    func rectForRange(_ range: NSRange) -> CGRect {
        guard let start = position(from: beginningOfDocument, offset: range.location),
              let end = position(from: start, offset: range.length),
              let textRange = self.textRange(from: start, to: end) else {
            return .zero
        }
        return firstRect(for: textRange)
    }

    /// Try to start a value scrub at the given point (read mode only)
    func tryStartScrub(at point: CGPoint) -> Bool {
        guard readModeActive else { return false }

        let charIndex = layoutManager.characterIndex(
            for: point, in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        guard let numRange = findNumberAt(charIndex) else { return false }

        let nsText = text as NSString
        let valueStr = nsText.substring(with: numRange)
        let rect = rectForRange(numRange)

        // Convert to screen coordinates
        let screenRect = convert(rect, to: window)

        scrubActive = true
        scrubRange = numRange
        scrubStartY = point.y
        scrubOriginalValue = valueStr

        // Highlight the number
        let highlight = NSMutableAttributedString(attributedString: attributedText)
        highlight.addAttribute(.backgroundColor, value: UIColor.orange.withAlphaComponent(0.3), range: numRange)
        attributedText = highlight

        scValueScrubStart?(numRange, valueStr, screenRect)
        return true
    }

    @objc private func handleTwoFingerTap(_ gesture: UITapGestureRecognizer) {
        if gesture.state == .ended {
            // Use AppState.lastSelection (persists after focus loss) rather than
            // the live selectedTextRange which may already be nil.
            let saved = scGetSelectedText?() ?? ""
            if !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                scEvaluateCallback?(saved)
            } else {
                // No selection — evaluate entire buffer
                scEvaluateCallback?(text ?? "")
            }
        }
    }

    @objc private func handleThreeFingerTap(_ gesture: UITapGestureRecognizer) {
        if gesture.state == .ended {
            // Always stop all — CmdPeriod is the most reliable stop mechanism
            scStopCallback?()
        }
    }

    // MARK: - Shake (fires when this view IS first responder)
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            scStopCallback?()
        } else {
            super.motionEnded(motion, with: event)
        }
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: self)

        switch gesture.state {
        case .began:
            longPressActive = true

            // Save content offset so UITextView's selectedRange assignment can't scroll the view
            let savedOffset = contentOffset

            // Accurate touch-to-character mapping via UITextInput API
            let touchPosition = closestPosition(to: location) ?? beginningOfDocument
            let charIndex = offset(from: beginningOfDocument, to: touchPosition)

            // Clear any stale selection at the touch point before block-finding
            setSelectedRangeWithoutScrolling(NSRange(location: charIndex, length: 0), savedOffset: savedOffset)

            // Try to find enclosing ( ... ) block first
            if let blockRange = findEnclosingBlock(at: charIndex) {
                longPressAnchorLineRange = blockRange
                setSelectedRangeWithoutScrolling(blockRange, savedOffset: savedOffset)
            } else {
                // No block found — select current line
                let anchorRange = lineRange(at: charIndex)
                longPressAnchorLineRange = anchorRange
                if let r = anchorRange {
                    setSelectedRangeWithoutScrolling(r, savedOffset: savedOffset)
                }
            }

        case .changed:
            guard longPressActive, let anchor = longPressAnchorLineRange else { return }

            let savedOffset = contentOffset

            let touchPosition = closestPosition(to: location) ?? beginningOfDocument
            let charIndex = offset(from: beginningOfDocument, to: touchPosition)
            let currentRange = lineRange(at: charIndex)
            guard let current = currentRange else { return }

            let start = min(anchor.location, current.location)
            let end = max(
                anchor.location + anchor.length,
                current.location + current.length
            )
            setSelectedRangeWithoutScrolling(NSRange(location: start, length: end - start), savedOffset: savedOffset)

        case .ended, .cancelled, .failed:
            longPressActive = false
            longPressAnchorLineRange = nil
            // Selection persists because isEditable=true (editing blocked by delegate)

            // Reset horizontal scroll to prevent content sliding off screen
            if contentOffset.x != 0 {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                setContentOffset(CGPoint(x: 0, y: contentOffset.y), animated: false)
                CATransaction.commit()
            }

        default:
            break
        }
    }

    private var scrollLockOffset: CGPoint?
    private var scrollLockFrames = 0

    /// Sets selectedRange while suppressing the automatic scroll UITextView triggers.
    private func setSelectedRangeWithoutScrolling(_ range: NSRange, savedOffset: CGPoint) {
        let shouldLock = !UserDefaults.standard.bool(forKey: "sc_scroll_to_selection")

        if shouldLock {
            // Lock the scroll position for several frames to defeat UITextView's
            // multiple deferred scroll-to-selection passes
            scrollLockOffset = savedOffset
            scrollLockFrames = 6  // ~100ms at 60fps
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        selectedRange = range
        contentOffset = savedOffset
        CATransaction.commit()

        if shouldLock {
            // Keep restoring for several frames
            func restoreOffset(_ count: Int) {
                guard count > 0 else {
                    self.scrollLockOffset = nil
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, let locked = self.scrollLockOffset else { return }
                    self.setContentOffset(locked, animated: false)
                    restoreOffset(count - 1)
                }
            }
            restoreOffset(scrollLockFrames)
        }
    }

    /// Find the enclosing SC evaluation block around a character index.
    ///
    /// In SuperCollider, an evaluation block is delimited by `(` and `)` that are
    /// each the ONLY non-whitespace character on their respective lines.  However,
    /// we must count ALL parentheses (including inline ones like `Pbind(`, `Pseq(`)
    /// to correctly track nesting depth — the bare-line `(` / `)` are only the
    /// *boundaries*, not the only parens in the document.
    ///
    /// Algorithm:
    ///   Backward pass  — scan char-by-char from touch point toward start of text,
    ///     tracking full paren depth.  When we encounter a `(` that brings depth
    ///     to 0 AND is the only non-whitespace on its line → that is the block open.
    ///   Forward pass   — scan char-by-char from touch point toward end of text,
    ///     tracking full paren depth.  When we encounter a `)` that brings depth
    ///     to 0 AND is the only non-whitespace on its line → that is the block close.
    ///
    /// Parens inside line comments (`// …`), block comments (`/* … */`), double-quoted
    /// strings, and single-quoted symbols are ignored.
    private func findEnclosingBlock(at charIndex: Int) -> NSRange? {
        guard let fullText = text, !fullText.isEmpty else { return nil }
        let chars = Array(fullText.unicodeScalars)
        let totalLength = chars.count
        guard totalLength > 0 else { return nil }

        let idx = min(charIndex, totalLength - 1)

        // MARK: helpers

        /// Return true if the character at position `p` is the only non-whitespace
        /// character on its line.  Also returns the (start, end) byte offsets of that
        /// line (end is exclusive, includes the newline if present).
        func isAloneOnLine(_ p: Int) -> (alone: Bool, lineStart: Int, lineEnd: Int) {
            // Walk backward to find line start
            var ls = p
            while ls > 0 {
                let prev = chars[ls - 1]
                if prev == "\n" || prev == "\r" { break }
                ls -= 1
            }
            // Walk forward from line start to find line end (position just after newline)
            var lineEnd = ls
            while lineEnd < totalLength {
                let c = chars[lineEnd]
                if c == "\n" { lineEnd += 1; break }
                if c == "\r" {
                    lineEnd += 1
                    if lineEnd < totalLength && chars[lineEnd] == "\n" { lineEnd += 1 }
                    break
                }
                lineEnd += 1
            }
            // Check that p is the only non-whitespace char on [ls, lineEnd)
            var alone = true
            for i in ls..<lineEnd {
                let c = chars[i]
                if c == " " || c == "\t" || c == "\r" || c == "\n" { continue }
                if i != p { alone = false; break }
            }
            return (alone, ls, lineEnd)
        }

        // MARK: Backward scan to find block open

        // We walk backwards character by character, adjusting depth for every real
        // `(` and `)` we encounter (skipping those inside comments/strings).
        // When depth reaches 0 on a `(` that is alone on its line, that's our open.

        /// Classify the character at position `p` considering context.
        /// Returns the "real" character if it's a paren that should count, or nil.
        /// For the backward pass we need to know whether a given position is inside
        /// a comment or string — we do that with a lightweight forward pre-scan.

        // Build a boolean array: isInert[i] == true means the char at i is inside
        // a comment or string literal and should NOT be counted as a paren.
        var isInert = [Bool](repeating: false, count: totalLength)
        do {
            var i = 0
            while i < totalLength {
                let c = chars[i]
                // Line comment: // … \n
                if c == "/" && i + 1 < totalLength && chars[i + 1] == "/" {
                    let start = i
                    i += 2
                    while i < totalLength && chars[i] != "\n" { i += 1 }
                    // mark start..<i as inert (don't include the newline itself)
                    for k in start..<i { isInert[k] = true }
                    continue
                }
                // Block comment: /* … */
                if c == "/" && i + 1 < totalLength && chars[i + 1] == "*" {
                    let start = i
                    i += 2
                    while i + 1 < totalLength {
                        if chars[i] == "*" && chars[i + 1] == "/" { i += 2; break }
                        i += 1
                    }
                    for k in start..<i { isInert[k] = true }
                    continue
                }
                // Double-quoted string "…"  (SC strings don't span lines in practice)
                if c == "\"" {
                    let start = i
                    i += 1
                    while i < totalLength {
                        if chars[i] == "\\" { i += 2; continue } // escape
                        if chars[i] == "\"" { i += 1; break }
                        i += 1
                    }
                    for k in start..<i { isInert[k] = true }
                    continue
                }
                // Single-quoted symbol '…'
                if c == "'" {
                    let start = i
                    i += 1
                    while i < totalLength {
                        if chars[i] == "\\" { i += 2; continue }
                        if chars[i] == "'" { i += 1; break }
                        i += 1
                    }
                    for k in start..<i { isInert[k] = true }
                    continue
                }
                i += 1
            }
        }

        // MARK: Backward pass

        var blockStartPos: Int? = nil
        var depth = 0

        var p = idx
        while p >= 0 {
            if !isInert[p] {
                let c = chars[p]
                if c == ")" {
                    depth += 1
                } else if c == "(" {
                    if depth == 0 {
                        // Candidate: is it alone on its line?
                        let info = isAloneOnLine(p)
                        if info.alone {
                            blockStartPos = info.lineStart
                            break
                        }
                        // Not alone on its line → cannot be a SC block open;
                        // depth stays 0 and we keep scanning backward.
                    } else {
                        depth -= 1
                    }
                }
            }
            p -= 1
        }

        guard let startLineStart = blockStartPos else { return nil }

        // MARK: Forward pass

        var blockEndPos: Int? = nil
        depth = 0

        p = idx
        while p < totalLength {
            if !isInert[p] {
                let c = chars[p]
                if c == "(" {
                    depth += 1
                } else if c == ")" {
                    if depth == 0 {
                        let info = isAloneOnLine(p)
                        if info.alone {
                            blockEndPos = info.lineEnd
                            break
                        }
                        // Not alone on its line — regular close paren, depth goes negative;
                        // clamp to 0 so we keep scanning for the real block close.
                        // (depth was 0 and this paren is not a bare-line one, so it is an
                        //  unmatched inline `)` relative to our scan start — ignore it.)
                    } else {
                        depth -= 1
                    }
                }
            }
            p += 1
        }

        guard let endPos = blockEndPos else { return nil }
        guard endPos > startLineStart else { return nil }

        return NSRange(location: startLineStart, length: endPos - startLineStart)
    }

    /// Returns the NSRange of the full line (including newline) that contains the given character index.
    private func lineRange(at charIndex: Int) -> NSRange? {
        guard let fullText = text as NSString? else { return nil }
        let totalLength = fullText.length
        guard totalLength > 0 else { return nil }

        let clampedIndex = min(charIndex, totalLength - 1)
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
            // No selection — evaluate entire text
            scEvaluateCallback?(text ?? "")
        }
    }

    /// Snapshot current selection for the Play button (called before focus is lost)
    func snapshotSelectionForPlay() -> String {
        if let range = selectedTextRange, !range.isEmpty {
            return text(in: range) ?? ""
        }
        return ""  // No selection
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
    var isEditable: Bool = true
    var onEvaluate: (() -> Void)?
    var onEvaluateCode: ((String) -> Void)?
    var onStop: (() -> Void)?
    var onSelectionChanged: ((String) -> Void)?
    var onDoubleTap: (() -> Void)?
    var onScrubStart: ((NSRange, String, CGRect) -> Void)?
    var onScrubUpdate: ((Double) -> Void)?
    var onScrubEnd: (() -> Void)?

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

        // Wire up selection closures
        scGetSelectedText = { [weak textView] in
            textView?.getSelectedText() ?? ""
        }
        scSnapshotSelection = { [weak textView] in
            textView?.snapshotSelectionForPlay() ?? ""
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

        // Read/Edit mode: control whether text is editable
        // Always keep isEditable=true so UITextView maintains selection.
        // We block actual text changes in Read mode via shouldChangeTextIn delegate.
        // Keyboard is suppressed in Read mode via inputView override.
        textView.isEditable = true
        textView.readModeActive = !isEditable
        context.coordinator.allowEditing = isEditable

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
        scSnapshotSelection = { [weak textView] in
            textView?.snapshotSelectionForPlay() ?? ""
        }
        scDoubleTapCallback = onDoubleTap
        scValueScrubStart = onScrubStart
        scValueScrubUpdate = onScrubUpdate
        scValueScrubEnd = onScrubEnd

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
        /// When false, blocks text editing (Read mode) while keeping isEditable=true
        /// so UITextView maintains text selection properly
        var allowEditing: Bool = true
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

        // Block text changes in Read mode (isEditable stays true for selection)
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            return allowEditing
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
            // Defer to next run loop to avoid "Publishing changes from within view updates"
            let callback = onSelectionChanged
            DispatchQueue.main.async {
                callback?(selected)
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            // Defer binding update to avoid "Publishing changes from within view updates"
            let newText = textView.text ?? ""
            DispatchQueue.main.async { [weak self] in
                self?.text.wrappedValue = newText
            }

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
