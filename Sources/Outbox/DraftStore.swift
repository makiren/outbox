import Foundation

final class DraftStore {
    private let fileURL: URL
    private var pendingWorkItem: DispatchWorkItem?
    private var pendingText: String?

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupport.appendingPathComponent("Outbox")

        // Create directory if needed
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        fileURL = directory.appendingPathComponent("draft.md")
    }

    func load() -> String {
        guard let data = try? Data(contentsOf: fileURL) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    func save(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func scheduleSave(_ text: String) {
        pendingWorkItem?.cancel()
        pendingText = text

        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.pendingWorkItem = nil
            self.pendingText = nil
            self.save(text)
        }
        pendingWorkItem = item

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    func flush() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        if let text = pendingText {
            pendingText = nil
            save(text)
        }
    }
}
