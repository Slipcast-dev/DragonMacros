import AppKit
import Carbon
import UniformTypeIdentifiers

// MARK: - Окно настроек

final class SettingsWindowController: NSWindowController {
    var onAppChange: (() -> Void)?     // Dock / значок в строке меню
    var onUIChange: (() -> Void)?      // язык или стиль: нужно перестроить окна
    private let dockCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let menuCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let loginCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let animationCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let minCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let themePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let langPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let hint = NSTextField(labelWithString: "")

    init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 560),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = L("Настройки", "Settings")
        w.appearance = Theme.appearance
        w.isReleasedWhenClosed = false
        w.center()
        super.init(window: w)
        build(in: w.contentView!)
    }
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil); window?.makeKeyAndOrderFront(nil)
    }

    private func build(in root: NSView) {
        root.wantsLayer = true; root.layer?.backgroundColor = NSColor.dragonBG.cgColor
        let v = FlippedView(frame: root.bounds); v.autoresizingMask = [.width, .height]; root.addSubview(v)
        let s = Settings.shared, x: CGFloat = 28
        func place(_ view: NSView, _ y: CGFloat, _ w: CGFloat = 384, _ h: CGFloat = 20) { view.frame = NSRect(x: x, y: y, width: w, height: h); v.addSubview(view) }
        func check(_ b: NSButton, _ title: String, _ on: Bool, _ action: Selector) {
            b.title = title; b.state = on ? .on : .off; b.target = self; b.action = action
        }

        place(caption(L("Отображение", "Appearance on screen")), 24, 300, 14)
        check(dockCheck, L("Показывать приложение в Dock", "Show app in the Dock"), s.showInDock, #selector(dockChanged)); place(dockCheck, 46)
        check(menuCheck, L("Показывать значок в строке меню", "Show menu bar icon"), s.showMenuBarIcon, #selector(menuChanged)); place(menuCheck, 74)
        hint.font = .systemFont(ofSize: 11); hint.textColor = .dragonGray; hint.stringValue = L("Хотя бы один из значков должен оставаться включённым.", "At least one of the icons must stay enabled.")
        place(hint, 98, 384, 14)

        place(caption(L("Запуск", "Startup")), 136, 300, 14)
        check(loginCheck, L("Запускать при входе в систему", "Launch at login"), launchAtLogin, #selector(loginChanged)); place(loginCheck, 158)
        check(minCheck, L("Запускать в свёрнутом виде", "Start minimized"), s.startMinimized, #selector(minChanged)); place(minCheck, 186)

        place(caption(L("Стиль интерфейса", "Interface style")), 228, 300, 14)
        themePopup.addItems(withTitles: [L("Самурай", "Samurai"), L("Оригинальный бело-красный", "Original white & red"), L("Чёрно-красный", "Black & red"), L("Как в системе", "Match system")])
        themePopup.selectItem(at: [ThemeKind.samurai, .original, .dark, .system].firstIndex(of: s.theme) ?? 0)
        themePopup.target = self; themePopup.action = #selector(themeChanged); place(themePopup, 248, 260, 26)

        let description = NSTextField(wrappingLabelWithString: Theme.styleDescription)
        description.font = .systemFont(ofSize: 11)
        description.textColor = .dragonGray
        place(description, 282, 384, 32)
        check(animationCheck, L("Анимация интерфейса", "Interface animations"), s.animationsEnabled, #selector(animationChanged)); place(animationCheck, 326)
        let motionDescription = NSTextField(wrappingLabelWithString: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? L("Движение отключено системной настройкой macOS «Уменьшение движения».", "Motion is disabled by the macOS Reduce Motion setting.")
            : L("Самурай: движение фона. Все стили: переходы и отклик кнопок.", "Samurai: background motion. All styles: transitions and button feedback."))
        motionDescription.font = .systemFont(ofSize: 10)
        motionDescription.textColor = .dragonGray
        place(motionDescription, 354, 384, 32)
        place(caption(L("Язык", "Language") + " / " + L("Language", "Язык")), 402, 300, 14)
        langPopup.addItems(withTitles: ["Русский", "English"])
        langPopup.selectItem(at: s.language == "ru" ? 0 : 1)
        langPopup.target = self; langPopup.action = #selector(langChanged); place(langPopup, 422, 260, 26)

        place(caption(L("Ссылки", "Links")), 470, 300, 14)
        let reset = NSButton(title: L("Сбросить разрешённые ссылки", "Reset allowed links"), target: self, action: #selector(resetTrustedLinks))
        reset.bezelStyle = .rounded
        place(reset, 490, 260, 28)
        let resetHint = NSTextField(wrappingLabelWithString: L("Ссылки не на сайты снова будут открываться только после подтверждения.",
                                                               "Non-website links will again ask for confirmation before opening."))
        resetHint.font = .systemFont(ofSize: 10); resetHint.textColor = .dragonGray
        place(resetHint, 522, 384, 28)
    }

    @objc private func dockChanged() {
        if dockCheck.state == .off && menuCheck.state == .off { dockCheck.state = .on; NSSound.beep(); return }
        Settings.shared.showInDock = dockCheck.state == .on; onAppChange?()
    }
    @objc private func menuChanged() {
        if menuCheck.state == .off && dockCheck.state == .off { menuCheck.state = .on; NSSound.beep(); return }
        Settings.shared.showMenuBarIcon = menuCheck.state == .on; onAppChange?()
    }
    @objc private func loginChanged() {
        setLaunchAtLogin(loginCheck.state == .on)
        loginCheck.state = launchAtLogin ? .on : .off
    }
    @objc private func animationChanged() { Settings.shared.animationsEnabled = animationCheck.state == .on }
    @objc private func minChanged() { Settings.shared.startMinimized = minCheck.state == .on }
    @objc private func themeChanged() {
        Settings.shared.theme = [ThemeKind.samurai, .original, .dark, .system][max(0, themePopup.indexOfSelectedItem)]
        DispatchQueue.main.async { self.onUIChange?() }
    }
    @objc private func resetTrustedLinks() {
        let count = Settings.shared.trustedURLTargets.count
        Settings.shared.trustedURLTargets = []
        let alert = NSAlert()
        alert.messageText = count == 0 ? L("Разрешённых ссылок нет", "No allowed links") : L("Разрешения сброшены: \(count)", "Permissions reset: \(count)")
        if let window = window { alert.beginSheetModal(for: window) } else { alert.runModal() }
    }
    @objc private func langChanged() {
        Settings.shared.language = langPopup.indexOfSelectedItem == 0 ? "ru" : "en"
        DispatchQueue.main.async { self.onUIChange?() }
    }
}
