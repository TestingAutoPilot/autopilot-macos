import AppKit

final class AppController: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 480, height: 900),
        styleMask: [.titled, .closable], backing: .buffered, defer: false)

    // --- type / status / count ---
    let nameField = NSTextField(frame: NSRect(x: 20, y: 410, width: 200, height: 24))
    let statusLabel = NSTextField(labelWithString: "status: ")
    let countLabel = NSTextField(labelWithString: "count: 0")
    var count = 0

    // --- double-click counter ---
    let dblLabel = NSTextField(labelWithString: "dbl: 0")
    var dblCount = 0

    // --- menu flag ---
    var flagOn = false
    let flagItem = NSMenuItem(title: "Toggle Flag", action: #selector(toggleFlag), keyEquivalent: "")

    // --- slider (drag test) ---
    // NSSlider 0–100, starts at 0; drag moves the thumb
    let sliderValueLabel = NSTextField(labelWithString: "slider: 0")

    // --- E1: segmented control ---
    let segmentLabel = NSTextField(labelWithString: "segment: 0")

    // --- E2: picker ---
    let pickerLabel = NSTextField(labelWithString: "pick: Red")

    // --- E3: stepper ---
    let quantityLabel = NSTextField(labelWithString: "qty: 0")

    // --- E4: progress ---
    let uploadProgress = NSProgressIndicator()

    // --- E7: table ---
    let tableFiles = ["document.pdf", "photo.jpg", "notes.txt"]
    let tableSelLabel = NSTextField(labelWithString: "table-sel: none")
    var tableView: NSTableView!
    var tableDataSource: FileTableDataSource!

    func applicationDidFinishLaunching(_ note: Notification) {
        window.title = "TestHostApp"
        let content = NSView(frame: window.contentView!.bounds)

        // ── nameField ────────────────────────────────────────────────────────
        nameField.setAccessibilityIdentifier("nameField")
        nameField.target = self
        nameField.action = #selector(nameChanged)
        nameField.delegate = self
        content.addSubview(nameField)

        // ── statusLabel ──────────────────────────────────────────────────────
        statusLabel.frame = NSRect(x: 20, y: 382, width: 440, height: 22)
        statusLabel.setAccessibilityIdentifier("statusLabel")
        content.addSubview(statusLabel)

        // ── countLabel ───────────────────────────────────────────────────────
        countLabel.frame = NSRect(x: 20, y: 356, width: 200, height: 20)
        countLabel.setAccessibilityIdentifier("countLabel")
        content.addSubview(countLabel)

        // ── dblLabel ─────────────────────────────────────────────────────────
        dblLabel.frame = NSRect(x: 240, y: 356, width: 200, height: 20)
        dblLabel.setAccessibilityIdentifier("dblLabel")
        content.addSubview(dblLabel)

        // ── okButton ─────────────────────────────────────────────────────────
        let okButton = NSButton(title: "OK", target: self, action: #selector(okTapped))
        okButton.frame = NSRect(x: 20, y: 316, width: 80, height: 28)
        okButton.setAccessibilityIdentifier("okButton")
        content.addSubview(okButton)

        // ── dblButton (custom double-click view acting as AX button) ────────
        let dblButton = DoubleClickButton(label: "DblClick", controller: self)
        dblButton.frame = NSRect(x: 120, y: 316, width: 90, height: 28)
        dblButton.setAccessibilityIdentifier("dblButton")
        dblButton.setAccessibilityElement(true)
        dblButton.setAccessibilityRole(.button)
        dblButton.setAccessibilityLabel("DblClick")
        content.addSubview(dblButton)

        // ── flagCheckbox ─────────────────────────────────────────────────────
        let check = NSButton(checkboxWithTitle: "Flag", target: nil, action: nil)
        check.frame = NSRect(x: 230, y: 316, width: 120, height: 28)
        check.setAccessibilityIdentifier("flagCheckbox")
        content.addSubview(check)

        // ── colorSwatch — solid #3478F6 = sRGB(52,120,246) ──────────────────
        let swatch = NSView(frame: NSRect(x: 370, y: 296, width: 80, height: 80))
        swatch.wantsLayer = true
        swatch.layer?.backgroundColor = NSColor(srgbRed: 52/255, green: 120/255, blue: 246/255, alpha: 1).cgColor
        swatch.setAccessibilityIdentifier("colorSwatch")
        swatch.setAccessibilityElement(true)
        swatch.setAccessibilityRole(.group)
        content.addSubview(swatch)

        // ── searchField ──────────────────────────────────────────────────────
        let search = NSSearchField(frame: NSRect(x: 20, y: 280, width: 200, height: 24))
        search.setAccessibilityIdentifier("searchField")
        content.addSubview(search)
        DispatchQueue.main.async { self.window.makeFirstResponder(search) }

        // ── scroll view ──────────────────────────────────────────────────────
        // Contains 10 numbered labels; "scroll-end" is at the bottom (hidden initially).
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 160, width: 220, height: 100))
        scrollView.setAccessibilityIdentifier("scrollView")
        scrollView.hasVerticalScroller = true
        let tallContent = NSView(frame: NSRect(x: 0, y: 0, width: 210, height: 300))
        for i in 0..<10 {
            let lbl = NSTextField(labelWithString: i == 9 ? "scroll-end" : "item-\(i)")
            lbl.frame = NSRect(x: 4, y: 4 + i * 28, width: 200, height: 22)
            lbl.setAccessibilityIdentifier(i == 9 ? "scroll-end" : "item-\(i)")
            tallContent.addSubview(lbl)
        }
        scrollView.documentView = tallContent
        content.addSubview(scrollView)

        // ── slider (drag test) ───────────────────────────────────────────────
        // A 200pt wide slider 0–100, starting at 0.
        // Dragging the thumb right raises its value; we read it back as a float string.
        let slider = NSSlider(value: 0, minValue: 0, maxValue: 100, target: self, action: #selector(sliderMoved(_:)))
        slider.frame = NSRect(x: 20, y: 120, width: 200, height: 22)
        slider.setAccessibilityIdentifier("slider")
        content.addSubview(slider)

        sliderValueLabel.frame = NSRect(x: 232, y: 120, width: 200, height: 22)
        sliderValueLabel.setAccessibilityIdentifier("sliderValueLabel")
        content.addSubview(sliderValueLabel)

        // ── right-click target ────────────────────────────────────────────────
        let rightClickBox = RightClickBox(statusLabel: statusLabel)
        rightClickBox.frame = NSRect(x: 20, y: 76, width: 140, height: 32)
        rightClickBox.wantsLayer = true
        rightClickBox.layer?.backgroundColor = NSColor.systemPurple.cgColor
        rightClickBox.setAccessibilityIdentifier("rightClickTarget")
        rightClickBox.setAccessibilityElement(true)
        rightClickBox.setAccessibilityRole(.group)
        rightClickBox.setAccessibilityLabel("rightClickTarget")
        content.addSubview(rightClickBox)

        // ── rightClick label (shows which context item was chosen) ────────────
        let rcLabel = NSTextField(labelWithString: "rc: none")
        rcLabel.frame = NSRect(x: 172, y: 82, width: 200, height: 22)
        rcLabel.setAccessibilityIdentifier("rcLabel")
        rightClickBox.rcLabel = rcLabel
        content.addSubview(rcLabel)

        // ── result label for various actions (drag outcome, etc.) ─────────────
        let resultLabel = NSTextField(labelWithString: "result: idle")
        resultLabel.frame = NSRect(x: 20, y: 40, width: 300, height: 22)
        resultLabel.setAccessibilityIdentifier("resultLabel")
        content.addSubview(resultLabel)

        // ════════════════════════════════════════════════════════════════════
        // NEW ELEMENTS — y=460 upward (visually above existing elements)
        // ════════════════════════════════════════════════════════════════════

        // ── E1: Segmented control ────────────────────────────────────────────
        // y=856..890 (top of window)
        let segCtrl = NSSegmentedControl(labels: ["Alpha", "Beta", "Gamma"],
                                         trackingMode: .selectOne,
                                         target: self,
                                         action: #selector(segmentChanged(_:)))
        segCtrl.frame = NSRect(x: 20, y: 862, width: 220, height: 24)
        segCtrl.setSelected(true, forSegment: 0)
        segCtrl.setAccessibilityIdentifier("modeSegment")
        content.addSubview(segCtrl)

        segmentLabel.frame = NSRect(x: 252, y: 862, width: 180, height: 24)
        segmentLabel.setAccessibilityIdentifier("segmentLabel")
        content.addSubview(segmentLabel)

        // ── E2: Picker (NSPopUpButton) ────────────────────────────────────────
        // y=818..852
        let colorPicker = NSPopUpButton(frame: NSRect(x: 20, y: 820, width: 130, height: 26), pullsDown: false)
        colorPicker.addItems(withTitles: ["Red", "Green", "Blue"])
        colorPicker.selectItem(at: 0)
        colorPicker.target = self
        colorPicker.action = #selector(pickerChanged(_:))
        colorPicker.setAccessibilityIdentifier("colorPicker")
        content.addSubview(colorPicker)

        pickerLabel.frame = NSRect(x: 162, y: 822, width: 200, height: 22)
        pickerLabel.setAccessibilityIdentifier("pickerLabel")
        content.addSubview(pickerLabel)

        // ── E3: Stepper ───────────────────────────────────────────────────────
        // y=778..812
        let stepper = NSStepper(frame: NSRect(x: 20, y: 780, width: 40, height: 26))
        stepper.minValue = 0
        stepper.maxValue = 10
        stepper.increment = 1
        stepper.doubleValue = 0
        stepper.target = self
        stepper.action = #selector(stepperChanged(_:))
        stepper.setAccessibilityIdentifier("quantityStepper")
        content.addSubview(stepper)

        quantityLabel.frame = NSRect(x: 70, y: 782, width: 200, height: 22)
        quantityLabel.setAccessibilityIdentifier("quantityLabel")
        content.addSubview(quantityLabel)

        // ── E4: Progress indicator ────────────────────────────────────────────
        // y=738..772
        uploadProgress.frame = NSRect(x: 20, y: 742, width: 200, height: 20)
        uploadProgress.style = .bar
        uploadProgress.isIndeterminate = false
        uploadProgress.minValue = 0.0
        uploadProgress.maxValue = 1.0
        uploadProgress.doubleValue = 0.5
        uploadProgress.setAccessibilityIdentifier("uploadProgress")
        content.addSubview(uploadProgress)

        let advanceButton = NSButton(title: "Advance", target: self, action: #selector(advanceProgress))
        advanceButton.frame = NSRect(x: 232, y: 738, width: 90, height: 28)
        advanceButton.setAccessibilityIdentifier("advanceButton")
        content.addSubview(advanceButton)

        // ── E5: Multi-line text area ──────────────────────────────────────────
        // y=648..736 (scroll view ~80pt tall)
        let notesScrollView = NSScrollView(frame: NSRect(x: 20, y: 648, width: 200, height: 80))
        notesScrollView.hasVerticalScroller = true
        notesScrollView.setAccessibilityElement(false)
        let notesTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 80))
        notesTextView.isEditable = true
        notesTextView.isRichText = false
        notesTextView.setAccessibilityIdentifier("notesArea")
        notesScrollView.documentView = notesTextView
        content.addSubview(notesScrollView)

        // ── E6: Link / tappable label ─────────────────────────────────────────
        // y=608..642
        let termsLink = TappableLink(statusLabel: statusLabel)
        termsLink.frame = NSRect(x: 20, y: 610, width: 160, height: 24)
        termsLink.setAccessibilityIdentifier("termsLink")
        termsLink.setAccessibilityElement(true)
        termsLink.setAccessibilityRole(.link)
        content.addSubview(termsLink)

        // ── E7: Table ─────────────────────────────────────────────────────────
        // y=508..606 (90pt scroll view + 22pt label below = 598..596 for label)
        tableDataSource = FileTableDataSource(files: tableFiles, selLabel: tableSelLabel)
        tableView = NSTableView()
        tableView.setAccessibilityIdentifier("fileTable")
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col"))
        col.title = "File"
        col.width = 200
        tableView.addTableColumn(col)
        tableView.dataSource = tableDataSource
        tableView.delegate = tableDataSource
        tableView.rowHeight = 20
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.target = self
        tableView.action = #selector(tableRowClicked)

        let tableScrollView = NSScrollView(frame: NSRect(x: 20, y: 508, width: 220, height: 90))
        tableScrollView.documentView = tableView
        tableScrollView.hasVerticalScroller = true
        content.addSubview(tableScrollView)

        tableSelLabel.frame = NSRect(x: 20, y: 478, width: 300, height: 22)
        tableSelLabel.setAccessibilityIdentifier("tableSelLabel")
        content.addSubview(tableSelLabel)

        // ── E8: Alert trigger ─────────────────────────────────────────────────
        // y=438..472
        let alertButton = NSButton(title: "Show Alert", target: self, action: #selector(showAlert))
        alertButton.frame = NSRect(x: 20, y: 440, width: 120, height: 28)
        alertButton.setAccessibilityIdentifier("alertButton")
        content.addSubview(alertButton)

        // ── E9: Disabled element ──────────────────────────────────────────────
        // existing elements occupy y=40..434; put E9 just above y=434
        // Use y=436 (tight but just above existing top nameField at y=410+24=434)
        // Actually place at y=438 for 2pt gap — but E8 is at 440, so place E9 at a
        // slightly different x to share the row, or move E9 below. Use same row (y=440):
        let lockedButton = NSButton(title: "Locked", target: nil, action: nil)
        lockedButton.frame = NSRect(x: 160, y: 440, width: 90, height: 28)
        lockedButton.isEnabled = false
        lockedButton.setAccessibilityIdentifier("lockedButton")
        content.addSubview(lockedButton)

        let disabledLabel = NSTextField(labelWithString: "locked: true")
        disabledLabel.frame = NSRect(x: 262, y: 444, width: 140, height: 22)
        disabledLabel.setAccessibilityIdentifier("disabledLabel")
        content.addSubview(disabledLabel)

        window.contentView = content
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        installMenu()
    }

    func installMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu

        let viewItem = NSMenuItem()
        mainMenu.addItem(viewItem)
        let viewMenu = NSMenu(title: "View")
        flagItem.target = self
        viewMenu.addItem(flagItem)
        viewItem.submenu = viewMenu

        NSApp.mainMenu = mainMenu
    }

    @objc func toggleFlag() {
        flagOn.toggle()
        flagItem.state = flagOn ? .on : .off
        statusLabel.stringValue = "status: flag=\(flagOn)"
    }

    @objc func nameChanged() {
        statusLabel.stringValue = "status: \(nameField.stringValue)"
    }

    func controlTextDidChange(_ obj: Notification) {
        statusLabel.stringValue = "status: \(nameField.stringValue)"
    }

    @objc func okTapped() {
        count += 1
        countLabel.stringValue = "count: \(count)"
    }

    func doubleClickFired() {
        dblCount += 1
        dblLabel.stringValue = "dbl: \(dblCount)"
    }

    @objc func sliderMoved(_ sender: NSSlider) {
        sliderValueLabel.stringValue = "slider: \(Int(sender.doubleValue))"
    }

    // ── E1 ──────────────────────────────────────────────────────────────────
    @objc func segmentChanged(_ sender: NSSegmentedControl) {
        segmentLabel.stringValue = "segment: \(sender.selectedSegment)"
    }

    // ── E2 ──────────────────────────────────────────────────────────────────
    @objc func pickerChanged(_ sender: NSPopUpButton) {
        let title = sender.selectedItem?.title ?? ""
        pickerLabel.stringValue = "pick: \(title)"
    }

    // ── E3 ──────────────────────────────────────────────────────────────────
    @objc func stepperChanged(_ sender: NSStepper) {
        quantityLabel.stringValue = "qty: \(Int(sender.doubleValue))"
    }

    // ── E4 ──────────────────────────────────────────────────────────────────
    @objc func advanceProgress() {
        uploadProgress.doubleValue = 1.0
    }

    // ── E7 ──────────────────────────────────────────────────────────────────
    @objc func tableRowClicked() {
        let row = tableView.clickedRow
        guard row >= 0, row < tableFiles.count else { return }
        tableSelLabel.stringValue = "table-sel: \(tableFiles[row])"
    }

    // ── E8 ──────────────────────────────────────────────────────────────────
    @objc func showAlert() {
        let alert = NSAlert()
        alert.messageText = "Are you sure?"
        alert.informativeText = "This cannot be undone."
        alert.addButton(withTitle: "Confirm")
        alert.addButton(withTitle: "Cancel")
        if let confirmBtn = alert.buttons.first {
            confirmBtn.setAccessibilityIdentifier("confirmButton")
        }
        if alert.buttons.count > 1 {
            alert.buttons[1].setAccessibilityIdentifier("cancelButton")
        }
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertFirstButtonReturn {
                self?.statusLabel.stringValue = "status: alert-confirmed"
            } else {
                self?.statusLabel.stringValue = "status: alert-cancelled"
            }
        }
    }
}

// MARK: - DoubleClickButton

/// NSView that fires a double-click callback and exposes AX as a button.
final class DoubleClickButton: NSView {
    private let label: String
    private weak var controller: AppController?

    init(label: String, controller: AppController) {
        self.label = label
        self.controller = controller
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: NSRect) {
        NSColor.systemBlue.setFill()
        rect.fill()
        let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.white,
                                                     .font: NSFont.systemFont(ofSize: 12)]
        NSAttributedString(string: label, attributes: attrs).draw(at: NSPoint(x: 6, y: 7))
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { controller?.doubleClickFired() }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - RightClickBox

/// Purple view that shows a context menu on right-click; selection updates rcLabel.
final class RightClickBox: NSView {
    weak var rcLabel: NSTextField?
    private weak var statusLabel: NSTextField?

    init(statusLabel: NSTextField) {
        self.statusLabel = statusLabel
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu(title: "Context")
        let item = NSMenuItem(title: "ContextAction", action: #selector(contextAction), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc func contextAction() {
        rcLabel?.stringValue = "rc: tapped"
        statusLabel?.stringValue = "status: context-tapped"
    }
}

// MARK: - TappableLink

/// Clickable label styled as a blue underlined link; sets statusLabel on click.
final class TappableLink: NSView {
    private weak var statusLabel: NSTextField?
    private let textField = NSTextField(labelWithString: "")

    init(statusLabel: NSTextField) {
        self.statusLabel = statusLabel
        super.init(frame: .zero)

        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: NSFont.systemFont(ofSize: 13)
        ]
        textField.attributedStringValue = NSAttributedString(string: "Terms of Service", attributes: attrs)
        textField.frame = NSRect(x: 0, y: 0, width: 160, height: 24)
        textField.isEditable = false
        textField.isBordered = false
        textField.backgroundColor = .clear
        addSubview(textField)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        statusLabel?.stringValue = "status: link-tapped"
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override var isFlipped: Bool { false }
}

// MARK: - FileTableDataSource

final class FileTableDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private let files: [String]
    private weak var selLabel: NSTextField?

    init(files: [String], selLabel: NSTextField) {
        self.files = files
        self.selLabel = selLabel
    }

    func numberOfRows(in tableView: NSTableView) -> Int { files.count }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        files[row]
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTextField(labelWithString: files[row])
        cell.setAccessibilityIdentifier("row-\(files[row])")
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tv = notification.object as? NSTableView else { return }
        let row = tv.selectedRow
        if row >= 0, row < files.count {
            selLabel?.stringValue = "table-sel: \(files[row])"
        }
    }
}

let app = NSApplication.shared
let controller = AppController()
app.delegate = controller
app.setActivationPolicy(.regular)
app.run()
