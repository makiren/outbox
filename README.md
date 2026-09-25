# Outbox

**A scratchpad that disappears when you copy.**

Outbox is a tiny menu-bar app for macOS. Press a hotkey, write the long Slack message or AI-chat prompt you did not want to type into a cramped input box, press **⌘⏎**, and the text is on your clipboard, pasted back into the app you came from, and the panel is gone.

That is the whole idea: a buffer that sits in front of the clipboard. Write → copy → gone.

![Outbox panel](docs/screenshot.png)

## Why

Chat inputs are a bad place to write anything longer than two lines. Enter sends by accident, the box is small, and a reload eats your draft. Notes apps solve the writing part but then you have to select, copy, switch, paste, and go back to delete the note.

Outbox collapses that into one keystroke each way.

## How it works

- **⌃⌥Space** opens a floating panel with your draft (or an empty one). Outbox becomes the active app while the panel is open.
- **⌘C** or **⌘X** with *nothing selected* copies or cuts the *whole* text and closes the panel. With a selection they behave normally. **⌘⏎** and **⇧⌘⏎** do the same regardless of selection.
- On close, focus goes back to the app you came from, and Outbox sends **⌘V** there (optional, needs Accessibility permission).
- **Esc** hides the panel and keeps the draft. The draft is saved to disk as you type, so it survives restarts.

| Action | Shortcut |
| --- | --- |
| Open / hide the panel | ⌃⌥Space |
| Copy everything and close | ⌘⏎, or ⌘C with no selection |
| Cut everything and close | ⇧⌘⏎, or ⌘X with no selection |
| Hide and keep the draft | Esc or ⌘W |
| Quit | ⌘Q from the menu-bar icon |

## Install

Requires macOS 13 or later. The release build is a universal binary (Apple Silicon and Intel).

1. Download `Outbox-<version>.zip` from [Releases](../../releases) and unzip it.
2. Move `Outbox.app` to `/Applications` and open it. An icon appears in the menu bar. Nothing appears in the Dock.
3. Optional: add Outbox to **System Settings → General → Login Items** so it starts at login.

### "Apple could not verify Outbox"

Outbox is signed ad hoc, not notarized, so Gatekeeper refuses it on first launch. Either

- open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**, or
- clear the quarantine flag in a terminal:

```sh
xattr -dr com.apple.quarantine /Applications/Outbox.app
```

### Paste-back needs Accessibility

The first time you press ⌘⏎, macOS asks for Accessibility permission so Outbox can send ⌘V to the previous app. Grant it under **System Settings → Privacy & Security → Accessibility**. Without it, the text is still on the clipboard; you just paste yourself. Paste-back can be turned off from the menu-bar icon.

## Configuration

There is no settings window. Everything is a `defaults` key. Restart Outbox after changing the hotkey.

| Key | Default | Meaning |
| --- | --- | --- |
| `pasteBack` | `true` | Send ⌘V to the previous app after copying |
| `monospace` | `false` | Use the system monospaced font instead of SF Pro |
| `hotKeyCode` | `49` (Space) | Virtual key code of the hotkey |
| `hotKeyModifiers` | `6144` (⌃⌥) | Carbon modifier mask: ⌘ 256, ⇧ 512, ⌥ 2048, ⌃ 4096. Add them up. |

```sh
# Example: ⌥⌘Space
defaults write tokyo.initie.outbox hotKeyCode -int 49
defaults write tokyo.initie.outbox hotKeyModifiers -int 2304

# Monospaced font
defaults write tokyo.initie.outbox monospace -bool true
```

The draft lives at `~/Library/Application Support/Outbox/draft.md`.

## Build from source

Xcode command line tools are enough. No third-party dependencies.

```sh
git clone https://github.com/makiren/outbox.git
cd outbox
make install      # builds, copies to /Applications, launches
```

Other targets: `make app` (bundle in `build/`), `make run`, `make release` (universal binary + zip), `make clean`.

The code is about 700 lines of Swift:

| File | Role |
| --- | --- |
| `Sources/Outbox/AppDelegate.swift` | Menu bar item, show/hide, activation hand-off, commit |
| `Sources/Outbox/OutboxPanel.swift` | Borderless vibrancy panel and layout |
| `Sources/Outbox/OutboxTextView.swift` | Copy/cut-to-close logic, shortcuts, placeholder |
| `Sources/Outbox/HotKey.swift` | Global hotkey via Carbon `RegisterEventHotKey` |
| `Sources/Outbox/PasteBack.swift` | ⌘V via `CGEvent` |
| `Sources/Outbox/DraftStore.swift` | Debounced draft persistence |

## Non-goals

Outbox is not a notes app. One draft, no list, no sync, no formatting toolbar. If you want to keep what you wrote, keep it where you pasted it.

## 日本語

Slack や AI チャットに長文を送る前に、いったん書いておくための常駐パッドです。

- **⌃⌥Space** でパネルを開く
- 書いて **⌘⏎**（または選択なしで ⌘C / ⌘X）→ 全文がクリップボードに入り、直前のアプリに貼り付けられ、パネルが消える
- **Esc** で下書きを残したまま閉じる。下書きは自動保存

初回起動時に「開発元を確認できない」と出たら、**システム設定 → プライバシーとセキュリティ** の「このまま開く」を押すか、`xattr -dr com.apple.quarantine /Applications/Outbox.app` を実行してください。貼り戻しにはアクセシビリティの許可が必要です。ホットキーやフォントの変更は上の Configuration を参照。

## License

[MIT](LICENSE)
