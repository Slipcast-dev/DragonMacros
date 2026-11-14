import AppKit
import QuartzCore
import Carbon
import UniformTypeIdentifiers

final class MainWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSWindowDelegate {
    let store: MacroStore
    private let table = NSTableView()
    private let editor = FlippedView()
    private let placeholder = FlippedView()
    private let nameField = NSTextField()
    private let hotkeyField = HotkeyField()
    private let clearButton = NSButton()
    private let hotkeyStatus = NSTextField(labelWithString: "")
    private let kindApp = MotionButton(title: "", target: nil, action: nil)
    private let kindUrl = MotionButton(title: "", target: nil, action: nil)
    private let valueCaption = caption("")
    private let appPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let urlField = NSTextField()
    private let enabledCheck = SamuraiToggle(checkboxWithTitle: L("Макрос включён", "Macro enabled"), target: nil, action: nil)
    private var editorControls: [NSView] = []
    private let editorTitle = NSTextField(labelWithString: "")
    private let editorSubtitle = NSTextField(labelWithString: "")
    private let editorNumber = CenteredBadge()
    private let macroCount = CenteredBadge()
    private let totalText = NSTextField(labelWithString: "")
    private let pauseButton = NSButton()
    private var lastSelectedID: UUID?
    private let backdrop = SamuraiBackdrop()
    private var hasPresented = false
    var onTogglePause: (() -> Void)?
    private var apps: [InstalledApp] = []
    private var loading = false
    private var pendingText: (id: UUID, name: String, url: String)?
    private var textSave: DispatchWorkItem?
    private var selected: Int? { table.selectedRow >= 0 && table.selectedRow < store.macros.count ? table.selectedRow : nil }
    var selectedIndex: Int? { selected }
    var onOpenSettings: (() -> Void)?

    init(store: MacroStore, selectIndex: Int? = nil) {
        self.store = store
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1160, height: 800),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        w.title = "Dragon Macros"
        w.contentMinSize = NSSize(width: 1000, height: 760)
        w.appearance = Theme.appearance
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.backgroundColor = .dragonSide
        w.isReleasedWhenClosed = false
        w.center()
        super.init(window: w)
        w.delegate = self
        build(in: w.contentView!)
        if !store.macros.isEmpty { table.selectRowIndexes([min(selectIndex ?? 0, store.macros.count - 1)], byExtendingSelection: false) }
        loadEditor()
        AppCatalog.load { [weak self] list in self?.apps = list; self?.fillAppPopup() }
    }
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        NSApp.setActivationPolicy(Settings.shared.showInDock ? .regular : .accessory)
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil); window?.makeKeyAndOrderFront(nil)
        if !hasPresented {
            hasPresented = true
            animateEntrance()
        }
    }

    // MARK: Построение интерфейса

    /// Компоновка повторяет утверждённый макет: панель, список, редактор, статус.
    /// Фиксированная ширина полей оставляет справа свободное место для декора.
    private func build(in root: NSView) {
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.dragonBG.cgColor
        let width = root.bounds.width, height = root.bounds.height
        let headerHeight: CGFloat = 84, sidebarWidth: CGFloat = 253, footerHeight: CGFloat = 39
        let bodyHeight = height - headerHeight - footerHeight

        let header = HeaderView(frame: NSRect(x: 0, y: height - headerHeight, width: width, height: headerHeight))
        header.autoresizingMask = [.width, .minYMargin]
        let title = NSTextField(labelWithString: "Dragon Macros")
        title.font = Theme.titleFont
        title.textColor = Theme.headerText
        title.frame = NSRect(x: 30, y: 36, width: 330, height: 32)
        header.addSubview(title)
        let subtitle = NSTextField(labelWithString: Theme.isSamurai ? "精度と速度" : L("Горячие клавиши для приложений и ссылок", "Hotkeys for applications and links"))
        subtitle.font = .systemFont(ofSize: 10)
        subtitle.textColor = Theme.headerText.withAlphaComponent(0.65)
        subtitle.frame = NSRect(x: 32, y: 19, width: 360, height: 15)
        header.addSubview(subtitle)
        let buttons = [
            HeaderButton(symbol: "square.and.arrow.down", label: L("Загрузить", "Load"), target: self, action: #selector(loadConfig)),
            HeaderButton(symbol: "square.and.arrow.up", label: L("Сохранить", "Save"), target: self, action: #selector(saveConfig)),
            HeaderButton(symbol: "gearshape", label: "", target: self, action: #selector(settingsClicked))
        ]
        buttons[2].setAccessibilityLabel(L("Настройки", "Settings"))
        buttons[2].toolTip = L("Настройки (⌘,)", "Settings (⌘,)")
        var right = width - 24
        for button in buttons.reversed() {
            right -= button.idealWidth
            button.frame = NSRect(x: right, y: 22, width: button.idealWidth, height: 40)
            button.autoresizingMask = [.minXMargin]
            header.addSubview(button)
            right -= 8
        }
        root.addSubview(header)

        let sidebar = NSView(frame: NSRect(x: 0, y: footerHeight, width: sidebarWidth, height: bodyHeight))
        sidebar.autoresizingMask = [.height, .maxXMargin]
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = NSColor.dragonSide.cgColor
        let label = NSTextField(labelWithString: L("Мои макросы", "My macros"))
        label.font = .systemFont(ofSize: 12)
        label.textColor = .dragonGray
        label.frame = NSRect(x: 30, y: bodyHeight - 49, width: 170, height: 20)
        label.autoresizingMask = [.minYMargin]
        sidebar.addSubview(label)
        macroCount.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        macroCount.textColor = .dragonText
        macroCount.wantsLayer = true
        macroCount.layer?.borderColor = NSColor.dragonBorder.cgColor
        macroCount.layer?.borderWidth = 1
        macroCount.layer?.cornerRadius = 4
        macroCount.setAccessibilityLabel(L("Количество макросов", "Macro count"))
        macroCount.frame = NSRect(x: 197, y: bodyHeight - 49, width: 34, height: 22)
        macroCount.autoresizingMask = [.minYMargin]
        sidebar.addSubview(macroCount)
        let separator = NSView(frame: NSRect(x: sidebarWidth - 1, y: 0, width: 1, height: bodyHeight))
        separator.autoresizingMask = .height
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.dragonBorder.cgColor
        sidebar.addSubview(separator)
        let scroll = NSScrollView(frame: NSRect(x: 10, y: 79, width: sidebarWidth - 20, height: bodyHeight - 155))
        scroll.autoresizingMask = [.width, .height]
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.scrollerStyle = .overlay
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c"))
        column.resizingMask = .autoresizingMask
        column.minWidth = 210
        column.width = scroll.contentSize.width
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.frame = NSRect(origin: .zero, size: scroll.contentSize)
        table.addTableColumn(column)
        table.headerView = nil
        table.backgroundColor = .clear
        table.rowHeight = 76
        table.intercellSpacing = NSSize(width: 0, height: 8)
        table.selectionHighlightStyle = .regular
        table.dataSource = self
        table.delegate = self
        table.focusRingType = .none
        table.setAccessibilityLabel(L("Список макросов", "Macro list"))
        scroll.documentView = table
        sidebar.addSubview(scroll)
        let add = MotionButton(title: "", target: self, action: #selector(addMacro))
        styleButton(add, title: "＋  " + L("Добавить макрос", "Add macro"), filled: false, size: 12)
        add.frame = NSRect(x: 17, y: 22, width: sidebarWidth - 34, height: 42)
        sidebar.addSubview(add)
        root.addSubview(sidebar)

        editor.frame = NSRect(x: sidebarWidth, y: footerHeight, width: width - sidebarWidth, height: bodyHeight)
        editor.autoresizingMask = [.width, .height]
        editor.wantsLayer = true
        editor.layer?.masksToBounds = true
        root.addSubview(editor)
        backdrop.frame = editor.bounds
        backdrop.autoresizingMask = [.width, .height]
        backdrop.isHidden = Settings.shared.theme != .samurai
        editor.addSubview(backdrop)
        // Пустое состояние объясняет отсутствие редактора и предлагает реальные действия.
        // Демонстрационные макросы в пользовательское хранилище не добавляются.
        placeholder.frame = NSRect(x: 42, y: 185, width: 520, height: 280)
        placeholder.setAccessibilityLabel(L("Пока нет макросов", "No macros yet"))
        let emptyTitle = NSTextField(labelWithString: L("Создайте первый макрос", "Create your first macro"))
        emptyTitle.font = Theme.isSamurai ? (NSFont(name: "Georgia", size: 29) ?? .systemFont(ofSize: 29)) : .systemFont(ofSize: 28, weight: .semibold)
        emptyTitle.textColor = .dragonText
        emptyTitle.frame = NSRect(x: 0, y: 0, width: 520, height: 42)
        placeholder.addSubview(emptyTitle)
        let emptyDescription = NSTextField(wrappingLabelWithString: L(
            "Открывайте приложения и сайты одним сочетанием клавиш. Добавьте макрос или загрузите свой конфиг, чтобы начать.",
            "Open applications and websites with a hotkey. Add a macro or load your configuration to get started."))
        emptyDescription.font = .systemFont(ofSize: 14)
        emptyDescription.textColor = .dragonGray
        emptyDescription.frame = NSRect(x: 0, y: 58, width: 480, height: 65)
        placeholder.addSubview(emptyDescription)
        let emptyAdd = redButton(L("Добавить макрос", "Add macro"), target: self, action: #selector(addMacro))
        emptyAdd.setAccessibilityIdentifier("empty-add")
        emptyAdd.frame = NSRect(x: 0, y: 142, width: 190, height: 44)
        placeholder.addSubview(emptyAdd)
        let emptyLoad = MotionButton(title: "", target: self, action: #selector(loadConfig))
        styleButton(emptyLoad, title: L("Загрузить конфиг", "Load config"), filled: false, size: 12)
        emptyLoad.frame = NSRect(x: 204, y: 142, width: 180, height: 44)
        placeholder.addSubview(emptyLoad)
        let steps = NSTextField(labelWithString: L("Действие  →  Сочетание клавиш  →  Проверка", "Action  →  Hotkey  →  Test"))
        steps.font = .systemFont(ofSize: 11)
        steps.textColor = .dragonGray
        steps.frame = NSRect(x: 0, y: 214, width: 500, height: 22)
        placeholder.addSubview(steps)
        editor.addSubview(placeholder)

        let x: CGFloat = 42
        func place(_ view: NSView, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) {
            view.frame = NSRect(x: x, y: y, width: width, height: height)
            editor.addSubview(view)
            editorControls.append(view)
        }
        editorTitle.font = Theme.editorFont
        editorTitle.textColor = .dragonText
        editorTitle.lineBreakMode = .byTruncatingTail
        place(editorTitle, 33, 440, 48)
        editorNumber.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        editorNumber.textColor = .dragonGray
        editorNumber.wantsLayer = true
        editorNumber.layer?.borderWidth = 1
        editorNumber.layer?.borderColor = NSColor.dragonBorder.cgColor
        editorNumber.layer?.cornerRadius = 4
        place(editorNumber, 47, 30, 23)
        editorNumber.frame.origin.x = x + 465
        editorNumber.setAccessibilityLabel(L("Номер макроса", "Macro number"))
        editorSubtitle.font = .systemFont(ofSize: 12)
        editorSubtitle.textColor = .dragonGray
        place(editorSubtitle, 90, 540, 22)
        place(caption(L("Название", "Name")), 136, 400, 15)
        for field in [nameField, urlField] {
            field.font = .systemFont(ofSize: 14)
            field.textColor = .dragonText
            field.backgroundColor = .dragonField
            field.isBezeled = false
            field.focusRingType = .none
            field.wantsLayer = true
            field.layer?.cornerRadius = 5
            field.layer?.masksToBounds = true
            field.layer?.borderWidth = 1
            field.layer?.borderColor = NSColor.dragonBorder.cgColor
            field.delegate = self
            // Ячейка центрирует текст в увеличенном поле, сохраняя нативное редактирование.
            field.cell = PaddedTextFieldCell(textCell: "")
            field.isEditable = true
            field.isSelectable = true
            field.cell?.isScrollable = true
            field.font = .systemFont(ofSize: 14)
            field.textColor = .dragonText
            field.backgroundColor = .dragonField
            field.isBezeled = false
            field.drawsBackground = true
            field.layer?.backgroundColor = NSColor.dragonField.cgColor
        }
        nameField.placeholderString = L("Например: Почта", "e.g. Mail")
        nameField.setAccessibilityLabel(L("Название макроса", "Macro name"))
        place(nameField, 160, 520, 44)
        place(caption(L("Комбинация клавиш", "Hotkey")), 229, 400, 15)
        hotkeyField.onChange = { [weak self] key in
            guard let self = self else { return }
            if !self.mutate({ $0.hotkey = key }), let index = self.selected {
                self.hotkeyField.hotkey = self.store.macros[index].hotkey
            }
        }
        hotkeyField.onRecording = { [weak self] recording in
            guard let self = self else { return }
            HotkeyCenter.shared.setRecording(recording, macros: self.store.macros, paused: self.store.paused)
            if !recording { self.refreshHotkeyStatus() }
        }
        place(hotkeyField, 253, 318, 54)
        styleButton(clearButton, title: L("Очистить", "Clear"), filled: false, size: 11)
        clearButton.layer?.borderWidth = 0
        clearButton.target = self
        clearButton.action = #selector(clearHotkey)
        place(clearButton, 259, 100, 40)
        clearButton.frame.origin.x = x + 330
        hotkeyStatus.font = .systemFont(ofSize: 10)
        hotkeyStatus.lineBreakMode = .byTruncatingTail
        place(hotkeyStatus, 317, 540, 17)
        place(caption(L("Действие", "Action")), 353, 300, 15)
        for (button, tag) in [(kindApp, 0), (kindUrl, 1)] {
            button.target = self
            button.action = #selector(kindChanged(_:))
            button.tag = tag
            place(button, 377, 180, 40)
        }
        kindUrl.frame.origin.x = x + 182
        place(valueCaption, 442, 500, 15)
        appPopup.target = self
        appPopup.action = #selector(appChosen)
        appPopup.font = .systemFont(ofSize: 13)
        appPopup.setAccessibilityLabel(L("Приложение", "Application"))
        place(appPopup, 466, 520, 44)
        urlField.placeholderString = "https://example.com"
        urlField.setAccessibilityLabel(L("Адрес сайта или ссылка", "Website or link"))
        place(urlField, 466, 520, 44)
        enabledCheck.target = self
        enabledCheck.action = #selector(enabledChanged)
        enabledCheck.contentTintColor = .dragonOK
        enabledCheck.attributedTitle = NSAttributedString(string: L("Макрос включён", "Macro enabled"), attributes: [
            .font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.dragonText])
        place(enabledCheck, 532, 350, 24)
        let test = redButton(L("Проверить", "Test"), target: self, action: #selector(testMacro))
        test.image = NSImage(systemSymbolName: "play", accessibilityDescription: nil)
        test.imagePosition = .imageLeading
        test.imageHugsTitle = true
        test.contentTintColor = .white
        place(test, 581, 155, 42)
        let delete = MotionButton(title: "", target: self, action: #selector(deleteMacro))
        styleButton(delete, title: L("Удалить", "Delete"), filled: false, size: 11)
        delete.layer?.borderWidth = 0
        place(delete, 581, 100, 42)
        delete.frame.origin.x = x + 176

        let footer = NSView(frame: NSRect(x: 0, y: 0, width: width, height: footerHeight))
        footer.autoresizingMask = [.width, .maxYMargin]
        footer.wantsLayer = true
        footer.layer?.backgroundColor = NSColor.dragonSide.cgColor
        let footerLine = NSView(frame: NSRect(x: 0, y: footerHeight - 1, width: width, height: 1))
        footerLine.wantsLayer = true
        footerLine.layer?.backgroundColor = NSColor.dragonBorder.cgColor
        footerLine.autoresizingMask = .width
        footer.addSubview(footerLine)
        pauseButton.isBordered = false
        pauseButton.target = self
        pauseButton.action = #selector(pauseClicked)
        pauseButton.frame = NSRect(x: 22, y: 8, width: 238, height: 24)
        pauseButton.alignment = .left
        pauseButton.font = .systemFont(ofSize: 11)
        pauseButton.toolTip = L("Приостановить / возобновить макросы", "Pause / resume macros")
        footer.addSubview(pauseButton)
        totalText.font = .systemFont(ofSize: 10)
        totalText.textColor = .dragonGray
        totalText.alignment = .right
        totalText.frame = NSRect(x: width - 180, y: 12, width: 155, height: 18)
        totalText.autoresizingMask = [.minXMargin]
        footer.addSubview(totalText)
        root.addSubview(footer)
        refreshSummary()
    }

    /// Движение только визуальное: состояние модели и регистрации не затрагиваются.
    private func animateEntrance() {
        guard Motion.enabled else { return }
        for view in editorControls + [placeholder] where !view.isHidden {
            view.wantsLayer = true
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            fade.duration = 0.45
            let slide = CABasicAnimation(keyPath: "transform.translation.y")
            slide.fromValue = -10
            slide.toValue = 0
            slide.duration = 0.45
            let group = CAAnimationGroup()
            group.animations = [fade, slide]
            group.duration = 0.45
            group.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.75, 0.25, 1)
            view.layer?.add(group, forKey: "editorEntrance")
        }
    }

    func refreshSummary() {
        macroCount.stringValue = String(store.macros.count)
        totalText.stringValue = store.macros.isEmpty ? L("Нет макросов", "No macros") : L("Макросов: ", "Macros: ") + String(store.macros.count)
        pauseButton.title = "●  " + (store.paused ? L("Макросы приостановлены", "Macros paused") : L("Макросы активны", "Macros active"))
        pauseButton.contentTintColor = store.paused ? .dragonGray : .dragonOK
        pauseButton.setAccessibilityLabel(store.paused ? L("Возобновить макросы", "Resume macros") : L("Приостановить макросы", "Pause macros"))
    }

    @objc private func pauseClicked() { onTogglePause?() }

    // MARK: Таблица

    func numberOfRows(in tableView: NSTableView) -> Int { store.macros.count }

    func tableView(_ tv: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { DragonRow() }

    func tableView(_ tv: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        let macro = store.macros[row]
        let cell = NSView(frame: NSRect(x: 0, y: 0, width: 230, height: 76))
        let icon = NSImageView(frame: NSRect(x: 22, y: 39, width: 17, height: 17))
        icon.image = NSImage(systemSymbolName: macro.kind == .url ? "globe" : "app", accessibilityDescription: nil)
        icon.contentTintColor = .dragonGray
        let name = NSTextField(labelWithString: macro.title)
        name.font = .systemFont(ofSize: 14, weight: .medium)
        name.textColor = macro.enabled ? .dragonText : .dragonGray
        name.lineBreakMode = .byTruncatingTail
        name.frame = NSRect(x: 50, y: 37, width: 164, height: 22)
        let key = NSTextField(labelWithString: macro.hotkey?.display ?? L("Без сочетания", "No hotkey"))
        key.font = .systemFont(ofSize: 11)
        key.textColor = .dragonGray
        key.frame = NSRect(x: 50, y: 14, width: 160, height: 18)
        [icon, name, key].forEach { cell.addSubview($0) }
        return cell
    }

    func selectionShouldChange(in tableView: NSTableView) -> Bool { flushPendingEdits() }
    func tableViewSelectionDidChange(_ n: Notification) { loadEditor() }
    func windowShouldClose(_ sender: NSWindow) -> Bool { flushPendingEdits() }

    // MARK: Редактор

    private func loadEditor() {
        loading = true; defer { loading = false }
        guard let i = selected else {
            editorControls.forEach { $0.isHidden = true }; placeholder.isHidden = false
            lastSelectedID = nil
            refreshSummary()
            return
        }
        editorControls.forEach { $0.isHidden = false }; placeholder.isHidden = true
        let m = store.macros[i]
        editorTitle.stringValue = m.title
        editorNumber.stringValue = String(format: "%02d", i + 1)
        if lastSelectedID != m.id { animateEntrance() }
        lastSelectedID = m.id
        nameField.stringValue = m.name
        hotkeyField.hotkey = m.hotkey
        urlField.stringValue = m.url
        enabledCheck.state = m.enabled ? .on : .off
        fillAppPopup()
        updateKindVisibility(m.kind)
        refreshHotkeyStatus()
        refreshSummary()
    }

    private func updateKindVisibility(_ k: ActionKind) {
        valueCaption.stringValue = k == .app ? L("Приложение", "Application").uppercased() : L("Адрес сайта или ссылка", "Website or link").uppercased()
        appPopup.isHidden = k != .app; urlField.isHidden = k != .url
        editorSubtitle.stringValue = k == .app ? L("Открыть приложение по сочетанию клавиш", "Open an application with a hotkey") : L("Открыть сайт по сочетанию клавиш", "Open a website with a hotkey")
        styleButton(kindApp, title: L("Приложение", "Application"), filled: k == .app, size: 12)
        styleButton(kindUrl, title: L("Сайт / ссылка", "Website / link"), filled: k == .url, size: 12)
        for button in [kindApp, kindUrl] {
            let active = button === (k == .app ? kindApp : kindUrl)
            // После смены заливки обновляем и текст: белая надпись на светло-розовом
            // фоне исходного стиля теряла контраст.
            let title = NSMutableAttributedString(attributedString: button.attributedTitle)
            title.addAttribute(.foregroundColor, value: active ? NSColor.dragonText : NSColor.dragonGray,
                               range: NSRange(location: 0, length: title.length))
            button.attributedTitle = title
            button.layer?.backgroundColor = (active ? NSColor.dragonTint : NSColor.dragonField).cgColor
            button.layer?.borderWidth = 1
            button.layer?.borderColor = NSColor.dragonBorder.cgColor
        }
    }

    private func fillAppPopup() {
        guard let i = selected else { return }
        let wasLoading = loading; loading = true; defer { loading = wasLoading }
        let path = store.macros[i].appPath
        appPopup.removeAllItems()
        appPopup.menu?.addItem(NSMenuItem(title: L("— выберите приложение —", "— choose an application —"), action: nil, keyEquivalent: ""))
        var list = apps
        if !path.isEmpty && !list.contains(where: { $0.path == path }) {
            list.insert(InstalledApp(name: FileManager.default.displayName(atPath: path).replacingOccurrences(of: ".app", with: ""), path: path), at: 0)
        }
        for a in list {
            let item = NSMenuItem(title: a.name, action: nil, keyEquivalent: "")
            let icon = NSWorkspace.shared.icon(forFile: a.path); icon.size = NSSize(width: 16, height: 16)
            item.image = icon; item.representedObject = a.path
            appPopup.menu?.addItem(item)
        }
        appPopup.menu?.addItem(.separator())
        let other = NSMenuItem(title: L("Другое приложение…", "Other application…"), action: nil, keyEquivalent: ""); other.tag = 999
        appPopup.menu?.addItem(other)
        if let idx = appPopup.menu?.items.firstIndex(where: { ($0.representedObject as? String) == path }), !path.isEmpty { appPopup.selectItem(at: idx) }
        else { appPopup.selectItem(at: 0) }
    }

    func refreshHotkeyStatus() {
        refreshSummary()
        guard let i = selected else { return }
        let m = store.macros[i]
        func set(_ s: String, _ c: NSColor) { hotkeyStatus.stringValue = s; hotkeyStatus.textColor = c }
        guard let hk = m.hotkey else { set(L("Комбинация не задана", "No hotkey set"), .dragonGray); return }
        if let status = HotkeyCenter.shared.systemError {
            set(L("Ошибка регистрации сочетаний: ", "Hotkey registration error: ") + String(status), .dragonAccentText)
            return
        }
        if store.paused { set(L("Макросы приостановлены (меню в строке меню)", "Macros are paused (menu bar menu)"), .dragonGray); return }
        if !m.enabled { set(L("Макрос выключен", "Macro is disabled"), .dragonGray); return }
        if let other = store.macros.enumerated().first(where: { $0.offset != i && $0.element.enabled && hk.same($0.element.hotkey) }) {
            set(L("Уже используется макросом «\(other.element.title)»", "Already used by “\(other.element.title)”"), .dragonAccentText)
        } else if HotkeyCenter.shared.failed.contains(m.id) {
            set(L("Комбинация занята системой или другим приложением", "Hotkey is taken by the system or another app"), .dragonAccentText)
        } else { set(L("●  Комбинация активна", "●  Hotkey active"), .dragonOK) }
    }

    /// Запись выполняется транзакционно: интерфейс откатывается при ошибке диска.
    @discardableResult
    private func persist(_ proposed: [Macro]) -> Bool {
        do {
            try store.commit(proposed)
            return true
        } catch {
            alert(L("Изменения не сохранены", "Changes were not saved"), error.localizedDescription)
            return false
        }
    }

    @discardableResult
    private func mutate(_ change: (inout Macro) -> Void) -> Bool {
        guard !loading, flushPendingEdits(), let i = selected else { return false }
        var proposed = store.macros
        change(&proposed[i])
        if !persist(proposed) { loadEditor(); return false }
        table.reloadData(forRowIndexes: [i], columnIndexes: [0])
        refreshHotkeyStatus()
        return true
    }

    /// Объединяем последовательные нажатия в одну запись. Перед сменой строки,
    /// закрытием окна, экспортом и выходом ожидающее изменение записывается сразу.
    func controlTextDidChange(_ n: Notification) {
        guard !loading, let field = n.object as? NSTextField,
              field === nameField || field === urlField, let i = selected else { return }
        pendingText = (store.macros[i].id, nameField.stringValue, urlField.stringValue)
        editorTitle.stringValue = nameField.stringValue.isEmpty ? L("Новый макрос", "New macro") : nameField.stringValue
        textSave?.cancel()
        let work = DispatchWorkItem { [weak self] in _ = self?.flushPendingEdits() }
        textSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    @discardableResult
    func flushPendingEdits() -> Bool {
        textSave?.cancel(); textSave = nil
        guard let pending = pendingText else { return true }
        guard let i = store.macros.firstIndex(where: { $0.id == pending.id }) else {
            pendingText = nil; return true
        }
        var proposed = store.macros
        proposed[i].name = pending.name
        proposed[i].url = pending.url
        guard persist(proposed) else { return false }
        pendingText = nil
        table.reloadData(forRowIndexes: [i], columnIndexes: [0])
        return true
    }

    // MARK: Действия

    @objc private func settingsClicked() { if flushPendingEdits() { onOpenSettings?() } }

    // MARK: Загрузка и сохранение конфига

    private func alert(_ title: String, _ info: String) {
        let a = NSAlert(); a.messageText = title; a.informativeText = info; a.alertStyle = .warning
        a.addButton(withTitle: "OK"); a.runModal()
    }

    /// Сохраняет макросы в JSON-файл, выбранный пользователем.
    @objc func saveConfig() {
        guard flushPendingEdits() else { return }
        let p = NSSavePanel()
        p.allowedContentTypes = [.json]; p.canCreateDirectories = true
        p.nameFieldStringValue = "DragonMacros-config.json"
        p.title = L("Сохранить конфиг макросов", "Save macros config"); p.prompt = L("Сохранить", "Save")
        p.beginSheetModal(for: window!) { [weak self] r in
            guard r == .OK, let url = p.url, let self = self else { return }
            do {
                try self.store.exportConfig(to: url)
            } catch {
                self.alert(L("Не удалось сохранить файл", "Could not save the file"), error.localizedDescription)
            }
        }
    }

    /// Загружает макросы из JSON-файла: заменить текущие или добавить к ним.
    @objc func loadConfig() {
        guard flushPendingEdits() else { return }
        let p = NSOpenPanel()
        p.allowedContentTypes = [.json]; p.canChooseDirectories = false; p.allowsMultipleSelection = false
        p.title = L("Загрузить конфиг макросов", "Load macros config"); p.prompt = L("Загрузить", "Load")
        p.beginSheetModal(for: window!) { [weak self] r in
            guard r == .OK, let url = p.url, let self = self else { return }
            let loaded: [Macro]
            do { loaded = try MacroStore.readConfig(from: url) }
            catch {
                self.alert(L("Не удалось загрузить конфиг", "Could not load the config"),
                           error.localizedDescription)
                return
            }
            guard !loaded.isEmpty else {
                self.alert(L("Конфиг пуст", "The config is empty"), L("В файле нет ни одного макроса.", "The file contains no macros.")); return
            }
            var mode: Int
            if self.store.macros.isEmpty { mode = 0 } else {
                let a = NSAlert()
                a.messageText = L("Загрузить \(loaded.count) макр. из файла?", "Load \(loaded.count) macro(s) from the file?")
                a.informativeText = L("Заменить текущие макросы или добавить к ним?", "Replace the current macros or add to them?")
                a.addButton(withTitle: L("Заменить", "Replace")); a.addButton(withTitle: L("Добавить", "Add")); a.addButton(withTitle: L("Отмена", "Cancel"))
                let resp = a.runModal()
                if resp == .alertFirstButtonReturn { mode = 0 } else if resp == .alertSecondButtonReturn { mode = 1 } else { return }
            }
            guard self.flushPendingEdits() else { return }
            let proposed = mode == 0 ? loaded : self.store.macros + loaded
            guard self.persist(proposed) else { return }
            self.table.reloadData()
            if !self.store.macros.isEmpty { self.table.selectRowIndexes([mode == 0 ? 0 : self.store.macros.count - loaded.count], byExtendingSelection: false) }
            self.loadEditor()
        }
    }

    @objc private func addMacro() {
        guard flushPendingEdits(), persist(store.macros + [Macro()]) else { return }
        table.reloadData()
        table.selectRowIndexes([store.macros.count - 1], byExtendingSelection: false)
        table.scrollRowToVisible(store.macros.count - 1)
        window?.makeFirstResponder(nameField); nameField.selectText(nil)
    }

    @objc private func deleteMacro() {
        guard flushPendingEdits(), let i = selected else { return }
        let a = NSAlert(); a.messageText = L("Удалить макрос «\(store.macros[i].title)»?", "Delete macro “\(store.macros[i].title)”?"); a.alertStyle = .warning
        a.addButton(withTitle: L("Удалить", "Delete")); a.addButton(withTitle: L("Отмена", "Cancel"))
        guard a.runModal() == .alertFirstButtonReturn else { return }
        var proposed = store.macros
        proposed.remove(at: i)
        guard persist(proposed) else { return }
        table.reloadData()
        if !store.macros.isEmpty { table.selectRowIndexes([min(i, store.macros.count - 1)], byExtendingSelection: false) }
        loadEditor()
    }

    @objc private func clearHotkey() {
        if mutate({ $0.hotkey = nil }) { hotkeyField.hotkey = nil }
    }
    @objc private func testMacro() { if flushPendingEdits(), let i = selected { runMacro(store.macros[i]) } }
    @objc private func enabledChanged() {
        if !mutate({ $0.enabled = enabledCheck.state == .on }), let i = selected {
            enabledCheck.state = store.macros[i].enabled ? .on : .off
        }
    }

    @objc private func kindChanged(_ sender: NSButton) {
        let k: ActionKind = sender.tag == 0 ? .app : .url
        if mutate({ $0.kind = k }) { updateKindVisibility(k) }
    }

    @objc private func appChosen() {
        guard let item = appPopup.selectedItem else { return }
        if item.tag == 999 {
            let p = NSOpenPanel(); p.allowedContentTypes = [.applicationBundle]; p.directoryURL = URL(fileURLWithPath: "/Applications")
            p.canChooseDirectories = false; p.prompt = L("Выбрать", "Choose")
            if p.runModal() == .OK, let u = p.url { setApp(u.path) } else { fillAppPopup() }
        } else if let path = item.representedObject as? String { setApp(path) }
        else { mutate { $0.appPath = "" } }
    }

    private func setApp(_ path: String) {
        let name = FileManager.default.displayName(atPath: path).replacingOccurrences(of: ".app", with: "")
        if mutate({ $0.appPath = path; if $0.name.isEmpty { $0.name = name } }) { loadEditor() }
        else { fillAppPopup() }
    }
}
