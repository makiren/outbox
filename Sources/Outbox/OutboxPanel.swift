import AppKit

final class OutboxPanel: NSPanel {
    let textView: OutboxTextView
    private(set) var counterField: NSTextField
    private var hintField: NSTextField!

    init() {
        // init(frame:) builds the text storage/layout/container network; init(frame:textContainer: nil) does not
        self.textView = OutboxTextView.make(frame: NSRect(x: 0, y: 0, width: 664, height: 352))
        self.counterField = NSTextField(labelWithString: "0 chars · 0 lines")

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 400),
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        isFloatingPanel = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .none
        minSize = NSSize(width: 420, height: 220)
        setFrameAutosaveName("OutboxPanel")

        let effectView = RoundedEffectView()
        self.contentView = effectView

        setupViews(inside: effectView)
    }

    private func setupViews(inside parent: RoundedEffectView) {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // documentView must use autoresizing (not Auto Layout) so it tracks the clip view width
        textView.frame = NSRect(x: 0, y: 0, width: 664, height: 352)
        scrollView.documentView = textView

        parent.addSubview(scrollView)

        hintField = NSTextField(labelWithString: "⌘⏎ copy & close    ⇧⌘⏎ cut & close    esc hide")
        hintField.font = .systemFont(ofSize: 11)
        hintField.textColor = .tertiaryLabelColor
        hintField.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(hintField)

        counterField.font = .systemFont(ofSize: 11)
        counterField.textColor = .tertiaryLabelColor
        counterField.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(counterField)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: parent.topAnchor, constant: 14),
            scrollView.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -34),

            hintField.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: 20),
            hintField.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -11),

            counterField.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -20),
            counterField.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -11)
        ])

        updateCounter()
    }

    func updateCounter() {
        let text = textView.string
        let chars = text.utf16.count
        let lines = text.isEmpty ? 0 : text.components(separatedBy: .newlines).count

        counterField.stringValue = "\(chars) chars · \(lines) lines"
    }

    func fadeIn() {
        alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - RoundedEffectView

final class RoundedEffectView: NSVisualEffectView {
    init() {
        super.init(frame: .zero)
        material = .popover
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        updateBorderColor()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBorderColor()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateBorderColor()
    }

    private func updateBorderColor() {
        if effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            layer?.borderColor = NSColor(white: 1, alpha: 0.14).cgColor
        } else {
            layer?.borderColor = NSColor(white: 0, alpha: 0.08).cgColor
        }
    }
}
