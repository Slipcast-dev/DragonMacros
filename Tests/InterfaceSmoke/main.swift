import AppKit
import Carbon
import QuartzCore

// Проверка реальных AppKit-контролов с временным хранилищем, без регистрации
// глобальных сочетаний и без чтения пользовательского macros.json.
// Тест временно меняет оформление и восстанавливает точные прежние значения.
let preferenceKeys = ["theme", "language", "animationsEnabled", "samuraiDesignV1"]
let previousPreferences = preferenceKeys.map { ($0, UserDefaults.standard.object(forKey: $0)) }
func restorePreferences() {
    for (key, value) in previousPreferences {
        if let value = value { UserDefaults.standard.set(value, forKey: key) }
        else { UserDefaults.standard.removeObject(forKey: key) }
    }
}
defer { restorePreferences() }
let app = NSApplication.shared
Settings.shared.language = "ru"
Settings.shared.theme = .samurai
Settings.shared.animationsEnabled = false
let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("DragonInterface-\(UUID().uuidString)")
defer { try? FileManager.default.removeItem(at: temporary) }
let store = MacroStore(fileURL: temporary.appendingPathComponent("macros.json"))
var browser = Macro()
browser.name = "Браузер"; browser.kind = .url; browser.url = "https://example.com"
browser.hotkey = Hotkey(keyCode: 11, modifiers: UInt32(cmdKey | optionKey), label: "B")
var terminal = Macro()
terminal.name = "Терминал"; terminal.kind = .app
terminal.appPath = "/System/Applications/Utilities/Terminal.app"
try store.commit([browser, terminal])
let controller = MainWindowController(store: store)
let window = controller.window!
let content = window.contentView!
func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
func require(_ value: Bool, _ message: String) {
    if !value {
        restorePreferences()
        try? FileManager.default.removeItem(at: temporary)
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}
let views = descendants(content)
let fields = views.compactMap { $0 as? NSTextField }.filter { $0.cell is PaddedTextFieldCell }
require(fields.count == 2, "Два поля редактора")
for field in fields {
    require(field.isEditable && field.isSelectable, "Редактирование и выделение доступны")
    require(field.drawsBackground, "Фон поля виден")
    require(field.cell?.isScrollable == true, "Однострочная прокрутка")
    require(field.cell!.drawingRect(forBounds: field.bounds).height > 0, "Непустая область текста")
}
let table = views.compactMap { $0 as? NSTableView }.first!
require(table.tableColumns.first!.width >= 210, "Список не обрезает названия до нескольких букв")
let name = fields.first { $0.stringValue == "Браузер" }!
name.selectText(nil)
let fieldEditor = name.currentEditor() as? NSTextView
require(fieldEditor != nil, "AppKit создаёт нативный полевой редактор")
fieldEditor!.insertText("Проверка сохранения", replacementRange: NSRange(location: 0, length: fieldEditor!.string.utf16.count))
window.makeFirstResponder(nil)
require(name.stringValue == "Проверка сохранения", "Нативный ввод изменил текст поля")
require(controller.flushPendingEdits(), "Ожидающий текст сохраняется")
require(store.macros[0].name == "Проверка сохранения", "Изменение попало в хранилище")
let toggle = views.compactMap { $0 as? SamuraiToggle }.first!
toggle.performClick(nil)
require(!store.macros[0].enabled, "Переключатель выключает макрос одним нажатием")
toggle.performClick(nil)
require(store.macros[0].enabled, "Повторное нажатие включает макрос")
for size in [NSSize(width:1160,height:800), NSSize(width:1000,height:760)] {
    window.setContentSize(size)
    content.layoutSubtreeIfNeeded()
    for button in views.compactMap({ $0 as? NSButton }).filter({ $0.action == NSSelectorFromString("testMacro") || $0.action == NSSelectorFromString("deleteMacro") }) {
        require(button.superview!.bounds.contains(button.frame), "Нижние кнопки помещаются при \(size)")
    }
}
require(window.contentMinSize.height >= 760, "Минимум задан для области содержимого")
name.stringValue = "Браузер"
controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: name))
require(controller.flushPendingEdits(), "Демонстрационный заголовок восстановлен")
window.setContentSize(NSSize(width:1160,height:800))
content.layoutSubtreeIfNeeded()
if CommandLine.arguments.count > 1,
   let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) {
    window.effectiveAppearance.performAsCurrentDrawingAppearance {
        content.cacheDisplay(in: content.bounds, to: bitmap)
    }
    for field in fields {
        let point = field.convert(NSPoint(x: field.bounds.maxX - 20, y: field.bounds.midY), to: content)
        let scaleX = CGFloat(bitmap.pixelsWide) / content.bounds.width
        let scaleY = CGFloat(bitmap.pixelsHigh) / content.bounds.height
        let color = bitmap.colorAt(x: Int(point.x * scaleX), y: Int((content.bounds.height - point.y) * scaleY))!.usingColorSpace(.sRGB)!
        // Сравниваем пиксели одного bitmap: профиль дисплея может менять абсолютные RGB.
        let outside = field.convert(NSPoint(x: field.bounds.maxX - 20, y: -10), to: content)
        let background = bitmap.colorAt(x: Int(outside.x * scaleX), y: Int((content.bounds.height - outside.y) * scaleY))!.usingColorSpace(.sRGB)!
        require(abs(color.redComponent - background.redComponent) > 0.015, "Фон поля отличается от поверхности редактора")
    }
    if let data = bitmap.representation(using: .png, properties: [:]) {
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
}
// Регрессия счётчиков: цифры любого допустимого разряда центрируются в исходной рамке.
let badge = CenteredBadge(frame: NSRect(x: 0, y: 0, width: 36, height: 24))
for value in ["0", "1", "10", "100", "500"] {
    badge.stringValue = value
    let rect = badge.textRect
    require(abs(rect.midX - badge.bounds.midX) < 0.01 && abs(rect.midY - badge.bounds.midY) < 0.01,
            "Счётчик \(value) центрирован по двум осям")
    require(badge.bounds.contains(rect), "Счётчик \(value) помещается без обрезания")
    require(badge.accessibilityValue() as? String == value, "Accessibility передаёт значение счётчика")
}

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".build/interface-tests/window.png")
let outputDirectory = output.deletingLastPathComponent()
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

/// Рендерим реальное дерево AppKit; пиксели проверяем в свободных от текста местах.
func snapshot(_ controller: MainWindowController, name: String) throws -> NSBitmapImageRep {
    let content = controller.window!.contentView!
    content.layoutSubtreeIfNeeded()
    let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds)!
    controller.window!.effectiveAppearance.performAsCurrentDrawingAppearance {
        content.cacheDisplay(in: content.bounds, to: bitmap)
    }
    require(bitmap.pixelsWide > 0 && bitmap.pixelsHigh > 0, "Непустой bitmap \(name)")
    try bitmap.representation(using: .png, properties: [:])!.write(to: outputDirectory.appendingPathComponent(name + ".png"))
    return bitmap
}

func pixel(_ bitmap: NSBitmapImageRep, content: NSView, view: NSView, point: NSPoint) -> NSColor {
    let converted = view.convert(point, to: content)
    let x = Int(converted.x * CGFloat(bitmap.pixelsWide) / content.bounds.width)
    let y = Int((content.bounds.height - converted.y) * CGFloat(bitmap.pixelsHigh) / content.bounds.height)
    return bitmap.colorAt(x: min(max(x, 0), bitmap.pixelsWide - 1),
                          y: min(max(y, 0), bitmap.pixelsHigh - 1))!.usingColorSpace(.sRGB)!
}

var headerSamples: [ThemeKind: NSColor] = [:]
for theme in [ThemeKind.samurai, .original, .dark, .system] {
    Settings.shared.theme = theme
    let themed = MainWindowController(store: store)
    let content = themed.window!.contentView!
    let all = descendants(content)
    let header = all.compactMap { $0 as? HeaderView }.first!
    let backdrop = all.compactMap { $0 as? SamuraiBackdrop }.first!
    require(Theme.usesCrimsonHeader == [.original, .dark].contains(theme), "Политика красной шапки \(theme)")
    require(backdrop.isHidden == (theme != .samurai), "Рисунок доступен только в Samurai")
    let image = try snapshot(themed, name: "theme-" + theme.rawValue)
    let color = pixel(image, content: content, view: header, point: NSPoint(x: 500, y: 15))
    headerSamples[theme] = color
    if theme == .original || theme == .dark {
        require(color.redComponent > color.greenComponent * 1.5, "Красная шапка в \(theme)")
    } else if theme == .samurai {
        require(abs(color.redComponent - color.greenComponent) < 0.06 && color.redComponent < 0.25,
                "Угольная шапка Samurai")
    }
    let surface = pixel(image, content: content, view: content, point: NSPoint(x: 800, y: 100))
    if theme == .original { require(surface.redComponent > 0.85 && surface.greenComponent > 0.85, "Белая поверхность Original") }
    if theme == .dark { require(surface.redComponent < 0.2 && surface.greenComponent < 0.2, "Тёмная поверхность Dark") }
    themed.close()
}
require(abs(headerSamples[.samurai]!.redComponent - headerSamples[.original]!.redComponent) > 0.1,
        "Фактические пиксели шапок Original и Samurai отличаются")

// Пустое состояние действительно ведёт к редактору, а не добавляет демонстрационные данные.
Settings.shared.theme = .samurai
let emptyStore = MacroStore(fileURL: temporary.appendingPathComponent("empty/macros.json"))
let empty = MainWindowController(store: emptyStore)
let emptyViews = descendants(empty.window!.contentView!)
require(emptyStore.macros.isEmpty, "Пустое хранилище остаётся пустым до действия")
require(emptyViews.compactMap { $0 as? NSTextField }.contains { $0.stringValue == "Создайте первый макрос" && !$0.isHiddenOrHasHiddenAncestor },
        "В пустом состоянии показан понятный заголовок")
_ = try snapshot(empty, name: "empty-state")
let emptyAdd = emptyViews.compactMap { $0 as? NSButton }.first { $0.accessibilityIdentifier() == "empty-add" }!
emptyAdd.performClick(nil)
require(emptyStore.macros.count == 1, "Кнопка пустого состояния создаёт ровно один макрос")
require(descendants(empty.window!.contentView!).compactMap { $0 as? NSTextField }
    .contains { $0.cell is PaddedTextFieldCell && !$0.isHiddenOrHasHiddenAncestor && $0.isEditable },
    "После добавления доступен нативный редактор")
empty.close()

// Проверяем реальный action всплывающего списка и сохранение ожидающего текста при перестроении.
var rebuilt = MainWindowController(store: store)
let settingsController = SettingsWindowController()
let popups = descendants(settingsController.window!.contentView!).compactMap { $0 as? NSPopUpButton }
let themePopup = popups.first { $0.numberOfItems == 4 }!
var callbacks = 0
settingsController.onUIChange = {
    require(rebuilt.flushPendingEdits(), "Перед перестроением сохранён ожидающий текст")
    rebuilt.close()
    rebuilt = MainWindowController(store: store)
    callbacks += 1
}
let pendingName = descendants(rebuilt.window!.contentView!).compactMap { $0 as? NSTextField }
    .first { $0.cell is PaddedTextFieldCell && $0.stringValue == "Браузер" }!
pendingName.stringValue = "Сохранено при смене темы"
rebuilt.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: pendingName))
for (index, theme) in [ThemeKind.samurai, .original, .dark, .system].enumerated() {
    let before = callbacks
    themePopup.selectItem(at: index)
    require(themePopup.sendAction(themePopup.action!, to: themePopup.target), "Popup отправил action")
    let deadline = Date().addingTimeInterval(2)
    while callbacks == before && Date() < deadline {
        _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
    }
    require(callbacks == before + 1 && Settings.shared.theme == theme, "Тема \(theme) применена через настройки")
    require(store.macros[0].name == "Сохранено при смене темы", "Перестроение сохраняет ожидающий ввод")
    _ = try snapshot(rebuilt, name: "popup-" + theme.rawValue)
}
rebuilt.close()
settingsController.close()

// Структурный контракт Core Animation: статичные PNG не доказывают движение presentation layer.
func layers(_ layer: CALayer) -> [CALayer] { [layer] + (layer.sublayers ?? []).flatMap(layers) }
Settings.shared.theme = .samurai
Settings.shared.animationsEnabled = true
let motion = SamuraiBackdrop(frame: NSRect(x: 0, y: 0, width: 900, height: 680))
motion.layoutSubtreeIfNeeded()
require(motion.artworkFrame.width == 390 && motion.artworkFrame.height == 610, "Композиция сохраняет локальный размер 390×610")
let motionLayers = layers(motion.layer!)
let sun = motionLayers.first { $0.name == "samurai.sun" }!
let orbit = motionLayers.first { $0.name == "samurai.orbit" }!
let inks = motionLayers.filter { $0.name?.hasPrefix("samurai.ink.") == true }.compactMap { $0 as? CAShapeLayer }
require(inks.count == 3, "Три локальных мазка туши")
for ink in inks {
    let pathBounds = ink.path!.boundingBoxOfPath
    require(ink.bounds.contains(pathBounds) && pathBounds.width <= 390, "Мазок задан внутри локального холста, не через форму")
}
motion.reconcileMotion(isActive: true)
if Motion.enabled {
    require(motion.motionIsRunning, "Активная композиция запускает движение")
    let breathe = sun.animation(forKey: "breathe")!
    require(abs(breathe.duration * (breathe.autoreverses ? 2 : 1) - 9) < 0.01, "Полный цикл дыхания 9 секунд")
    require(abs(orbit.animation(forKey: "orbit")!.duration - 40) < 0.01, "Оборот орбиты 40 секунд")
    require(inks.allSatisfy { $0.animation(forKey: "brush") != nil }, "Мазки имеют анимацию появления")
    require(motionLayers.filter { $0.animation(forKey: "drift") != nil }.count == 3, "Три частицы с дрейфом")
} else {
    require(!motion.motionIsRunning && motionLayers.allSatisfy { ($0.animationKeys() ?? []).isEmpty },
            "Системное Reduce Motion запрещает движение")
}
// Скрытый несмонтированный слой может не иметь presentation: это диагностическое
// наблюдение, а не подтверждение воспроизведения анимации в пользовательском окне.
CATransaction.flush()
let beforePresentation = sun.presentation()?.transform
_ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.15))
let afterPresentation = sun.presentation()?.transform
if let before = beforePresentation, let after = afterPresentation {
    print("INFO: detached presentation available, changed=\(!CATransform3DEqualToTransform(before, after))")
} else {
    print("INFO: detached presentation unavailable; real-window motion remains unverified")
}
for active in [false, true, false] {
    motion.reconcileMotion(isActive: active)
    require(motion.motionIsRunning == (active && Motion.enabled), "Жизненный цикл движения: active=\(active)")
}
motion.isHidden = true
motion.reconcileMotion(isActive: true)
require(!motion.motionIsRunning, "Скрытый рисунок не анимируется")
motion.isHidden = false
motion.setMotionEnabled(false)
motion.reconcileMotion(isActive: true)
require(!motion.motionIsRunning, "Локальный выключатель останавливает движение")
motion.setMotionEnabled(true)
Settings.shared.animationsEnabled = false
motion.reconcileMotion(isActive: true)
require(!motion.motionIsRunning && motionLayers.allSatisfy { ($0.animationKeys() ?? []).isEmpty }, "Настройка убирает все анимации")
Settings.shared.animationsEnabled = true
Settings.shared.theme = .original
motion.reconcileMotion(isActive: true)
require(!motion.motionIsRunning, "Другие темы не запускают рисунок Samurai")
// У backing layer NSView неявный opacity-переход подавлялся: проверяем явную CA-анимацию.
do {
    let savedMotion = Settings.shared.animationsEnabled
    defer { Settings.shared.animationsEnabled = savedMotion }
    Settings.shared.animationsEnabled = true
    let button = MotionButton(frame: NSRect(x: 0, y: 0, width: 150, height: 40))
    button.setHovered(true)
    require(abs((button.layer?.opacity ?? 0) - 0.85) < 0.001, "Hover изменяет целевую прозрачность")
    if Motion.enabled {
        require(button.layer?.animation(forKey: "hover") != nil, "Hover имеет явную анимацию AppKit")
    }
    button.setHovered(false)
    require(button.layer?.opacity == 1, "Выход указателя восстанавливает прозрачность")
    Settings.shared.animationsEnabled = false
    button.setHovered(true)
    require(button.layer?.animation(forKey: "hover") == nil, "Отключение движения убирает hover-анимацию")
}
print("PASS: AppKit fields, pending edits, badge geometry, empty state, four rendered themes, popup actions, CA motion contracts")
