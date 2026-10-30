import AppKit
import Carbon

// Dragon Macros — программные макросы для macOS: глобальная комбинация клавиш → открыть приложение или ссылку.
// Работает с любой клавиатурой и не использует HID/протокол K530. Глобальные комбинации — через Carbon
// RegisterEventHotKey, поэтому разрешения «Мониторинг ввода» и «Универсальный доступ» не нужны.

// MARK: - Настройки и локализация

enum ThemeKind: String { case original, dark, system }

final class Settings {
    static let shared = Settings()
    private let d = UserDefaults.standard

    var showInDock: Bool {
        get { d.object(forKey: "showInDock") as? Bool ?? true }
        set { d.set(newValue, forKey: "showInDock") }
    }
    var showMenuBarIcon: Bool {
        get { d.object(forKey: "showMenuBarIcon") as? Bool ?? true }
        set { d.set(newValue, forKey: "showMenuBarIcon") }
    }
    var startMinimized: Bool {
        get { d.object(forKey: "startMinimized") as? Bool ?? false }
        set { d.set(newValue, forKey: "startMinimized") }
    }
    var theme: ThemeKind {
        get { ThemeKind(rawValue: d.string(forKey: "theme") ?? "") ?? .original }
        set { d.set(newValue.rawValue, forKey: "theme") }
    }
    /// "ru" или "en"; по умолчанию — язык системы (русский, если он первый в списке, иначе английский).
    var language: String {
        get {
            if let l = d.string(forKey: "language"), l == "ru" || l == "en" { return l }
            return (Locale.preferredLanguages.first ?? "en").hasPrefix("ru") ? "ru" : "en"
        }
        set { d.set(newValue, forKey: "language") }
    }
}

/// Строка на текущем языке интерфейса.
func L(_ ru: String, _ en: String) -> String { Settings.shared.language == "ru" ? ru : en }

// Автозапуск — LaunchAgent в ~/Library/LaunchAgents (работает на macOS 11 и новее).
let agentLabel = "dev.slipcast.dragonmacros"
var agentURL: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist") }
var launchAtLogin: Bool {
    get { FileManager.default.fileExists(atPath: agentURL.path) }
    set {
        if !newValue { try? FileManager.default.removeItem(at: agentURL); return }
        guard let exe = Bundle.main.executablePath else { return }
        let plist: [String: Any] = ["Label": agentLabel, "ProgramArguments": [exe], "RunAtLoad": true]
        try? FileManager.default.createDirectory(at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
            try? data.write(to: agentURL, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: agentURL.path)
        }
    }
}

// MARK: - Цвета (зависят от выбранного стиля)

enum Theme {
    /// Тёмная палитра: стиль «чёрно-красный» или стиль «как в системе» при тёмной теме macOS.
    static var isDark: Bool {
        switch Settings.shared.theme {
        case .original: return false
        case .dark: return true
        case .system: return UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        }
    }
    /// Внешний вид окон: оригинальный и чёрно-красный стили фиксируют светлый/тёмный, системный — следует за macOS.
    static var appearance: NSAppearance? {
        switch Settings.shared.theme {
        case .original: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        case .system: return nil
        }
    }
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: 1) }

extension NSColor {
    static var dragonRed: NSColor { rgb(0.78, 0.06, 0.18) }
    static var dragonDark: NSColor { rgb(0.42, 0.03, 0.10) }
    static var dragonBG: NSColor { Theme.isDark ? rgb(0.09, 0.07, 0.08) : .white }
    static var dragonSide: NSColor { Theme.isDark ? rgb(0.14, 0.08, 0.10) : rgb(0.99, 0.94, 0.94) }
    static var dragonTint: NSColor { Theme.isDark ? rgb(0.30, 0.08, 0.12) : rgb(0.99, 0.94, 0.94) }
    static var dragonText: NSColor { Theme.isDark ? .white : .black }
    static var dragonGray: NSColor { Theme.isDark ? rgb(0.68, 0.62, 0.63) : rgb(0.45, 0.40, 0.40) }
    static var dragonField: NSColor { Theme.isDark ? rgb(0.17, 0.13, 0.14) : .white }
    static var dragonBorder: NSColor { Theme.isDark ? rgb(0.34, 0.28, 0.29) : NSColor(white: 0.80, alpha: 1) }
    /// Красный для текста на фоне окна: в тёмных стилях светлее, чтобы читался.
    static var dragonAccentText: NSColor { Theme.isDark ? rgb(1.0, 0.36, 0.42) : .dragonRed }
    static var dragonOK: NSColor { Theme.isDark ? rgb(0.35, 0.80, 0.45) : rgb(0.10, 0.50, 0.20) }
}

// MARK: - Модель

enum ActionKind: String, Codable { case app, url }

struct Hotkey: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32      // маски Carbon: cmdKey, shiftKey, optionKey, controlKey
    var label: String
    var display: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + label
    }
    func same(_ o: Hotkey?) -> Bool { o != nil && o!.keyCode == keyCode && o!.modifiers == modifiers }
}

struct Macro: Codable {
    var id = UUID()
    var name = ""          // пустое имя показывается как «Новый макрос» на текущем языке
    var hotkey: Hotkey?
    var kind: ActionKind = .app
    var appPath = ""
    var url = ""
    var enabled = true
    var title: String { name.isEmpty ? L("Новый макрос", "New macro") : name }
}

final class MacroStore {
    var macros: [Macro] = []
    var paused = false
    var onChange: (() -> Void)?

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DragonMacros", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        return dir.appendingPathComponent("macros.json")
    }()

    func load() {
        guard let d = try? Data(contentsOf: fileURL) else { return }
        guard var m = try? JSONDecoder().decode([Macro].self, from: d) else {
            // Файл повреждён: сохраняем копию, чтобы следующее сохранение не стёрло данные безвозвратно.
            let bak = fileURL.deletingLastPathComponent().appendingPathComponent("macros.corrupt.json")
            try? FileManager.default.removeItem(at: bak); try? FileManager.default.copyItem(at: fileURL, to: bak)
            return
        }
        // Старые версии сохраняли имя «Новый макрос» буквально — считаем его пустым, чтобы оно переводилось.
        for i in m.indices where m[i].name == "Новый макрос" { m[i].name = "" }
        macros = m
    }

    func save() {
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let d = try? enc.encode(macros) {
            try? d.write(to: fileURL, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        }
        onChange?()
    }
}

// MARK: - Клавиши

let functionKeyCodes: Set<UInt16> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90]
let specialKeyLabels: [UInt16: String] = [
    36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 71: "Clear", 76: "⌤", 114: "Help",
    115: "↖", 116: "⇞", 117: "⌦", 119: "↘", 121: "⇟", 123: "←", 124: "→", 125: "↓", 126: "↑",
    122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9",
    109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15", 106: "F16",
    64: "F17", 79: "F18", 80: "F19", 90: "F20",
]

func carbonModifiers(_ f: NSEvent.ModifierFlags) -> UInt32 {
    let f = f.intersection(.deviceIndependentFlagsMask)
    var m: UInt32 = 0
    if f.contains(.command) { m |= UInt32(cmdKey) }
    if f.contains(.option) { m |= UInt32(optionKey) }
    if f.contains(.control) { m |= UInt32(controlKey) }
    if f.contains(.shift) { m |= UInt32(shiftKey) }
    return m
}

// MARK: - Глобальные комбинации (Carbon)

final class HotkeyCenter {
    static let shared = HotkeyCenter()
    var handler: ((UUID) -> Void)?
    private(set) var failed = Set<UUID>()
    private var refs: [UInt32: (ref: EventHotKeyRef, id: UUID)] = [:]
    private var next: UInt32 = 1
    private var installed = false

    private func installHandler() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            let n = hk.id
            DispatchQueue.main.async { HotkeyCenter.shared.fire(n) }
            return noErr
        }, 1, &spec, nil, nil)
    }

    fileprivate func fire(_ n: UInt32) {
        if let e = refs[n] { handler?(e.id) }
    }

    func unregisterAll() {
        for (_, e) in refs { UnregisterEventHotKey(e.ref) }
        refs.removeAll(); failed.removeAll()
    }

    func register(_ macros: [Macro], paused: Bool) {
        installHandler()
        unregisterAll()
        guard !paused else { return }
        var seen: [Hotkey] = []
        for m in macros where m.enabled {
            guard let hk = m.hotkey else { continue }
            if seen.contains(where: { hk.same($0) }) { failed.insert(m.id); continue }
            var ref: EventHotKeyRef?
            let n = next; next += 1
            let st = RegisterEventHotKey(hk.keyCode, hk.modifiers, EventHotKeyID(signature: OSType(0x44524E47), id: n),
                                         GetApplicationEventTarget(), 0, &ref)
            if st == noErr, let r = ref { refs[n] = (r, m.id); seen.append(hk) } else { failed.insert(m.id) }
        }
    }
}

// MARK: - Выполнение действий

func runMacro(_ m: Macro) {
    switch m.kind {
    case .app:
        var isDir: ObjCBool = false
        guard m.appPath.hasSuffix(".app"), FileManager.default.fileExists(atPath: m.appPath, isDirectory: &isDir), isDir.boolValue else { NSSound.beep(); return }
        let cfg = NSWorkspace.OpenConfiguration(); cfg.activates = true
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: m.appPath), configuration: cfg) { _, err in
            if err != nil { DispatchQueue.main.async { NSSound.beep() } }
        }
    case .url:
        var s = m.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { NSSound.beep(); return }
        if !s.contains("://") && !s.lowercased().hasPrefix("mailto:") { s = "https://" + s }
        let extra = CharacterSet(charactersIn: "%#:/?&=@+;,~")
        let allowed = CharacterSet.urlQueryAllowed.union(.urlHostAllowed).union(.urlPathAllowed).union(extra)
        if let u = URL(string: s) ?? s.addingPercentEncoding(withAllowedCharacters: allowed).flatMap({ URL(string: $0) }) {
            // Локальные файлы и скрипты не открываем: макрос должен открывать только сайты и ссылки.
            let blocked: Set<String> = ["file", "javascript", "data", "vbscript"]
            if let scheme = u.scheme?.lowercased(), !blocked.contains(scheme) { NSWorkspace.shared.open(u) } else { NSSound.beep() }
        } else { NSSound.beep() }
    }
}

// MARK: - Список установленных приложений

struct InstalledApp { let name: String; let path: String }

enum AppCatalog {
    static func load(_ done: @escaping ([InstalledApp]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let roots = ["/Applications", "/Applications/Utilities", "/System/Applications", "/System/Applications/Utilities",
                         NSHomeDirectory() + "/Applications"]
            var seen = Set<String>(), result: [InstalledApp] = []
            func add(_ path: String) {
                guard seen.insert(path).inserted else { return }
                result.append(InstalledApp(name: fm.displayName(atPath: path).replacingOccurrences(of: ".app", with: ""), path: path))
            }
            for root in roots {
                for item in (try? fm.contentsOfDirectory(atPath: root)) ?? [] {
                    let p = root + "/" + item
                    if item.hasSuffix(".app") { add(p) }
                    else {
                        var isDir: ObjCBool = false
                        guard fm.fileExists(atPath: p, isDirectory: &isDir), isDir.boolValue else { continue }
                        for sub in (try? fm.contentsOfDirectory(atPath: p)) ?? [] where sub.hasSuffix(".app") { add(p + "/" + sub) }
                    }
                }
            }
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            DispatchQueue.main.async { done(result) }
        }
    }
}

// MARK: - Интерфейс: вспомогательные элементы

final class FlippedView: NSView { override var isFlipped: Bool { true } }

final class HeaderView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSGradient(starting: .dragonDark, ending: .dragonRed)?.draw(in: bounds, angle: 0)
    }
}

final class DragonRow: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        NSColor.dragonRed.withAlphaComponent(Theme.isDark ? 0.35 : 0.14).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 8, dy: 2), xRadius: 9, yRadius: 9).fill()
    }
}

/// Поле записи комбинации: клик → нажать клавиши. Esc — отмена, Delete — очистить.
final class HotkeyField: NSView {
    var hotkey: Hotkey? { didSet { needsDisplay = true } }
    var onChange: ((Hotkey?) -> Void)?
    var onRecording: ((Bool) -> Void)?
    private(set) var recording = false {
        didSet { needsDisplay = true; if oldValue != recording { onRecording?(recording) } }
    }
    private var hint = ""

    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) { hint = ""; window?.makeFirstResponder(self); recording = true }
    override func resignFirstResponder() -> Bool { recording = false; return true }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if recording { keyDown(with: event); return true }
        return false
    }

    private func stop() { recording = false; window?.makeFirstResponder(nil) }

    override func keyDown(with e: NSEvent) {
        guard recording else { super.keyDown(with: e); return }
        let mods = carbonModifiers(e.modifierFlags)
        if e.keyCode == 53 { stop(); return }
        if mods == 0 && (e.keyCode == 51 || e.keyCode == 117) { hotkey = nil; onChange?(nil); stop(); return }
        if mods == 0 && !functionKeyCodes.contains(e.keyCode) {
            hint = L("Добавьте ⌃, ⌥, ⇧ или ⌘", "Add ⌃, ⌥, ⇧ or ⌘"); needsDisplay = true; NSSound.beep(); return
        }
        let label = specialKeyLabels[e.keyCode] ?? (e.charactersIgnoringModifiers?.uppercased() ?? "?")
        let hk = Hotkey(keyCode: UInt32(e.keyCode), modifiers: mods, label: label)
        hotkey = hk; onChange?(hk); stop()
    }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: r, xRadius: 9, yRadius: 9)
        (recording ? NSColor.dragonTint : NSColor.dragonField).setFill(); path.fill()
        (recording ? NSColor.dragonRed : NSColor.dragonBorder).setStroke()
        path.lineWidth = recording ? 2 : 1; path.stroke()
        let text: String, color: NSColor, font: NSFont
        if recording {
            text = hint.isEmpty ? L("Нажмите комбинацию…", "Press a key combination…") : hint
            color = .dragonAccentText; font = .systemFont(ofSize: 14)
        } else if let hk = hotkey { text = hk.display; color = .dragonText; font = .systemFont(ofSize: 17, weight: .semibold) }
        else { text = L("Нажмите, чтобы задать", "Click to set"); color = .dragonGray; font = .systemFont(ofSize: 14) }
        let s = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        let sz = s.size()
        s.draw(at: NSPoint(x: (bounds.width - sz.width) / 2, y: (bounds.height - sz.height) / 2))
    }
}

func styleButton(_ b: NSButton, title: String, filled: Bool, size: CGFloat = 13) {
    b.isBordered = false; b.wantsLayer = true
    b.layer?.cornerRadius = 8; b.layer?.borderWidth = 1.5; b.layer?.borderColor = NSColor.dragonRed.cgColor
    b.layer?.backgroundColor = (filled ? NSColor.dragonRed : NSColor.clear).cgColor
    let p = NSMutableParagraphStyle(); p.alignment = .center
    b.attributedTitle = NSAttributedString(string: title, attributes: [
        .foregroundColor: filled ? NSColor.white : NSColor.dragonAccentText,
        .font: NSFont.systemFont(ofSize: size, weight: .semibold), .paragraphStyle: p])
}

func redButton(_ title: String, target: AnyObject, action: Selector) -> NSButton {
    let b = NSButton(title: title, target: target, action: action)
    styleButton(b, title: title, filled: true)
    return b
}

func caption(_ s: String) -> NSTextField {
    let l = NSTextField(labelWithString: s.uppercased())
    l.font = .systemFont(ofSize: 10.5, weight: .bold); l.textColor = .dragonAccentText
    return l
}

/// "dragon-emblem" — кремовый круг с драконом (шапка), "dragon-mark" — красный силуэт на прозрачном фоне (водяной знак).
func emblemImage(_ name: String = "dragon-emblem") -> NSImage? {
    Bundle.main.url(forResource: name, withExtension: "png").flatMap { NSImage(contentsOf: $0) }
}

// MARK: - Главное окно

final class MainWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSWindowDelegate {
    let store: MacroStore
    private let table = NSTableView()
    private let editor = FlippedView()
    private let placeholder = NSTextField(labelWithString: L("Выберите макрос слева\nили нажмите «Добавить макрос»", "Select a macro on the left\nor click “Add macro”"))
    private let nameField = NSTextField()
    private let hotkeyField = HotkeyField()
    private let clearButton = NSButton()
    private let hotkeyStatus = NSTextField(labelWithString: "")
    private let kindApp = NSButton(title: "", target: nil, action: nil)
    private let kindUrl = NSButton(title: "", target: nil, action: nil)
    private let valueCaption = caption("")
    private let appPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let urlField = NSTextField()
    private let enabledCheck = NSButton(checkboxWithTitle: L("Макрос включён", "Macro enabled"), target: nil, action: nil)
    private var editorControls: [NSView] = []
    private var apps: [InstalledApp] = []
    private var loading = false
    private var selected: Int? { table.selectedRow >= 0 && table.selectedRow < store.macros.count ? table.selectedRow : nil }
    var selectedIndex: Int? { selected }
    var onOpenSettings: (() -> Void)?

    init(store: MacroStore, selectIndex: Int? = nil) {
        self.store = store
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 580),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        w.title = "Dragon Macros"
        w.minSize = NSSize(width: 800, height: 540)
        w.appearance = Theme.appearance
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
    }

    // MARK: Построение интерфейса

    private func build(in root: NSView) {
        root.wantsLayer = true; root.layer?.backgroundColor = NSColor.dragonBG.cgColor
        let W = root.bounds.width, H = root.bounds.height, headH: CGFloat = 76, sideW: CGFloat = 280

        let header = HeaderView(frame: NSRect(x: 0, y: H - headH, width: W, height: headH)); header.autoresizingMask = [.width, .minYMargin]
        if let img = emblemImage() {
            let iv = NSImageView(frame: NSRect(x: 20, y: 12, width: 52, height: 52)); iv.image = img; iv.imageScaling = .scaleProportionallyUpOrDown
            iv.wantsLayer = true; iv.layer?.cornerRadius = 26; iv.layer?.masksToBounds = true
            iv.layer?.borderWidth = 2; iv.layer?.borderColor = NSColor.white.cgColor
            header.addSubview(iv)
        }
        let title = NSTextField(labelWithString: "Dragon Macros"); title.font = .systemFont(ofSize: 24, weight: .bold); title.textColor = .white
        title.frame = NSRect(x: 86, y: 36, width: 400, height: 30); header.addSubview(title)
        let sub = NSTextField(labelWithString: L("Горячие клавиши для приложений и ссылок", "Hotkeys for apps and links")); sub.font = .systemFont(ofSize: 13)
        sub.textColor = NSColor(white: 1, alpha: 0.82); sub.frame = NSRect(x: 87, y: 14, width: 450, height: 18); header.addSubview(sub)
        // Кнопка настроек
        let gear = NSButton(title: "", target: self, action: #selector(settingsClicked))
        gear.frame = NSRect(x: W - 156, y: 22, width: 136, height: 32); gear.autoresizingMask = [.minXMargin]
        gear.isBordered = false; gear.wantsLayer = true
        gear.layer?.cornerRadius = 8; gear.layer?.borderWidth = 1.5; gear.layer?.borderColor = NSColor.white.cgColor
        gear.layer?.backgroundColor = NSColor(white: 1, alpha: 0.16).cgColor
        gear.attributedTitle = NSAttributedString(string: " " + L("Настройки", "Settings"), attributes: [
            .foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 13, weight: .semibold)])
        if let g = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: L("Настройки", "Settings")) { gear.image = g; gear.imagePosition = .imageLeading }
        gear.contentTintColor = .white; gear.toolTip = L("Настройки (⌘,)", "Settings (⌘,)")
        header.addSubview(gear)
        root.addSubview(header)

        // Левая колонка
        let side = NSView(frame: NSRect(x: 0, y: 0, width: sideW, height: H - headH)); side.autoresizingMask = [.height, .maxXMargin]
        side.wantsLayer = true; side.layer?.backgroundColor = NSColor.dragonSide.cgColor
        let line = NSView(frame: NSRect(x: sideW - 1, y: 0, width: 1, height: side.bounds.height)); line.autoresizingMask = .height
        line.wantsLayer = true; line.layer?.backgroundColor = NSColor.dragonRed.withAlphaComponent(0.25).cgColor
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 60, width: sideW - 1, height: side.bounds.height - 60)); scroll.autoresizingMask = [.width, .height]
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c")); col.resizingMask = .autoresizingMask
        table.addTableColumn(col); table.headerView = nil; table.backgroundColor = .clear
        table.rowHeight = 50; table.intercellSpacing = NSSize(width: 0, height: 2); table.selectionHighlightStyle = .regular
        table.dataSource = self; table.delegate = self; table.focusRingType = .none
        scroll.documentView = table
        let addBtn = redButton("＋  " + L("Добавить макрос", "Add macro"), target: self, action: #selector(addMacro))
        addBtn.frame = NSRect(x: 16, y: 14, width: sideW - 33, height: 32); addBtn.autoresizingMask = [.width, .maxYMargin]
        side.addSubview(scroll); side.addSubview(addBtn); side.addSubview(line)
        root.addSubview(side)

        // Редактор
        editor.frame = NSRect(x: sideW, y: 0, width: W - sideW, height: H - headH); editor.autoresizingMask = [.width, .height]
        root.addSubview(editor)
        if let img = emblemImage("dragon-mark") {
            let wm = NSImageView(frame: NSRect(x: editor.bounds.width - 250, y: editor.bounds.height - 250, width: 230, height: 230))
            wm.image = img; wm.alphaValue = Theme.isDark ? 0.16 : 0.10; wm.imageScaling = .scaleProportionallyUpOrDown; wm.autoresizingMask = [.minXMargin, .minYMargin]
            editor.addSubview(wm)
        }
        placeholder.alignment = .center; placeholder.font = .systemFont(ofSize: 15); placeholder.textColor = .dragonGray
        placeholder.frame = NSRect(x: 0, y: 190, width: editor.bounds.width, height: 50); placeholder.autoresizingMask = [.width]
        editor.addSubview(placeholder)

        let x: CGFloat = 32
        func place(_ v: NSView, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) { v.frame = NSRect(x: x, y: y, width: w, height: h); editor.addSubview(v); editorControls.append(v) }

        place(caption(L("Название", "Name")), 26, 300, 14)
        nameField.font = .systemFont(ofSize: 14); nameField.delegate = self; nameField.placeholderString = L("Например: Почта", "e.g. Mail")
        place(nameField, 44, 480, 28)

        place(caption(L("Комбинация клавиш", "Hotkey")), 92, 300, 14)
        hotkeyField.onChange = { [weak self] hk in self?.mutate { $0.hotkey = hk } }
        hotkeyField.onRecording = { [weak self] rec in
            guard let self = self else { return }
            if rec { HotkeyCenter.shared.unregisterAll() }
            else { HotkeyCenter.shared.register(self.store.macros, paused: self.store.paused); self.refreshHotkeyStatus() }
        }
        place(hotkeyField, 110, 300, 36)
        styleButton(clearButton, title: L("Очистить", "Clear"), filled: false, size: 12)
        clearButton.target = self; clearButton.action = #selector(clearHotkey)
        clearButton.frame = NSRect(x: x + 312, y: 111, width: 90, height: 32); editor.addSubview(clearButton); editorControls.append(clearButton)
        hotkeyStatus.font = .systemFont(ofSize: 12)
        place(hotkeyStatus, 152, 480, 16)

        place(caption(L("Действие", "Action")), 190, 300, 14)
        kindApp.target = self; kindApp.action = #selector(kindChanged(_:)); kindApp.tag = 0
        kindUrl.target = self; kindUrl.action = #selector(kindChanged(_:)); kindUrl.tag = 1
        place(kindApp, 208, 190, 30); place(kindUrl, 208, 190, 30)
        kindUrl.frame.origin.x = x + 200

        place(valueCaption, 256, 400, 14)
        appPopup.target = self; appPopup.action = #selector(appChosen)
        place(appPopup, 274, 480, 28)
        urlField.font = .systemFont(ofSize: 14); urlField.delegate = self; urlField.placeholderString = "https://example.com"
        place(urlField, 274, 480, 28)

        enabledCheck.target = self; enabledCheck.action = #selector(enabledChanged)
        place(enabledCheck, 322, 300, 20)

        let test = redButton(L("Проверить сейчас", "Test now"), target: self, action: #selector(testMacro))
        place(test, 366, 160, 32)
        let del = NSButton(title: "", target: self, action: #selector(deleteMacro))
        styleButton(del, title: L("Удалить", "Delete"), filled: false)
        del.frame = NSRect(x: x + 172, y: 366, width: 100, height: 32); editor.addSubview(del); editorControls.append(del)
    }

    // MARK: Таблица

    func numberOfRows(in tableView: NSTableView) -> Int { store.macros.count }

    func tableView(_ tv: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { DragonRow() }

    func tableView(_ tv: NSTableView, viewFor col: NSTableColumn?, row: Int) -> NSView? {
        let m = store.macros[row]
        let cell = NSView(frame: NSRect(x: 0, y: 0, width: 270, height: 50))
        let name = NSTextField(labelWithString: m.title)
        name.font = .systemFont(ofSize: 14, weight: .semibold); name.lineBreakMode = .byTruncatingTail
        name.textColor = m.enabled ? .dragonText : .dragonGray
        name.frame = NSRect(x: 18, y: 26, width: 230, height: 18)
        let key = NSTextField(labelWithString: m.hotkey?.display ?? "—")
        key.font = .systemFont(ofSize: 12); key.textColor = m.hotkey == nil ? .dragonGray : .dragonAccentText
        key.frame = NSRect(x: 18, y: 7, width: 120, height: 16)
        let kind = NSTextField(labelWithString: m.kind == .app ? L("приложение", "app") : L("ссылка", "link"))
        kind.font = .systemFont(ofSize: 11); kind.textColor = .dragonGray; kind.alignment = .right
        kind.frame = NSRect(x: 150, y: 7, width: 100, height: 16)
        [name, key, kind].forEach { cell.addSubview($0) }
        return cell
    }

    func tableViewSelectionDidChange(_ n: Notification) { loadEditor() }

    // MARK: Редактор

    private func loadEditor() {
        loading = true; defer { loading = false }
        guard let i = selected else {
            editorControls.forEach { $0.isHidden = true }; placeholder.isHidden = false; return
        }
        editorControls.forEach { $0.isHidden = false }; placeholder.isHidden = true
        let m = store.macros[i]
        nameField.stringValue = m.name
        hotkeyField.hotkey = m.hotkey
        urlField.stringValue = m.url
        enabledCheck.state = m.enabled ? .on : .off
        fillAppPopup()
        updateKindVisibility(m.kind)
        refreshHotkeyStatus()
    }

    private func updateKindVisibility(_ k: ActionKind) {
        valueCaption.stringValue = k == .app ? L("Приложение", "Application").uppercased() : L("Адрес сайта или ссылка", "Website or link").uppercased()
        appPopup.isHidden = k != .app; urlField.isHidden = k != .url
        styleButton(kindApp, title: L("Открыть приложение", "Open application"), filled: k == .app)
        styleButton(kindUrl, title: L("Открыть сайт / ссылку", "Open website / link"), filled: k == .url)
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

    private func refreshHotkeyStatus() {
        guard let i = selected else { return }
        let m = store.macros[i]
        func set(_ s: String, _ c: NSColor) { hotkeyStatus.stringValue = s; hotkeyStatus.textColor = c }
        guard let hk = m.hotkey else { set(L("Комбинация не задана", "No hotkey set"), .dragonGray); return }
        if store.paused { set(L("Макросы приостановлены (меню в строке меню)", "Macros are paused (menu bar menu)"), .dragonGray); return }
        if !m.enabled { set(L("Макрос выключен", "Macro is disabled"), .dragonGray); return }
        if let other = store.macros.enumerated().first(where: { $0.offset != i && $0.element.enabled && hk.same($0.element.hotkey) }) {
            set(L("Уже используется макросом «\(other.element.title)»", "Already used by “\(other.element.title)”"), .dragonAccentText)
        } else if HotkeyCenter.shared.failed.contains(m.id) {
            set(L("Комбинация занята системой или другим приложением", "Hotkey is taken by the system or another app"), .dragonAccentText)
        } else { set(L("✓ Активна", "✓ Active"), .dragonOK) }
    }

    private func mutate(_ change: (inout Macro) -> Void) {
        guard !loading, let i = selected else { return }
        change(&store.macros[i])
        store.save()           // перерегистрирует комбинации через onChange
        table.reloadData(forRowIndexes: [i], columnIndexes: [0])
        refreshHotkeyStatus()
    }

    func controlTextDidChange(_ n: Notification) {
        guard let f = n.object as? NSTextField else { return }
        if f === nameField { mutate { $0.name = f.stringValue } }
        else if f === urlField { mutate { $0.url = f.stringValue } }
    }

    // MARK: Действия

    @objc private func settingsClicked() { onOpenSettings?() }

    @objc private func addMacro() {
        store.macros.append(Macro()); store.save(); table.reloadData()
        table.selectRowIndexes([store.macros.count - 1], byExtendingSelection: false)
        table.scrollRowToVisible(store.macros.count - 1)
        window?.makeFirstResponder(nameField); nameField.selectText(nil)
    }

    @objc private func deleteMacro() {
        guard let i = selected else { return }
        let a = NSAlert(); a.messageText = L("Удалить макрос «\(store.macros[i].title)»?", "Delete macro “\(store.macros[i].title)”?"); a.alertStyle = .warning
        a.addButton(withTitle: L("Удалить", "Delete")); a.addButton(withTitle: L("Отмена", "Cancel"))
        guard a.runModal() == .alertFirstButtonReturn else { return }
        store.macros.remove(at: i); store.save(); table.reloadData()
        if !store.macros.isEmpty { table.selectRowIndexes([min(i, store.macros.count - 1)], byExtendingSelection: false) }
        loadEditor()
    }

    @objc private func clearHotkey() { hotkeyField.hotkey = nil; mutate { $0.hotkey = nil } }
    @objc private func testMacro() { if let i = selected { runMacro(store.macros[i]) } }
    @objc private func enabledChanged() { mutate { $0.enabled = enabledCheck.state == .on } }

    @objc private func kindChanged(_ sender: NSButton) {
        let k: ActionKind = sender.tag == 0 ? .app : .url
        updateKindVisibility(k); mutate { $0.kind = k }
    }

    @objc private func appChosen() {
        guard let item = appPopup.selectedItem else { return }
        if item.tag == 999 {
            let p = NSOpenPanel(); p.allowedFileTypes = ["app"]; p.directoryURL = URL(fileURLWithPath: "/Applications")
            p.canChooseDirectories = false; p.prompt = L("Выбрать", "Choose")
            if p.runModal() == .OK, let u = p.url { setApp(u.path) } else { fillAppPopup() }
        } else if let path = item.representedObject as? String { setApp(path) }
        else { mutate { $0.appPath = "" } }
    }

    private func setApp(_ path: String) {
        let name = FileManager.default.displayName(atPath: path).replacingOccurrences(of: ".app", with: "")
        mutate { $0.appPath = path; if $0.name.isEmpty { $0.name = name } }
        loadEditor()
    }
}

// MARK: - Окно настроек

final class SettingsWindowController: NSWindowController {
    var onAppChange: (() -> Void)?     // Dock / значок в строке меню
    var onUIChange: (() -> Void)?      // язык или стиль: нужно перестроить окна
    private let dockCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let menuCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let loginCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let minCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let themePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let langPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let hint = NSTextField(labelWithString: "")

    init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 400),
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
        themePopup.addItems(withTitles: [L("Оригинальный бело-красный", "Original white & red"), L("Чёрно-красный", "Black & red"), L("Как в системе", "Match system")])
        themePopup.selectItem(at: [ThemeKind.original, .dark, .system].firstIndex(of: s.theme) ?? 0)
        themePopup.target = self; themePopup.action = #selector(themeChanged); place(themePopup, 248, 260, 26)

        place(caption(L("Язык", "Language") + " / " + L("Language", "Язык")), 296, 300, 14)
        langPopup.addItems(withTitles: ["Русский", "English"])
        langPopup.selectItem(at: s.language == "ru" ? 0 : 1)
        langPopup.target = self; langPopup.action = #selector(langChanged); place(langPopup, 316, 260, 26)
    }

    @objc private func dockChanged() {
        if dockCheck.state == .off && menuCheck.state == .off { dockCheck.state = .on; NSSound.beep(); return }
        Settings.shared.showInDock = dockCheck.state == .on; onAppChange?()
    }
    @objc private func menuChanged() {
        if menuCheck.state == .off && dockCheck.state == .off { menuCheck.state = .on; NSSound.beep(); return }
        Settings.shared.showMenuBarIcon = menuCheck.state == .on; onAppChange?()
    }
    @objc private func loginChanged() { launchAtLogin = loginCheck.state == .on }
    @objc private func minChanged() { Settings.shared.startMinimized = minCheck.state == .on }
    @objc private func themeChanged() {
        Settings.shared.theme = [ThemeKind.original, .dark, .system][max(0, themePopup.indexOfSelectedItem)]
        DispatchQueue.main.async { self.onUIChange?() }
    }
    @objc private func langChanged() {
        Settings.shared.language = langPopup.indexOfSelectedItem == 0 ? "ru" : "en"
        DispatchQueue.main.async { self.onUIChange?() }
    }
}

// MARK: - Приложение

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = MacroStore()
    private var controller: MainWindowController!
    private var settingsController: SettingsWindowController?
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var pauseItem = NSMenuItem()
    private var autoItem = NSMenuItem()

    func applicationDidFinishLaunching(_ n: Notification) {
        // Один экземпляр: иначе комбинации зарегистрируются дважды.
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: { $0 != NSRunningApplication.current }) {
            NSApp.terminate(nil); return
        }
        store.load()
        store.onChange = { [weak self] in guard let s = self else { return }; HotkeyCenter.shared.register(s.store.macros, paused: s.store.paused) }
        HotkeyCenter.shared.handler = { [weak self] id in
            if let m = self?.store.macros.first(where: { $0.id == id }) { runMacro(m) }
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

        // Системная тема меняется — перестроить интерфейс, если выбран стиль «как в системе».
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil, queue: .main) { [weak self] _ in
            if Settings.shared.theme == .system { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self?.reloadUI() } }
        }
    }

    func applicationShouldHandleReopen(_ app: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if controller.window?.isMiniaturized == true { controller.window?.deminiaturize(nil) }
        controller.show(); return true
    }

    private func makeMainController(selectIndex: Int?) -> MainWindowController {
        let c = MainWindowController(store: store, selectIndex: selectIndex)
        c.onOpenSettings = { [weak self] in self?.openSettings() }
        return c
    }

    /// Применяет «Dock» и «значок в строке меню».
    func applyAppSettings() {
        NSApp.setActivationPolicy(Settings.shared.showInDock ? .regular : .accessory)
        statusItem.isVisible = Settings.shared.showMenuBarIcon
    }

    /// Пересобирает окна и меню после смены языка или стиля, сохраняя положение и выбор.
    func reloadUI() {
        let old = controller!
        let frame = old.window?.frame, wasVisible = old.window?.isVisible ?? false, sel = old.selectedIndex
        old.close()
        controller = makeMainController(selectIndex: sel)
        if let f = frame { controller.window?.setFrame(f, display: false) }
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
        if controller.window?.isMiniaturized == true { controller.window?.deminiaturize(nil) }
        controller.show()
    }

    @objc private func togglePause() {
        store.paused.toggle()
        HotkeyCenter.shared.register(store.macros, paused: store.paused)
    }

    @objc private func toggleAutostart() { launchAtLogin.toggle() }

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
        sub(L("Правка", "Edit"), [NSMenuItem(title: L("Отменить", "Undo"), action: Selector(("undo:")), keyEquivalent: "z"),
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

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
