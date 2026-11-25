import AppKit
import Carbon
import UniformTypeIdentifiers

// MARK: - Приложение

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static let showWindowNotification = Notification.Name("dev.slipcast.dragonmacros.showWindow")
    private let store = MacroStore()
    private var controller: MainWindowController!
    private var settingsController: SettingsWindowController?
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var pauseItem = NSMenuItem()
    private var autoItem = NSMenuItem()

    func applicationDidFinishLaunching(_ n: Notification) {
        // Один экземпляр: иначе комбинации зарегистрируются дважды. Повторный запуск
        // просит уже работающую копию показать окно — даже если у неё нет значка в Dock.
        if let id = Bundle.main.bundleIdentifier,
           let running = NSRunningApplication.runningApplications(withBundleIdentifier: id).first(where: { $0 != NSRunningApplication.current }) {
            DistributedNotificationCenter.default().postNotificationName(Self.showWindowNotification, object: id,
                                                                         userInfo: nil, deliverImmediately: true)
            running.activate(options: [])
            NSApp.terminate(nil); return
        }
        if let id = Bundle.main.bundleIdentifier {
            DistributedNotificationCenter.default().addObserver(forName: Self.showWindowNotification, object: id, queue: .main) { [weak self] _ in
                self?.openWindow()
            }
        }
        store.paused = Settings.shared.macrosPaused
        var loadError: Error?
        do { try store.load() } catch { loadError = error }
        store.onChange = { [weak self] in
            guard let self = self else { return }
            HotkeyCenter.shared.register(self.store.macros, paused: self.store.paused)
            self.controller?.refreshSummary()
        }
        HotkeyCenter.shared.handler = { [weak self] id in
            if let self = self, !self.store.paused,
               let macro = self.store.macros.first(where: { $0.id == id && $0.enabled }) { runMacro(macro) }
        }
        HotkeyCenter.shared.register(store.macros, paused: store.paused)

        if let b = statusItem.button {
            if let url = Bundle.main.url(forResource: "StatusIcon@2x", withExtension: "png"), let img = NSImage(contentsOf: url) {
                img.size = NSSize(width: 18, height: 18); img.isTemplate = true; b.image = img
            } else { b.title = "DM" }
        }
        menu.delegate = self; statusItem.menu = menu
        controller = makeMainController(selectIndex: nil)
        buildMenus()
        applyAppSettings()

        // Запуск в свёрнутом виде: с иконкой в Dock окно сворачивается в Dock, без неё — просто не показывается.
        if Settings.shared.startMinimized {
            if Settings.shared.showInDock { controller.show(); controller.window?.miniaturize(nil) }
        } else { controller.show() }

        if let error = loadError {
            let alert = NSAlert()
            alert.messageText = L("Не удалось загрузить макросы", "Could not load macros")
            alert.informativeText = error.localizedDescription
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }

        // Системная тема меняется — перестроить интерфейс, если выбран стиль «как в системе».
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil, queue: .main) { [weak self] _ in
            if Settings.shared.theme == .system { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self?.reloadUI() } }
        }
    }

    /// Не завершаем процесс, если ожидающее изменение не удалось записать.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        controller == nil || controller.flushPendingEdits() ? .terminateNow : .terminateCancel
    }

    /// Сочетание, занятое другим приложением, могло освободиться, пока мы были в фоне.
    func applicationDidBecomeActive(_ notification: Notification) {
        guard controller != nil else { return }
        HotkeyCenter.shared.retryFailed(store.macros, paused: store.paused)
        controller.refreshHotkeyStatus()
    }

    func applicationShouldHandleReopen(_ app: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if controller.window?.isMiniaturized == true { controller.window?.deminiaturize(nil) }
        controller.show(); return true
    }

    private func makeMainController(selectIndex: Int?) -> MainWindowController {
        let c = MainWindowController(store: store, selectIndex: selectIndex)
        c.onOpenSettings = { [weak self] in self?.openSettings() }
        c.onTogglePause = { [weak self] in self?.togglePause() }
        return c
    }

    /// Применяет «Dock» и «значок в строке меню».
    func applyAppSettings() {
        NSApp.setActivationPolicy(Settings.shared.showInDock ? .regular : .accessory)
        statusItem.isVisible = Settings.shared.showMenuBarIcon
    }

    /// Пересобирает окна и меню после смены языка или стиля, сохраняя положение и выбор.
    func reloadUI() {
        guard controller.flushPendingEdits() else { return }
        let old = controller!
        let frame = old.window?.frame, wasVisible = old.window?.isVisible ?? false, sel = old.selectedIndex
        old.close()
        controller = makeMainController(selectIndex: sel)
        if var frame = frame, let window = controller.window {
            frame.size.width = max(frame.width, window.minSize.width)
            frame.size.height = max(frame.height, window.minSize.height)
            window.setFrame(frame, display: false)
        }
        if wasVisible { controller.show() }
        if let sc = settingsController {
            let sf = sc.window?.frame, sv = sc.window?.isVisible ?? false
            sc.close()
            settingsController = nil
            if sv { openSettings(); if let f = sf { settingsController?.window?.setFrameOrigin(f.origin) } }
        }
        buildMenus()
    }

    @objc func openSettings() {
        if settingsController == nil {
            let sc = SettingsWindowController()
            sc.onAppChange = { [weak self] in self?.applyAppSettings() }
            sc.onUIChange = { [weak self] in self?.reloadUI() }
            settingsController = sc
        }
        settingsController?.show()
    }

    func menuWillOpen(_ menu: NSMenu) {
        pauseItem.state = store.paused ? .off : .on
        pauseItem.title = store.paused ? L("Макросы приостановлены", "Macros paused") : L("Макросы активны", "Macros active")
        autoItem.state = launchAtLogin ? .on : .off
    }

    @objc private func openWindow() {
        guard controller != nil else { return }
        if controller.window?.isMiniaturized == true { controller.window?.deminiaturize(nil) }
        controller.show()
    }

    @objc private func togglePause() {
        store.paused.toggle()
        Settings.shared.macrosPaused = store.paused
        HotkeyCenter.shared.register(store.macros, paused: store.paused)
        controller.refreshHotkeyStatus()
    }

    @objc private func toggleAutostart() { setLaunchAtLogin(!launchAtLogin) }

    /// Меню в строке меню и главное меню приложения (нужно для ⌘C/⌘V/⌘A в полях ввода, ⌘W/⌘Q и ⌘,).
    private func buildMenus() {
        menu.removeAllItems()
        let open = NSMenuItem(title: L("Открыть Dragon Macros", "Open Dragon Macros"), action: #selector(openWindow), keyEquivalent: ""); open.target = self
        let settings = NSMenuItem(title: L("Настройки…", "Settings…"), action: #selector(openSettings), keyEquivalent: ""); settings.target = self
        pauseItem = NSMenuItem(title: "", action: #selector(togglePause), keyEquivalent: ""); pauseItem.target = self
        autoItem = NSMenuItem(title: L("Запускать при входе в систему", "Launch at login"), action: #selector(toggleAutostart), keyEquivalent: ""); autoItem.target = self
        let quit = NSMenuItem(title: L("Выйти", "Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        [open, settings, .separator(), pauseItem, autoItem, .separator(), quit].forEach { menu.addItem($0) }
        menuWillOpen(menu)

        let main = NSMenu()
        func sub(_ title: String, _ items: [NSMenuItem]) {
            let host = NSMenuItem(); main.addItem(host)
            let m = NSMenu(title: title); items.forEach { m.addItem($0) }; host.submenu = m
        }
        let prefs = NSMenuItem(title: L("Настройки…", "Settings…"), action: #selector(openSettings), keyEquivalent: ","); prefs.target = self
        sub("Dragon Macros", [prefs, .separator(),
                              NSMenuItem(title: L("Скрыть Dragon Macros", "Hide Dragon Macros"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"),
                              .separator(), NSMenuItem(title: L("Выйти", "Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")])
        let loadItem = NSMenuItem(title: L("Загрузить конфиг…", "Load Config…"), action: #selector(MainWindowController.loadConfig), keyEquivalent: "o")
        let saveItem = NSMenuItem(title: L("Сохранить конфиг…", "Save Config…"), action: #selector(MainWindowController.saveConfig), keyEquivalent: "s")
        sub(L("Файл", "File"), [loadItem, saveItem])
        sub(L("Правка", "Edit"), [NSMenuItem(title: L("Отменить", "Undo"), action: Selector(("undo:")), keyEquivalent: "z"),
                       { let redo = NSMenuItem(title: L("Повторить", "Redo"), action: Selector(("redo:")), keyEquivalent: "z")
                         redo.keyEquivalentModifierMask = [.command, .shift]; return redo }(),
                       .separator(),
                       NSMenuItem(title: L("Вырезать", "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x"),
                       NSMenuItem(title: L("Копировать", "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c"),
                       NSMenuItem(title: L("Вставить", "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v"),
                       NSMenuItem(title: L("Выделить всё", "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")])
        sub(L("Окно", "Window"), [NSMenuItem(title: L("Закрыть", "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"),
                     NSMenuItem(title: L("Свернуть", "Minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")])
        NSApp.mainMenu = main
    }
}
