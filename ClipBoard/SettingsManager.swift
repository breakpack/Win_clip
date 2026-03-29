import Cocoa
import Carbon

enum PasteMode: String {
    case enterToPaste = "enterToPaste"
    case holdAndRelease = "holdAndRelease"

    var displayName: String {
        switch self {
        case .enterToPaste: return "방향키 선택 + Enter 붙여넣기"
        case .holdAndRelease: return "홀드 중 선택, 떼면 붙여넣기"
        }
    }
}

class SettingsManager {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let pasteMode = "pasteMode"
        static let maxHistoryItems = "maxHistoryItems"
        static let shortcutKeyCode = "shortcutKeyCode"
        static let shortcutModifiers = "shortcutModifiers"
        static let holdKeyCode = "holdKeyCode"
        static let holdModifiers = "holdModifiers"
        static let panelOpacity = "panelOpacity"
        static let panelColorR = "panelColorR"
        static let panelColorG = "panelColorG"
        static let panelColorB = "panelColorB"
    }

    var pasteMode: PasteMode {
        get {
            if let raw = defaults.string(forKey: Keys.pasteMode),
               let mode = PasteMode(rawValue: raw) {
                return mode
            }
            return .enterToPaste
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.pasteMode)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    var maxHistoryItems: Int {
        get {
            let val = defaults.integer(forKey: Keys.maxHistoryItems)
            return val > 0 ? val : 50
        }
        set {
            defaults.set(newValue, forKey: Keys.maxHistoryItems)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    var panelOpacity: Double {
        get {
            if defaults.object(forKey: Keys.panelOpacity) != nil {
                return defaults.double(forKey: Keys.panelOpacity)
            }
            return 0.85
        }
        set {
            defaults.set(newValue, forKey: Keys.panelOpacity)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    var panelColor: NSColor {
        get {
            if defaults.object(forKey: Keys.panelColorR) != nil {
                let r = CGFloat(defaults.double(forKey: Keys.panelColorR))
                let g = CGFloat(defaults.double(forKey: Keys.panelColorG))
                let b = CGFloat(defaults.double(forKey: Keys.panelColorB))
                return NSColor(red: r, green: g, blue: b, alpha: 1.0)
            }
            return NSColor.black
        }
        set {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            let converted = newValue.usingColorSpace(.sRGB) ?? newValue
            converted.getRed(&r, green: &g, blue: &b, alpha: &a)
            defaults.set(Double(r), forKey: Keys.panelColorR)
            defaults.set(Double(g), forKey: Keys.panelColorG)
            defaults.set(Double(b), forKey: Keys.panelColorB)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    var holdModifiers: HoldModifiers {
        get {
            if defaults.object(forKey: Keys.holdModifiers) != nil {
                let raw = defaults.integer(forKey: Keys.holdModifiers)
                var flags: NSEvent.ModifierFlags = []
                if raw & Int(UInt32(cmdKey)) != 0 { flags.insert(.command) }
                if raw & Int(UInt32(shiftKey)) != 0 { flags.insert(.shift) }
                if raw & Int(UInt32(optionKey)) != 0 { flags.insert(.option) }
                if raw & Int(UInt32(controlKey)) != 0 { flags.insert(.control) }
                return HoldModifiers(modifiers: flags)
            }
            return .defaultHold  // 기본값: Cmd+Shift
        }
        set {
            defaults.set(Int(newValue.carbonModifiers), forKey: Keys.holdModifiers)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    var shortcut: KeyShortcut {
        get {
            if defaults.object(forKey: Keys.shortcutKeyCode) != nil {
                let keyCode = UInt32(defaults.integer(forKey: Keys.shortcutKeyCode))
                let modifiers = UInt32(defaults.integer(forKey: Keys.shortcutModifiers))
                return KeyShortcut(keyCode: keyCode, modifiers: modifiers)
            }
            return .defaultShortcut
        }
        set {
            defaults.set(Int(newValue.keyCode), forKey: Keys.shortcutKeyCode)
            defaults.set(Int(newValue.modifiers), forKey: Keys.shortcutModifiers)
            NotificationCenter.default.post(name: .shortcutChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
    static let shortcutChanged = Notification.Name("shortcutChanged")
}
