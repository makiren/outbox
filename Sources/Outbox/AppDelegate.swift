import AppKit
import Carbon

enum CommitKind {
    case copy
    case cut
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    private var panel: OutboxPanel!
    private var draftStore: DraftStore!
    private var hotKey: HotKey?
    private var statusItem: NSStatusItem?
    private var hadSavedFrame = false
    private var hasShownOnce = false
    private var previousApp: NSRunningApplication?

    private var textView: OutboxTextView {
        return panel.textView
    }

    private var pasteBack: Bool {
        return UserDefaults.standard.bool(forKey: "pasteBack")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // Register defaults
        UserDefaults.standard.register(defaults: ["pasteBack": true, "monospace": false])

        // Build minimal main menu
        buildMainMenu()

        // Create status item
        createStatusItem()

        // Create draft store
        draftStore = DraftStore()

        // Create panel (check for a saved frame first: autosave writes the initial frame immediately)
        hadSavedFrame = UserDefaults.standard.object(forKey: "NSWindow Frame OutboxPanel") != nil
        panel = OutboxPanel()
        setupTextViewCallbacks()

        // Load draft
        let draft = draftStore.load()
        textView.string = draft
        textView.applyDefaultAttributes()
        panel.updateCounter()

        // Register hotkey
        registerHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        draftStore?.flush()
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.title = "Outbox"
        appMenuItem.submenu = appMenu

        let quitItem = NSMenuItem(title: "Quit Outbox", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quitItem)

        mainMenu.addItem(appMenuItem)

        // Edit menu
        let editMenu = NSMenu()
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        editMenuItem.title = "Edit"

        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "tray.and.arrow.up", accessibilityDescription: "Outbox") {
                image.isTemplate = true
                button.image = image
            }
        }

        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open Outbox", action: #selector(show), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        let pasteBackItem = NSMenuItem(title: "Paste back after copy", action: #selector(togglePasteBack), keyEquivalent: "")
        pasteBackItem.target = self
        pasteBackItem.state = pasteBack ? .on : .off
        menu.addItem(pasteBackItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Outbox", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func togglePasteBack() {
        let newValue = !pasteBack
        UserDefaults.standard.set(newValue, forKey: "pasteBack")

        if let menu = statusItem?.menu, let item = menu.items.first(where: { $0.title == "Paste back after copy" }) {
            item.state = newValue ? .on : .off
        }
    }

    private func registerHotKey() {
        // Read hotkey from UserDefaults (Carbon keyCode and modifiers)
        // Default: ⌃⌥Space (keyCode 49, modifiers controlKey|optionKey = 6144). ⌥Space collides with Alfred.
        var keyCode = UInt32(UserDefaults.standard.integer(forKey: "hotKeyCode"))
        var modifiers = UInt32(UserDefaults.standard.integer(forKey: "hotKeyModifiers"))

        if keyCode == 0 {
            keyCode = 49 // kVK_Space
        }
        if modifiers == 0 {
            modifiers = 4096 | 2048 // controlKey | optionKey
        }

        hotKey = HotKey(keyCode: keyCode, modifiers: modifiers) { [weak self] in
            DispatchQueue.main.async {
                self?.toggle()
            }
        }
    }

    private func setupTextViewCallbacks() {
        textView.onCommit = { [weak self] kind in
            self?.commit(kind)
        }

        textView.onEscape = { [weak self] in
            self?.hide()
        }

        textView.onChange = { [weak self] in
            self?.panel.updateCounter()
            self?.draftStore.scheduleSave(self?.textView.string ?? "")
        }
    }

    @objc func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    @objc func show() {
        // Save previous frontmost app before activating
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = front
        }

        // First show with no autosaved frame: center on the screen containing the mouse
        if !hasShownOnce && !hadSavedFrame {
            let mouseLocation = NSEvent.mouseLocation
            let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main

            if let screen = screen {
                let screenFrame = screen.visibleFrame
                let panelSize = panel.frame.size

                let x = screenFrame.origin.x + (screenFrame.width - panelSize.width) / 2
                let y = screenFrame.origin.y + (screenFrame.height - panelSize.height) / 2

                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }

        hasShownOnce = true
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textView)
        activateSelf()

        // Move caret to end
        let length = textView.string.utf16.count
        textView.setSelectedRange(NSRange(location: length, length: 0))
        panel.fadeIn()
    }

    func hide() {
        draftStore.flush()
        panel.orderOut(nil)
        restorePreviousApp()
    }

    /// macOS 14+ cooperative activation refuses self-activation from a background app,
    /// but LaunchServices honors an activation request coming from another process,
    /// so ask `/usr/bin/open` to bring us forward (same path as `open -a Outbox`).
    private func activateSelf() {
        let url = Bundle.main.bundleURL
        guard url.pathExtension == "app" else {
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-a", url.path]
        proc.standardOutput = nil
        proc.standardError = nil
        try? proc.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, self.panel.isVisible else { return }
            self.panel.makeKeyAndOrderFront(nil)
            self.panel.makeFirstResponder(self.textView)
        }
    }

    /// The self-open above arrives here as a reopen; ignore it so show() does not recurse.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return false
    }

    private func restorePreviousApp() {
        guard let prev = previousApp else { return }
        if #available(macOS 14.0, *) {
            NSApp.yieldActivation(to: prev)
            prev.activate()
        } else {
            prev.activate(options: [.activateIgnoringOtherApps])
        }
    }

    func commit(_ kind: CommitKind) {
        draftStore.flush()
        hide()

        if pasteBack {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                PasteBack.postCommandV()
            }
        }
    }
}
