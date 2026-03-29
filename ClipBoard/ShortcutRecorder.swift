import Cocoa
import Carbon

struct KeyShortcut: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32  // Carbon modifier flags

    static let defaultShortcut = KeyShortcut(keyCode: 9, modifiers: UInt32(cmdKey | shiftKey)) // Cmd+Shift+V

    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }

    var holdModifiersDisplay: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        return parts.joined()
    }

    // Cocoa modifier flags → 홀드 감지용
    var cocoaModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return flags
    }
}

func cocoaToCarbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
    var carbon: UInt32 = 0
    if flags.contains(.command) { carbon |= UInt32(cmdKey) }
    if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
    if flags.contains(.option) { carbon |= UInt32(optionKey) }
    if flags.contains(.control) { carbon |= UInt32(controlKey) }
    return carbon
}

func keyCodeToString(_ keyCode: UInt32) -> String {
    let map: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P",
        37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5",
        22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
        49: "Space", 36: "↵", 48: "Tab", 51: "⌫", 53: "Esc",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5",
        97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12",
    ]
    return map[keyCode] ?? "Key\(keyCode)"
}

// 홀드할 modifier 키 조합을 저장하는 구조체
struct HoldModifiers: Equatable {
    var modifiers: NSEvent.ModifierFlags

    static let defaultHold = HoldModifiers(modifiers: [.command, .shift])

    var carbonModifiers: UInt32 {
        return cocoaToCarbonModifiers(modifiers)
    }

    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃ Control") }
        if modifiers.contains(.option) { parts.append("⌥ Option") }
        if modifiers.contains(.shift) { parts.append("⇧ Shift") }
        if modifiers.contains(.command) { parts.append("⌘ Command") }
        if parts.isEmpty { return "없음" }
        return parts.joined(separator: " + ")
    }

    var shortDisplay: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        if parts.isEmpty { return "없음" }
        return parts.joined()
    }
}

// 홀드 키 입력 받는 커스텀 버튼
class HoldKeyRecorderButton: NSButton {
    var isRecording = false
    var currentHold: HoldModifiers
    var onHoldRecorded: ((HoldModifiers) -> Void)?
    private var localMonitor: Any?
    private var peakModifiers: NSEvent.ModifierFlags = []

    init(hold: HoldModifiers) {
        self.currentHold = hold
        super.init(frame: .zero)
        self.bezelStyle = .rounded
        self.setButtonType(.momentaryPushIn)
        updateTitle()
        self.target = self
        self.action = #selector(clicked)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func updateTitle() {
        if isRecording {
            self.title = "modifier 키 입력..."
        } else {
            self.title = currentHold.displayString
        }
    }

    @objc private func clicked() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        peakModifiers = []
        updateTitle()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlags(event)
            return event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
        updateTitle()
    }

    private func handleFlags(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let relevant: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let pressed = flags.intersection(relevant)

        if !pressed.isEmpty {
            // 누를 때마다 최대 조합 갱신 (union)
            peakModifiers = peakModifiers.union(pressed)
            self.title = HoldModifiers(modifiers: peakModifiers).displayString
        } else if !peakModifiers.isEmpty {
            // 전부 뗐을 때 → 최대 조합으로 확정
            currentHold = HoldModifiers(modifiers: peakModifiers)
            onHoldRecorded?(currentHold)
            stopRecording()
        }
    }
}

// 단축키 입력 받는 커스텀 뷰
class ShortcutRecorderButton: NSButton {
    var isRecording = false
    var currentShortcut: KeyShortcut
    var onShortcutRecorded: ((KeyShortcut) -> Void)?
    private var localMonitor: Any?

    init(shortcut: KeyShortcut) {
        self.currentShortcut = shortcut
        super.init(frame: .zero)
        self.bezelStyle = .rounded
        self.setButtonType(.momentaryPushIn)
        updateTitle()
        self.target = self
        self.action = #selector(clicked)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func updateTitle() {
        if isRecording {
            self.title = "키 입력 대기중..."
        } else {
            self.title = currentShortcut.displayString
        }
    }

    @objc private func clicked() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        updateTitle()
        // 키 입력 캡처
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleRecordedKey(event)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
        updateTitle()
    }

    private func handleRecordedKey(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // modifier 키만 누른 건 무시 (최소 1개 modifier + 일반 키 필요)
        guard !flags.isEmpty else {
            stopRecording()
            return
        }

        let carbonMods = cocoaToCarbonModifiers(flags)
        let keyCode = UInt32(event.keyCode)
        currentShortcut = KeyShortcut(keyCode: keyCode, modifiers: carbonMods)
        onShortcutRecorded?(currentShortcut)
        stopRecording()
    }
}
