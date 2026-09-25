import AppKit

final class OutboxTextView: NSTextView {
    var onCommit: ((CommitKind) -> Void)?
    var onEscape: (() -> Void)?
    var onChange: (() -> Void)?

    /// The text view only holds the container; the storage must be kept alive by us.
    private var ownedStorage: NSTextStorage?

    /// Builds the text storage → layout manager → container network explicitly.
    /// `init(frame:textContainer: nil)` creates NO text system, so typing would go nowhere.
    static func make(frame: NSRect) -> OutboxTextView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: frame.width, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        let view = OutboxTextView(frame: frame, textContainer: container)
        view.ownedStorage = storage
        return view
    }

    override init(frame: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frame, textContainer: container)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    static var preferredFont: NSFont {
        UserDefaults.standard.bool(forKey: "monospace")
            ? .monospacedSystemFont(ofSize: 14, weight: .regular)
            : .systemFont(ofSize: 15)
    }

    private func setup() {
        isRichText = false
        drawsBackground = false
        textColor = .labelColor
        insertionPointColor = .controlAccentColor
        allowsUndo = true
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        smartInsertDeleteEnabled = false
        textContainerInset = NSSize(width: 12, height: 8)
        isVerticallyResizable = true
        isHorizontallyResizable = false
        autoresizingMask = [.width]
        minSize = NSSize(width: 0, height: 0)
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        let font = Self.preferredFont
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 4
        defaultParagraphStyle = ps
        self.font = font
        typingAttributes = [.font: font, .paragraphStyle: ps, .foregroundColor: NSColor.labelColor]

        if let container = textContainer {
            container.widthTracksTextView = true
            container.size = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        }
    }

    func applyDefaultAttributes() {
        guard let storage = textStorage else { return }
        storage.setAttributes(typingAttributes, range: NSRange(location: 0, length: storage.length))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if string.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [.font: Self.preferredFont, .foregroundColor: NSColor.placeholderTextColor]
            let point = NSPoint(
                x: textContainerInset.width + (textContainer?.lineFragmentPadding ?? 5),
                y: textContainerInset.height
            )
            ("Write here, then ⌘⏎" as NSString).draw(at: point, withAttributes: attrs)
        }
    }

    override func copy(_ sender: Any?) {
        if selectedRange().length == 0 && !string.isEmpty {
            let caret = selectedRange()
            selectAll(nil)
            super.copy(sender)
            setSelectedRange(caret)
            onCommit?(.copy)
        } else {
            super.copy(sender)
        }
    }

    override func cut(_ sender: Any?) {
        if selectedRange().length == 0 && !string.isEmpty {
            selectAll(nil)
            super.cut(sender)
            onCommit?(.cut)
        } else {
            super.cut(sender)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // ⌘A - Select All
        if modifiers == .command && event.keyCode == 0 {
            selectAll(nil)
            return true
        }

        // ⌘C - Copy
        if modifiers == .command && event.keyCode == 8 {
            copy(nil)
            return true
        }

        // ⌘X - Cut
        if modifiers == .command && event.keyCode == 7 {
            cut(nil)
            return true
        }

        // ⌘V - Paste
        if modifiers == .command && event.keyCode == 9 {
            paste(nil)
            return true
        }

        // ⌘Z - Undo
        if modifiers == .command && event.keyCode == 6 {
            undoManager?.undo()
            return true
        }

        // ⇧⌘Z - Redo
        if modifiers == [.command, .shift] && event.keyCode == 6 {
            undoManager?.redo()
            return true
        }

        // ⌘⏎ (Return, keyCode 36) - Copy all and commit
        if modifiers == .command && event.keyCode == 36 {
            if !string.isEmpty {
                let caret = selectedRange()
                selectAll(nil)
                super.copy(nil)
                setSelectedRange(caret)
                onCommit?(.copy)
            }
            return true
        }

        // ⇧⌘⏎ - Cut all and commit
        if modifiers == [.command, .shift] && event.keyCode == 36 {
            if !string.isEmpty {
                selectAll(nil)
                super.cut(nil)
                onCommit?(.cut)
            }
            return true
        }

        // ⌘W - Escape/Close
        if modifiers == .command && event.keyCode == 13 {
            onEscape?()
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    override func didChangeText() {
        super.didChangeText()
        onChange?()
        needsDisplay = true
    }
}
