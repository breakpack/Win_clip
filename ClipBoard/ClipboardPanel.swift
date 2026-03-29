import Cocoa

class ClipboardPanel: NSObject {
    private var panel: NSPanel!
    private var scrollView: NSScrollView!
    private var tableView: NSTableView!
    private var monitor: ClipboardMonitor
    private var selectedIndex: Int = 0
    private var localKeyMonitor: Any?
    private var localFlagsMonitor: Any?
    private var globalClickMonitor: Any?
    private var flagsMonitor: Any?
    private var emptyLabel: NSTextField!
    private var hintLabel: NSTextField!
    private var previousApp: NSRunningApplication?

    // 고정 레이아웃
    // 패널=420, scrollView=전체, bg=양쪽10px, 텍스트=bg안쪽 양쪽12px
    private let panelW: CGFloat = 420
    private let margin: CGFloat = 10       // bg 양쪽 마진
    private let textPad: CGFloat = 12      // bg 내부 텍스트 패딩

    var isVisible: Bool { panel.isVisible }

    init(monitor: ClipboardMonitor) {
        self.monitor = monitor
        super.init()
        setupPanel()
        setupTableView()
        setupEmptyLabel()

        NotificationCenter.default.addObserver(self, selector: #selector(clipboardUpdated),
                                                name: .clipboardUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsUpdated),
                                                name: .settingsChanged, object: nil)
    }

    private func setupPanel() {
        let panelWidth: CGFloat = 420
        let panelHeight: CGFloat = 500

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let x = (screenFrame.width - panelWidth) / 2 + screenFrame.origin.x
        let y = (screenFrame.height - panelHeight) / 2 + screenFrame.origin.y

        panel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: panelWidth, height: panelHeight),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = SettingsManager.shared.panelColor.withAlphaComponent(SettingsManager.shared.panelOpacity)
        panel.isOpaque = false
        panel.hasShadow = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 12
        panel.contentView?.layer?.masksToBounds = true

        hintLabel = NSTextField(labelWithString: "")
        hintLabel.frame = NSRect(x: 16, y: 8, width: panelWidth - 32, height: 20)
        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = NSColor.white.withAlphaComponent(0.5)
        hintLabel.alignment = .center
        panel.contentView?.addSubview(hintLabel)
        updateHintText()
    }

    private func setupTableView() {
        scrollView = NSScrollView(frame: NSRect(x: 0, y: 32, width: panelW, height: 460))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true

        tableView = NSTableView()
        tableView.backgroundColor = .clear
        tableView.headerView = nil
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        tableView.usesAutomaticRowHeights = false
        tableView.selectionHighlightStyle = .none
        tableView.focusRingType = .none
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        if #available(macOS 11.0, *) {
            tableView.style = .plain
        }

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("clip"))
        column.width = panelW
        column.minWidth = panelW
        column.maxWidth = panelW
        column.resizingMask = []
        tableView.addTableColumn(column)

        tableView.delegate = self
        tableView.dataSource = self

        scrollView.documentView = tableView
        panel.contentView?.addSubview(scrollView)
    }

    private func setupEmptyLabel() {
        emptyLabel = NSTextField(labelWithString: "클립보드 히스토리가 비어있습니다\n텍스트나 이미지를 복사해보세요")
        emptyLabel.frame = NSRect(x: 0, y: 220, width: 420, height: 60)
        emptyLabel.font = NSFont.systemFont(ofSize: 13)
        emptyLabel.textColor = NSColor.white.withAlphaComponent(0.4)
        emptyLabel.alignment = .center
        emptyLabel.maximumNumberOfLines = 2
        panel.contentView?.addSubview(emptyLabel)
    }

    private func updateHintText() {
        let mode = SettingsManager.shared.pasteMode
        switch mode {
        case .enterToPaste:
            hintLabel.stringValue = "↑↓ 선택  ↵ 붙여넣기  ⎋ 닫기  ⌫ 삭제"
        case .holdAndRelease:
            hintLabel.stringValue = "↑↓ 선택  키를 떼면 붙여넣기  ⎋ 닫기  ⌫ 삭제"
        }
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        // 이전 앱 기억 (포커스 뺏기 전에)
        previousApp = NSWorkspace.shared.frontmostApplication

        selectedIndex = 0
        tableView.reloadData()
        updateEmptyState()

        // 화면 중앙에 위치
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let panelFrame = panel.frame
            let x = (screenFrame.width - panelFrame.width) / 2 + screenFrame.origin.x
            let y = (screenFrame.height - panelFrame.height) / 2 + screenFrame.origin.y
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // 패널 표시 + 포커스 가져오기 (키보드 입력 받기 위해)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if monitor.items.count > 0 {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        }

        // 로컬 키보드 모니터 (포커스가 우리 앱이니까 로컬로 잡힘)
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyEvent(event)
        }

        // 외부 클릭 시 닫기
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }

        // holdAndRelease 모드: 설정된 홀드 키 감시
        if SettingsManager.shared.pasteMode == .holdAndRelease {
            let requiredMods = SettingsManager.shared.holdModifiers.modifiers
            let flagsHandler: (NSEvent) -> Void = { [weak self] event in
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                // 설정된 modifier 중 하나라도 떼면 붙여넣기
                if !flags.isSuperset(of: requiredMods) {
                    self?.releasePaste()
                }
            }
            localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                flagsHandler(event)
                return event
            }
            flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: flagsHandler)
        }
    }

    func hide() {
        panel.orderOut(nil)
        removeMonitors()
    }

    private func removeMonitors() {
        if let m = localKeyMonitor {
            NSEvent.removeMonitor(m)
            localKeyMonitor = nil
        }
        if let m = localFlagsMonitor {
            NSEvent.removeMonitor(m)
            localFlagsMonitor = nil
        }
        if let m = globalClickMonitor {
            NSEvent.removeMonitor(m)
            globalClickMonitor = nil
        }
        if let m = flagsMonitor {
            NSEvent.removeMonitor(m)
            flagsMonitor = nil
        }
    }

    func releasePaste() {
        guard panel.isVisible else { return }
        guard SettingsManager.shared.pasteMode == .holdAndRelease else { return }
        if !monitor.items.isEmpty {
            pasteSelected()
        } else {
            hide()
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        switch Int(event.keyCode) {
        case 125: // 아래 방향키
            moveSelection(by: 1)
            return nil
        case 126: // 위 방향키
            moveSelection(by: -1)
            return nil
        case 36: // Enter
            if SettingsManager.shared.pasteMode == .enterToPaste {
                pasteSelected()
            }
            return nil
        case 53: // ESC
            hide()
            return nil
        case 51: // Delete/Backspace
            deleteSelected()
            return nil
        default:
            return event
        }
    }

    private func moveSelection(by delta: Int) {
        guard !monitor.items.isEmpty else { return }
        selectedIndex = max(0, min(monitor.items.count - 1, selectedIndex + delta))
        tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        tableView.scrollRowToVisible(selectedIndex)
    }

    private func pasteSelected() {
        guard selectedIndex >= 0, selectedIndex < monitor.items.count else { return }
        let index = selectedIndex
        let targetApp = previousApp
        previousApp = nil

        // 1. 클립보드에 내용 세팅
        monitor.preparePaste(at: index)

        // 2. 패널 닫기
        hide()

        // 3. 이전 앱 활성화 + 붙여넣기
        if let app = targetApp {
            app.activate(options: .activateIgnoringOtherApps)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.monitor.simulatePaste(targetApp: targetApp)
            }
        }
    }

    private func deleteSelected() {
        guard selectedIndex >= 0, selectedIndex < monitor.items.count else { return }
        monitor.items.remove(at: selectedIndex)
        if selectedIndex >= monitor.items.count && selectedIndex > 0 {
            selectedIndex -= 1
        }
        tableView.reloadData()
        updateEmptyState()
        if !monitor.items.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        }
    }

    private func updateEmptyState() {
        emptyLabel.isHidden = !monitor.items.isEmpty
        scrollView.isHidden = monitor.items.isEmpty
    }

    @objc private func clipboardUpdated() {
        tableView.reloadData()
        updateEmptyState()
    }

    @objc private func settingsUpdated() {
        updateHintText()
        panel.backgroundColor = SettingsManager.shared.panelColor.withAlphaComponent(SettingsManager.shared.panelOpacity)
    }
}

// MARK: - NSTableViewDataSource & Delegate
extension ClipboardPanel: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return monitor.items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = monitor.items[row]
        let rowH = self.tableView(tableView, heightOfRow: row)
        let bw = panelW - margin * 2       // 400
        let tw = bw - textPad * 2           // 376
        let bgH = rowH - 4

        let cellView = NSView(frame: NSRect(x: 0, y: 0, width: panelW, height: rowH))

        // bg: 양쪽 margin(10px)씩
        let bg = NSView(frame: NSRect(x: margin, y: 2, width: bw, height: bgH))
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 8
        bg.layer?.masksToBounds = true

        let isSelected = (row == selectedIndex)
        bg.layer?.backgroundColor = isSelected
            ? NSColor.systemBlue.withAlphaComponent(0.4).cgColor
            : NSColor.white.withAlphaComponent(0.08).cgColor

        cellView.addSubview(bg)

        switch item.content {
        case .text(let text):
            let textH = bgH - 22

            let label = NSTextField(labelWithString: "")
            label.stringValue = item.content.displayText
            // bg 로컬 좌표: x=textPad(12), w=tw(376)
            label.frame = NSRect(x: textPad, y: 18, width: tw, height: textH)
            label.font = NSFont.systemFont(ofSize: 13)
            label.textColor = .white
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 3
            label.alignment = .left
            label.cell?.wraps = true
            label.cell?.isScrollable = false
            label.backgroundColor = .clear
            label.isBordered = false
            label.isEditable = false
            label.isSelectable = false
            label.drawsBackground = false
            bg.addSubview(label)

            let countLabel = NSTextField(labelWithString: "\(text.count)자")
            countLabel.frame = NSRect(x: textPad, y: 2, width: tw, height: 14)
            countLabel.font = NSFont.systemFont(ofSize: 10)
            countLabel.textColor = NSColor.white.withAlphaComponent(0.35)
            countLabel.alignment = .center
            bg.addSubview(countLabel)

        case .image(let image):
            let imageView = NSImageView(frame: NSRect(x: (bw - 40) / 2, y: bgH - 48, width: 40, height: 40))
            imageView.image = image
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.wantsLayer = true
            imageView.layer?.cornerRadius = 4
            imageView.layer?.masksToBounds = true
            bg.addSubview(imageView)

            let label = NSTextField(labelWithString: "이미지 (\(Int(image.size.width))×\(Int(image.size.height)))")
            label.frame = NSRect(x: 0, y: 4, width: bw, height: 16)
            label.font = NSFont.systemFont(ofSize: 11)
            label.textColor = NSColor.white.withAlphaComponent(0.5)
            label.alignment = .center
            bg.addSubview(label)
        }

        return cellView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row < monitor.items.count else { return 52 }
        let item = monitor.items[row]
        let tw = panelW - margin * 2 - textPad * 2  // 376

        switch item.content {
        case .text:
            let displayText = item.content.displayText
            let font = NSFont.systemFont(ofSize: 13)
            let textRect = (displayText as NSString).boundingRect(
                with: NSSize(width: tw, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font]
            )
            let textHeight = min(textRect.height, font.boundingRectForFont.height * 3)
            return max(52, textHeight + 26)
        case .image:
            return 64
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        if row >= 0 {
            selectedIndex = row
            tableView.reloadData()
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "방금" }
        if seconds < 3600 { return "\(seconds / 60)분 전" }
        if seconds < 86400 { return "\(seconds / 3600)시간 전" }
        return "\(seconds / 86400)일 전"
    }
}
