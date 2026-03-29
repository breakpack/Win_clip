import Cocoa

class SettingsWindowController: NSWindowController {
    private var pasteModePopup: NSPopUpButton!
    private var maxItemsField: NSTextField!
    private var maxItemsStepper: NSStepper!
    private var shortcutRecorder: ShortcutRecorderButton!
    private var holdKeyRecorder: HoldKeyRecorderButton!
    private var holdKeyRow: NSView!
    private var opacitySlider: NSSlider!
    private var opacityLabel: NSTextField!
    private var colorWell: NSColorWell!
    private var modeHintLabel: NSTextField?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClipBoard 설정"
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        let settings = SettingsManager.shared
        let margin: CGFloat = 24
        let labelWidth: CGFloat = 120
        let controlX: CGFloat = margin + labelWidth + 8
        let controlWidth: CGFloat = 460 - controlX - margin
        var y: CGFloat = 360

        // === 단축키 ===
        let shortcutLabel = NSTextField(labelWithString: "단축키:")
        shortcutLabel.frame = NSRect(x: margin, y: y, width: labelWidth, height: 24)
        shortcutLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        shortcutLabel.alignment = .right
        contentView.addSubview(shortcutLabel)

        shortcutRecorder = ShortcutRecorderButton(shortcut: settings.shortcut)
        shortcutRecorder.frame = NSRect(x: controlX, y: y - 2, width: 140, height: 28)
        shortcutRecorder.onShortcutRecorded = { newShortcut in
            SettingsManager.shared.shortcut = newShortcut
        }
        contentView.addSubview(shortcutRecorder)

        y -= 20
        let shortcutHint = NSTextField(labelWithString: "버튼 클릭 후 원하는 키 조합을 입력하세요")
        shortcutHint.frame = NSRect(x: controlX, y: y, width: controlWidth, height: 16)
        shortcutHint.font = NSFont.systemFont(ofSize: 11)
        shortcutHint.textColor = .tertiaryLabelColor
        contentView.addSubview(shortcutHint)

        y -= 36

        // === 붙여넣기 모드 ===
        let modeLabel = NSTextField(labelWithString: "붙여넣기 모드:")
        modeLabel.frame = NSRect(x: margin, y: y, width: labelWidth, height: 24)
        modeLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        modeLabel.alignment = .right
        contentView.addSubview(modeLabel)

        pasteModePopup = NSPopUpButton(frame: NSRect(x: controlX, y: y - 2, width: controlWidth, height: 28))
        pasteModePopup.addItem(withTitle: PasteMode.enterToPaste.displayName)
        pasteModePopup.addItem(withTitle: PasteMode.holdAndRelease.displayName)
        pasteModePopup.selectItem(at: settings.pasteMode == .enterToPaste ? 0 : 1)
        pasteModePopup.target = self
        pasteModePopup.action = #selector(pasteModeChanged)
        contentView.addSubview(pasteModePopup)

        y -= 20
        let modeHint = NSTextField(labelWithString: "")
        modeHint.frame = NSRect(x: controlX, y: y, width: controlWidth, height: 16)
        modeHint.font = NSFont.systemFont(ofSize: 11)
        modeHint.textColor = .tertiaryLabelColor
        updateModeHint(modeHint)
        self.modeHintLabel = modeHint
        contentView.addSubview(modeHint)

        y -= 36

        // === 홀드 키 (holdAndRelease 모드 전용) ===
        holdKeyRow = NSView(frame: NSRect(x: 0, y: y - 20, width: 460, height: 52))

        let holdLabel = NSTextField(labelWithString: "홀드 키:")
        holdLabel.frame = NSRect(x: margin, y: 24, width: labelWidth, height: 24)
        holdLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        holdLabel.alignment = .right
        holdKeyRow.addSubview(holdLabel)

        holdKeyRecorder = HoldKeyRecorderButton(hold: settings.holdModifiers)
        holdKeyRecorder.frame = NSRect(x: controlX, y: 22, width: 200, height: 28)
        holdKeyRecorder.onHoldRecorded = { newHold in
            SettingsManager.shared.holdModifiers = newHold
        }
        holdKeyRow.addSubview(holdKeyRecorder)

        let holdHint = NSTextField(labelWithString: "버튼 클릭 후 홀드할 키를 누르고 떼세요")
        holdHint.frame = NSRect(x: controlX, y: 4, width: controlWidth, height: 16)
        holdHint.font = NSFont.systemFont(ofSize: 11)
        holdHint.textColor = .tertiaryLabelColor
        holdKeyRow.addSubview(holdHint)

        contentView.addSubview(holdKeyRow)
        holdKeyRow.isHidden = settings.pasteMode != .holdAndRelease

        y -= 56

        // === 패널 투명도 ===
        let opacityTitleLabel = NSTextField(labelWithString: "패널 투명도:")
        opacityTitleLabel.frame = NSRect(x: margin, y: y, width: labelWidth, height: 24)
        opacityTitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        opacityTitleLabel.alignment = .right
        contentView.addSubview(opacityTitleLabel)

        opacitySlider = NSSlider(value: settings.panelOpacity, minValue: 0.3, maxValue: 1.0,
                                  target: self, action: #selector(opacityChanged))
        opacitySlider.frame = NSRect(x: controlX, y: y, width: controlWidth - 50, height: 24)
        contentView.addSubview(opacitySlider)

        opacityLabel = NSTextField(labelWithString: "\(Int(settings.panelOpacity * 100))%")
        opacityLabel.frame = NSRect(x: controlX + controlWidth - 44, y: y, width: 44, height: 24)
        opacityLabel.font = NSFont.systemFont(ofSize: 13)
        opacityLabel.textColor = .secondaryLabelColor
        opacityLabel.alignment = .right
        contentView.addSubview(opacityLabel)

        y -= 36

        // === 배경색 ===
        let colorLabel = NSTextField(labelWithString: "배경 색상:")
        colorLabel.frame = NSRect(x: margin, y: y, width: labelWidth, height: 24)
        colorLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        colorLabel.alignment = .right
        contentView.addSubview(colorLabel)

        colorWell = NSColorWell(frame: NSRect(x: controlX, y: y - 2, width: 44, height: 28))
        colorWell.color = settings.panelColor
        colorWell.target = self
        colorWell.action = #selector(colorChanged)
        contentView.addSubview(colorWell)

        y -= 36

        // === 최대 히스토리 수 ===
        let maxLabel = NSTextField(labelWithString: "최대 저장 개수:")
        maxLabel.frame = NSRect(x: margin, y: y, width: labelWidth, height: 24)
        maxLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        maxLabel.alignment = .right
        contentView.addSubview(maxLabel)

        maxItemsField = NSTextField(string: "\(settings.maxHistoryItems)")
        maxItemsField.frame = NSRect(x: controlX, y: y, width: 60, height: 24)
        maxItemsField.font = NSFont.systemFont(ofSize: 13)
        maxItemsField.alignment = .center
        maxItemsField.isEditable = false
        maxItemsField.isSelectable = false
        contentView.addSubview(maxItemsField)

        maxItemsStepper = NSStepper(frame: NSRect(x: controlX + 64, y: y, width: 19, height: 24))
        maxItemsStepper.minValue = 10
        maxItemsStepper.maxValue = 200
        maxItemsStepper.increment = 10
        maxItemsStepper.integerValue = settings.maxHistoryItems
        maxItemsStepper.target = self
        maxItemsStepper.action = #selector(maxItemsChanged)
        contentView.addSubview(maxItemsStepper)

        let maxHint = NSTextField(labelWithString: "개")
        maxHint.frame = NSRect(x: controlX + 88, y: y, width: 30, height: 24)
        maxHint.font = NSFont.systemFont(ofSize: 13)
        maxHint.textColor = .secondaryLabelColor
        contentView.addSubview(maxHint)
    }

    private func updateModeHint(_ label: NSTextField) {
        let settings = SettingsManager.shared
        let shortcutDisplay = settings.shortcut.displayString
        switch settings.pasteMode {
        case .enterToPaste:
            label.stringValue = "↑↓로 선택 후 Enter로 붙여넣기"
        case .holdAndRelease:
            label.stringValue = "\(shortcutDisplay)를 누른 채 ↑↓ 선택, 키를 떼면 붙여넣기"
        }
    }

    @objc private func pasteModeChanged() {
        let mode: PasteMode = pasteModePopup.indexOfSelectedItem == 0 ? .enterToPaste : .holdAndRelease
        SettingsManager.shared.pasteMode = mode
        if let hint = modeHintLabel {
            updateModeHint(hint)
        }
        holdKeyRow.isHidden = mode != .holdAndRelease
    }

    @objc private func opacityChanged() {
        let value = opacitySlider.doubleValue
        opacityLabel.stringValue = "\(Int(value * 100))%"
        SettingsManager.shared.panelOpacity = value
    }

    @objc private func colorChanged() {
        SettingsManager.shared.panelColor = colorWell.color
    }

    @objc private func maxItemsChanged() {
        let value = maxItemsStepper.integerValue
        maxItemsField.stringValue = "\(value)"
        SettingsManager.shared.maxHistoryItems = value
    }

    func showSettings() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
