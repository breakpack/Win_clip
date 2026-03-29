import Cocoa
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var clipboardPanel: ClipboardPanel!
    var clipboardMonitor: ClipboardMonitor!
    var hotKeyRef: EventHotKeyRef?
    var eventHandlerRef: EventHandlerRef?
    var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipBoard")
            button.image?.size = NSSize(width: 18, height: 18)
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "클립보드 열기", action: #selector(togglePanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "설정...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "히스토리 지우기", action: #selector(clearHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        clipboardMonitor = ClipboardMonitor()
        clipboardMonitor.startMonitoring()

        clipboardPanel = ClipboardPanel(monitor: clipboardMonitor)

        registerHotKey()

        NotificationCenter.default.addObserver(self, selector: #selector(shortcutDidChange),
                                                name: .shortcutChanged, object: nil)
    }

    func registerHotKey() {
        // 기존 핫키 해제
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }

        let shortcut = SettingsManager.shared.shortcut

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x434C4950)
        hotKeyID.id = 1

        var eventTypes: [EventTypeSpec] = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        // 핸들러는 한 번만 등록
        if eventHandlerRef == nil {
            let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
                var eventKind: UInt32 = 0
                if let event = event {
                    eventKind = UInt32(GetEventKind(event))
                }
                DispatchQueue.main.async {
                    guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
                    if eventKind == UInt32(kEventHotKeyPressed) {
                        appDelegate.handleHotKeyPressed()
                    } else if eventKind == UInt32(kEventHotKeyReleased) {
                        appDelegate.handleHotKeyReleased()
                    }
                }
                return noErr
            }
            InstallEventHandler(GetApplicationEventTarget(), handler, 2, &eventTypes, nil, &eventHandlerRef)
        }

        RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    @objc func shortcutDidChange() {
        registerHotKey()
    }

    func handleHotKeyPressed() {
        clipboardPanel.toggle()
    }

    func handleHotKeyReleased() {
        // 홀드 키 release는 ClipboardPanel의 flagsChanged 모니터가 처리
    }

    @objc func togglePanel() {
        clipboardPanel.toggle()
    }

    @objc func clearHistory() {
        clipboardMonitor.clearHistory()
    }

    @objc func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showSettings()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }
    }
}
