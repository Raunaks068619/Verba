import AppKit
import SwiftUI

struct NotesRichTextEditor: NSViewRepresentable {
    @ObservedObject var store: VoiceNoteStore

    static let textInset = CGSize(width: 10, height: 10)

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = NotesRichNSTextView(frame: .zero)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = Self.textInset
        textView.textContainer?.lineFragmentPadding = 0
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.defaultParagraphStyle = VoiceNoteStore.defaultParagraphStyle
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.font = VoiceNoteStore.defaultFont
        textView.typingAttributes = VoiceNoteStore.defaultTypingAttributes
        textView.delegate = context.coordinator
        textView.textStorage?.delegate = context.coordinator

        context.coordinator.textView = textView
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NotesRichNSTextView else { return }
        guard !textView.attributedString().isEqual(to: store.activeContent) else { return }

        let selectedRange = textView.selectedRange()
        context.coordinator.isApplyingExternalChange = true
        textView.textStorage?.setAttributedString(VoiceNoteStore.normalizedContent(store.activeContent))
        textView.typingAttributes = VoiceNoteStore.normalizedTypingAttributes(textView.typingAttributes)
        textView.setSelectedRange(clamped(range: selectedRange, in: textView.string))
        context.coordinator.isApplyingExternalChange = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func clamped(range: NSRange, in string: String) -> NSRange {
        let length = (string as NSString).length
        let location = min(range.location, length)
        let remaining = max(length - location, 0)
        return NSRange(location: location, length: min(range.length, remaining))
    }

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var parent: NotesRichTextEditor
        weak var textView: NotesRichNSTextView?
        var isApplyingExternalChange = false

        init(parent: NotesRichTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            pushUpdate()
        }

        func textStorage(
            _ textStorage: NSTextStorage,
            didProcessEditing editedMask: NSTextStorageEditActions,
            range editedRange: NSRange,
            changeInLength delta: Int
        ) {
            guard editedMask.contains(.editedAttributes) else { return }
            pushUpdate()
        }

        private func pushUpdate() {
            guard !isApplyingExternalChange, let textView else { return }
            let rawContent = NSAttributedString(attributedString: textView.attributedString())
            let content = VoiceNoteStore.normalizedContent(rawContent)
            normalizeEditorIfNeeded(textView: textView, normalizedContent: content)
            DispatchQueue.main.async { [parent] in
                parent.store.updateActiveContent(content)
            }
        }

        private func normalizeEditorIfNeeded(
            textView: NotesRichNSTextView,
            normalizedContent: NSAttributedString
        ) {
            guard !textView.attributedString().isEqual(to: normalizedContent) else {
                textView.typingAttributes = VoiceNoteStore.normalizedTypingAttributes(textView.typingAttributes)
                return
            }

            let selectedRange = textView.selectedRange()
            let textLength = (normalizedContent.string as NSString).length
            let location = min(selectedRange.location, textLength)
            let length = min(selectedRange.length, max(textLength - location, 0))

            isApplyingExternalChange = true
            textView.textStorage?.setAttributedString(normalizedContent)
            textView.typingAttributes = VoiceNoteStore.normalizedTypingAttributes(textView.typingAttributes)
            textView.setSelectedRange(NSRange(location: location, length: length))
            isApplyingExternalChange = false
        }
    }
}

final class NotesRichNSTextView: NSTextView {
    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            NotesEditorFocus.textView = self
        }
        return became
    }

    override func mouseDown(with event: NSEvent) {
        NotesEditorFocus.textView = self
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        NotesEditorFocus.textView = self

        if handleCommandShortcut(event) {
            return
        }

        if event.keyCode == 48 {
            if event.modifierFlags.contains(.shift) {
                outdentCurrentLine()
            } else {
                insertText("\t", replacementRange: selectedRange())
            }
            return
        }

        super.keyDown(with: event)
    }

    override func insertNewline(_ sender: Any?) {
        if continueListIfNeeded() {
            return
        }
        super.insertNewline(sender)
    }

    private func handleCommandShortcut(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else { return false }
        guard let key = event.charactersIgnoringModifiers?.lowercased() else { return false }

        switch key {
        case "b":
            NotesEditorFormatting.toggleBold()
        case "i":
            NotesEditorFormatting.toggleItalic()
        case "u":
            NotesEditorFormatting.toggleUnderline()
        case "k":
            NotesEditorFormatting.addLink()
        default:
            return false
        }

        return true
    }

    private func continueListIfNeeded() -> Bool {
        let selected = selectedRange()
        guard selected.length == 0 else { return false }
        guard let continuation = listContinuationBeforeCursor() else { return false }
        typingAttributes = VoiceNoteStore.normalizedTypingAttributes(typingAttributes)
        insertText(continuation, replacementRange: selected)
        return true
    }

    private func listContinuationBeforeCursor() -> String? {
        let nsString = string as NSString
        let cursor = min(selectedRange().location, nsString.length)
        let lineRange = nsString.lineRange(for: NSRange(location: cursor, length: 0))
        let beforeCursorLength = max(cursor - lineRange.location, 0)
        guard beforeCursorLength > 0 else { return nil }

        let beforeCursor = nsString.substring(
            with: NSRange(location: lineRange.location, length: beforeCursorLength)
        )

        if let numbered = numberedContinuation(for: beforeCursor) {
            return numbered
        }
        if let bulleted = bulletedContinuation(for: beforeCursor) {
            return bulleted
        }
        return nil
    }

    private func numberedContinuation(for line: String) -> String? {
        guard
            let match = firstMatch(pattern: #"^(\s*)(\d+)\.\s+(.+)$"#, in: line),
            let number = Int(capture(2, from: line, match: match))
        else {
            return nil
        }

        let content = capture(3, from: line, match: match)
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return "\n\(capture(1, from: line, match: match))\(number + 1). "
    }

    private func bulletedContinuation(for line: String) -> String? {
        guard let match = firstMatch(pattern: #"^(\s*)([•\-*])\s+(.+)$"#, in: line) else {
            return nil
        }

        let content = capture(3, from: line, match: match)
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return "\n\(capture(1, from: line, match: match))\(capture(2, from: line, match: match)) "
    }

    private func outdentCurrentLine() {
        guard let storage = textStorage else { return }
        let nsString = string as NSString
        let cursor = min(selectedRange().location, nsString.length)
        let lineRange = nsString.lineRange(for: NSRange(location: cursor, length: 0))
        guard lineRange.length > 0 else { return }

        let line = nsString.substring(with: lineRange)
        let removalLength: Int
        if line.hasPrefix("\t") {
            removalLength = 1
        } else {
            removalLength = min(line.prefix { $0 == " " }.count, 4)
        }

        guard removalLength > 0 else { return }
        let removeRange = NSRange(location: lineRange.location, length: removalLength)
        if shouldChangeText(in: removeRange, replacementString: "") {
            storage.replaceCharacters(in: removeRange, with: "")
            didChangeText()
        }
    }

    private func firstMatch(pattern: String, in line: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: (line as NSString).length)
        return regex.firstMatch(in: line, range: range)
    }

    private func capture(_ index: Int, from line: String, match: NSTextCheckingResult) -> String {
        let range = match.range(at: index)
        guard range.location != NSNotFound else { return "" }
        return (line as NSString).substring(with: range)
    }
}

private final class NotesEditorFocus {
    static weak var textView: NotesRichNSTextView?
}

struct NotesFormatToolbar: View {
    var body: some View {
        HStack(spacing: 3) {
            NotesToolbarButton(systemName: "bold", help: "Bold") {
                NotesEditorFormatting.toggleBold()
            }
            NotesToolbarButton(systemName: "italic", help: "Italic") {
                NotesEditorFormatting.toggleItalic()
            }
            NotesToolbarButton(systemName: "underline", help: "Underline") {
                NotesEditorFormatting.toggleUnderline()
            }
            NotesToolbarButton(systemName: "highlighter", help: "Highlight") {
                NotesEditorFormatting.toggleHighlight()
            }
            Rectangle()
                .fill(Theme.floatingControlForeground.opacity(0.14))
                .frame(height: 16)
                .frame(width: 1)
                .padding(.horizontal, 2)
            NotesToolbarButton(systemName: "list.bullet", help: "Bullet list") {
                NotesEditorFormatting.applyBullets()
            }
            NotesToolbarButton(systemName: "list.number", help: "Numbered list") {
                NotesEditorFormatting.applyNumbering()
            }
            NotesToolbarButton(systemName: "link", help: "Link selected text") {
                NotesEditorFormatting.addLink()
            }
            Rectangle()
                .fill(Theme.floatingControlForeground.opacity(0.14))
                .frame(height: 16)
                .frame(width: 1)
                .padding(.horizontal, 2)
            NotesToolbarButton(systemName: "textformat", help: "Clear formatting") {
                NotesEditorFormatting.clearFormatting()
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.RadiusExtra.input, style: .continuous)
                .fill(Theme.floatingControlFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusExtra.input, style: .continuous)
                .strokeBorder(Theme.floatingControlForeground.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct NotesToolbarButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.floatingControlForeground)
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .vfClickableCursor()
        .help(help)
    }
}

enum NotesEditorFormatting {
    static func toggleBold() {
        toggleFontTrait(.boldFontMask)
    }

    static func toggleItalic() {
        toggleFontTrait(.italicFontMask)
    }

    static func toggleUnderline() {
        guard let textView = focusedEditor else { return }
        let range = textView.selectedRange()
        if range.length == 0 {
            var attributes = VoiceNoteStore.normalizedTypingAttributes(textView.typingAttributes)
            if attributes[.underlineStyle] == nil {
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            } else {
                attributes.removeValue(forKey: .underlineStyle)
            }
            textView.typingAttributes = attributes
            return
        }

        let shouldApply = !rangeFullyHasAttribute(.underlineStyle, in: range, textView: textView)
        mutate(textView: textView) { storage in
            if shouldApply {
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            } else {
                storage.removeAttribute(.underlineStyle, range: range)
            }
        }
    }

    static func toggleHighlight() {
        guard let textView = focusedEditor else { return }
        let range = textView.selectedRange()
        let highlight = NSColor.systemYellow.withAlphaComponent(0.38)
        if range.length == 0 {
            var attributes = VoiceNoteStore.normalizedTypingAttributes(textView.typingAttributes)
            if attributes[.backgroundColor] == nil {
                attributes[.backgroundColor] = highlight
            } else {
                attributes.removeValue(forKey: .backgroundColor)
            }
            textView.typingAttributes = attributes
            return
        }

        let shouldApply = !rangeFullyHasAttribute(.backgroundColor, in: range, textView: textView)
        mutate(textView: textView) { storage in
            if shouldApply {
                storage.addAttribute(.backgroundColor, value: highlight, range: range)
            } else {
                storage.removeAttribute(.backgroundColor, range: range)
            }
        }
    }

    static func applyBullets() {
        applyLinePrefix { _ in "• " }
    }

    static func applyNumbering() {
        applyLinePrefix { index in "\(index + 1). " }
    }

    static func addLink() {
        guard let textView = focusedEditor else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else { return }

        let selectedText = (textView.string as NSString).substring(with: range)
        let pasteboardText = NSPasteboard.general.string(forType: .string) ?? ""
        guard let url = normalizedURL(from: selectedText) ?? normalizedURL(from: pasteboardText) else { return }

        mutate(textView: textView) { storage in
            storage.addAttribute(.link, value: url, range: range)
        }
    }

    static func clearFormatting() {
        guard let textView = focusedEditor else { return }
        let range = textView.selectedRange()
        if range.length == 0 {
            textView.typingAttributes = VoiceNoteStore.defaultTypingAttributes
            return
        }

        mutate(textView: textView) { storage in
            storage.setAttributes(VoiceNoteStore.defaultTypingAttributes, range: range)
        }
    }

    private static var focusedEditor: NotesRichNSTextView? {
        NotesEditorFocus.textView
    }

    private static func toggleFontTrait(_ trait: NSFontTraitMask) {
        guard let textView = focusedEditor else { return }
        let manager = NSFontManager.shared
        let range = textView.selectedRange()

        if range.length == 0 {
            var attributes = VoiceNoteStore.normalizedTypingAttributes(textView.typingAttributes)
            let currentFont = (attributes[.font] as? NSFont) ?? VoiceNoteStore.defaultFont
            let hasTrait = manager.traits(of: currentFont).contains(trait)
            attributes[.font] = hasTrait
                ? manager.convert(currentFont, toNotHaveTrait: trait)
                : manager.convert(currentFont, toHaveTrait: trait)
            textView.typingAttributes = attributes
            return
        }

        let shouldApply = !rangeFullyHasFontTrait(trait, in: range, textView: textView)
        mutate(textView: textView) { storage in
            storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
                let currentFont = (value as? NSFont) ?? VoiceNoteStore.defaultFont
                let converted = shouldApply
                    ? manager.convert(currentFont, toHaveTrait: trait)
                    : manager.convert(currentFont, toNotHaveTrait: trait)
                storage.addAttribute(.font, value: converted, range: subrange)
            }
        }
    }

    private static func rangeFullyHasFontTrait(
        _ trait: NSFontTraitMask,
        in range: NSRange,
        textView: NSTextView
    ) -> Bool {
        guard let storage = textView.textStorage else { return false }
        var allHaveTrait = true
        let manager = NSFontManager.shared
        storage.enumerateAttribute(.font, in: range) { value, _, stop in
            let font = (value as? NSFont) ?? VoiceNoteStore.defaultFont
            if !manager.traits(of: font).contains(trait) {
                allHaveTrait = false
                stop.pointee = true
            }
        }
        return allHaveTrait
    }

    private static func rangeFullyHasAttribute(
        _ key: NSAttributedString.Key,
        in range: NSRange,
        textView: NSTextView
    ) -> Bool {
        guard let storage = textView.textStorage else { return false }
        var allHaveAttribute = true
        storage.enumerateAttribute(key, in: range) { value, _, stop in
            if value == nil {
                allHaveAttribute = false
                stop.pointee = true
            }
        }
        return allHaveAttribute
    }

    private static func applyLinePrefix(_ prefix: (Int) -> String) {
        guard let textView = focusedEditor else { return }
        let nsString = textView.string as NSString
        let selectedRange = textView.selectedRange()
        let safeLocation = min(selectedRange.location, nsString.length)
        let safeLength = min(selectedRange.length, max(nsString.length - safeLocation, 0))
        let lineRange = nsString.lineRange(for: NSRange(location: safeLocation, length: safeLength))
        let original = nsString.substring(with: lineRange)
        let keepsTrailingNewline = original.hasSuffix("\n")
        var lines = original.components(separatedBy: "\n")
        if keepsTrailingNewline {
            lines.removeLast()
        }

        var nonEmptyIndex = 0
        let transformed = lines.enumerated().map { item in
            let line = item.element
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if selectedRange.length == 0, lines.count == 1 {
                    return prefix(0)
                }
                return line
            }
            let cleaned = line.replacingOccurrences(
                of: "^\\s*(•|[-*]|\\d+[\\.)])\\s+",
                with: "",
                options: .regularExpression
            )
            defer { nonEmptyIndex += 1 }
            return prefix(nonEmptyIndex) + cleaned
        }
        .joined(separator: "\n") + (keepsTrailingNewline ? "\n" : "")

        let attributes = VoiceNoteStore.normalizedTypingAttributes(textView.typingAttributes)
        let attributed = NSAttributedString(
            string: transformed,
            attributes: attributes
        )

        mutate(textView: textView) { storage in
            storage.replaceCharacters(in: lineRange, with: attributed)
        }
        textView.setSelectedRange(NSRange(location: lineRange.location, length: (transformed as NSString).length))
    }

    private static func mutate(textView: NSTextView, change: (NSTextStorage) -> Void) {
        guard let storage = textView.textStorage else { return }
        storage.beginEditing()
        change(storage)
        storage.endEditing()
        textView.didChangeText()
    }

    private static func normalizedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        guard trimmed.contains(".") else { return nil }
        return URL(string: "https://\(trimmed)")
    }
}
