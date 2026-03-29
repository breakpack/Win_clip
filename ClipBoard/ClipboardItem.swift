import Cocoa

enum ClipboardContent {
    case text(String)
    case image(NSImage)

    var displayText: String {
        switch self {
        case .text(let str):
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 80 {
                return String(trimmed.prefix(80)) + "…"
            }
            return trimmed
        case .image:
            return "🖼 이미지"
        }
    }
}

class ClipboardItem {
    let content: ClipboardContent
    let timestamp: Date

    init(content: ClipboardContent) {
        self.content = content
        self.timestamp = Date()
    }

    var isText: Bool {
        if case .text = content { return true }
        return false
    }

    var isImage: Bool {
        if case .image = content { return true }
        return false
    }
}
