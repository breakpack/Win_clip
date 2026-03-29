import Cocoa

class ClipboardMonitor {
    var items: [ClipboardItem] = []
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let maxItems = 50

    func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        // 이미지 확인
        if let image = NSImage(pasteboard: pasteboard) {
            let item = ClipboardItem(content: .image(image))
            addItem(item)
            return
        }

        // 텍스트 확인
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            // 중복 방지: 마지막 항목과 같으면 스킵
            if case .text(let lastText) = items.first?.content, lastText == text {
                return
            }
            let item = ClipboardItem(content: .text(text))
            addItem(item)
        }
    }

    private func addItem(_ item: ClipboardItem) {
        items.insert(item, at: 0)
        if items.count > maxItems {
            items.removeLast()
        }
        NotificationCenter.default.post(name: .clipboardUpdated, object: nil)
    }

    func clearHistory() {
        items.removeAll()
        NotificationCenter.default.post(name: .clipboardUpdated, object: nil)
    }

    func preparePaste(at index: Int) {
        guard index >= 0, index < items.count else { return }
        let item = items[index]
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.content {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .image(let image):
            if let tiffData = image.tiffRepresentation {
                pasteboard.setData(tiffData, forType: .tiff)
            }
        }

        // 선택한 항목을 맨 위로 이동
        items.remove(at: index)
        items.insert(item, at: 0)
        lastChangeCount = pasteboard.changeCount
    }

    func simulatePaste(targetApp: NSRunningApplication?) {
        // 접근성 권한 확인 (없으면 시스템 설정 열림)
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
        guard trusted else { return }

        guard let app = targetApp else { return }
        let pid = app.processIdentifier

        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        // 대상 앱 PID로 직접 전송
        keyDown?.postToPid(pid)
        keyUp?.postToPid(pid)
    }
}

extension Notification.Name {
    static let clipboardUpdated = Notification.Name("clipboardUpdated")
}
