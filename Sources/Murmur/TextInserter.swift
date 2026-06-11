import AppKit

/// Inserts text into the frontmost app by briefly borrowing the clipboard
/// and synthesizing ⌘V, then restoring whatever was on the clipboard before.
enum TextInserter {
    @MainActor
    static func paste(_ text: String) {
        let pasteboard = NSPasteboard.general

        // Snapshot current clipboard contents (all types).
        let saved: [[NSPasteboard.PasteboardType: Data]] = (pasteboard.pasteboardItems ?? []).map { item in
            var entry: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { entry[type] = data }
            }
            return entry
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        sendCmdV()

        // Restore the previous clipboard after the paste has landed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard !saved.isEmpty else { return }
            pasteboard.clearContents()
            let items: [NSPasteboardItem] = saved.map { entry in
                let item = NSPasteboardItem()
                for (type, data) in entry { item.setData(data, forType: type) }
                return item
            }
            pasteboard.writeObjects(items)
        }
    }

    private static func sendCmdV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let vKey: CGKeyCode = 9
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
