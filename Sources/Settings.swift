import AppKit
import Carbon
import ServiceManagement
import UniformTypeIdentifiers

// MARK: - Настройки и локализация

enum ThemeKind: String { case samurai, original, dark, system }

final class Settings {
    static let shared = Settings()
    private let d: UserDefaults

    var showInDock: Bool {
        get { d.object(forKey: "showInDock") as? Bool ?? true }
        set { d.set(newValue, forKey: "showInDock") }
    }
    var showMenuBarIcon: Bool {
        get { d.object(forKey: "showMenuBarIcon") as? Bool ?? true }
        set { d.set(newValue, forKey: "showMenuBarIcon") }
    }
    /// Пауза переживает перезапуск: иначе макросы молча включались бы снова.
    var macrosPaused: Bool {
        get { d.bool(forKey: "macrosPaused") }
        set { d.set(newValue, forKey: "macrosPaused") }
    }
    /// Пары «схема:хост» ссылок не на сайты, которые пользователь разрешил открывать без вопроса.
    /// Сбрасываются кнопкой в настройках.
    var trustedURLTargets: Set<String> {
        get { Set((d.stringArray(forKey: "trustedURLTargets") ?? []).map { $0.lowercased() }) }
        set { d.set(newValue.sorted(), forKey: "trustedURLTargets") }
    }
    /// Фоновая проверка обновлений при запуске и раз в сутки; по умолчанию включена.
    var checkForUpdates: Bool {
        get { d.object(forKey: "checkForUpdates") as? Bool ?? true }
        set { d.set(newValue, forKey: "checkForUpdates") }
    }
    /// Версия, о которой фоновая проверка больше не напоминает. Ручная проверка её показывает.
    var skippedUpdateVersion: String? {
        get { d.string(forKey: "skippedUpdateVersion") }
        set { d.set(newValue, forKey: "skippedUpdateVersion") }
    }
    var lastUpdateCheck: Date? {
        get { d.object(forKey: "lastUpdateCheck") as? Date }
        set { d.set(newValue, forKey: "lastUpdateCheck") }
    }
    var startMinimized: Bool {
        get { d.object(forKey: "startMinimized") as? Bool ?? false }
        set { d.set(newValue, forKey: "startMinimized") }
    }
    /// Версия оформления мигрируется один раз; последующий выбор пользователя сохраняется.
    init(defaults: UserDefaults = .standard) {
        d = defaults
        if !d.bool(forKey: "samuraiDesignV1") {
            d.set(ThemeKind.samurai.rawValue, forKey: "theme")
            d.set(true, forKey: "samuraiDesignV1")
        }
    }
    var animationsEnabled: Bool {
        get { d.object(forKey: "animationsEnabled") as? Bool ?? true }
        set { d.set(newValue, forKey: "animationsEnabled"); NotificationCenter.default.post(name: .dragonMotionChanged, object: nil) }
    }
    var theme: ThemeKind {
        get { ThemeKind(rawValue: d.string(forKey: "theme") ?? "") ?? .samurai }
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

// Автозапуск: на macOS 13+ — системный элемент входа (SMAppService), на macOS 11–12 или
// при его отказе — LaunchAgent в ~/Library/LaunchAgents, указывающий на текущий исполняемый файл.
let agentLabel = "dev.slipcast.dragonmacros"
var agentURL: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist") }

/// LaunchAgent действителен, только если запускает именно эту копию приложения.
/// После переноса приложения старый plist указывает в пустоту и считается выключенным.
var legacyAgentIsValid: Bool {
    guard let data = try? Data(contentsOf: agentURL),
          let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
          let arguments = plist["ProgramArguments"] as? [String], let program = arguments.first,
          let executable = Bundle.main.executablePath else { return false }
    return URL(fileURLWithPath: program).resolvingSymlinksInPath() == URL(fileURLWithPath: executable).resolvingSymlinksInPath()
}

var launchAtLogin: Bool {
    if #available(macOS 13.0, *) {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval: return true
        default: break
        }
    }
    return legacyAgentIsValid
}

private func removeLegacyAgent() throws {
    if FileManager.default.fileExists(atPath: agentURL.path) { try FileManager.default.removeItem(at: agentURL) }
}

private func writeLegacyAgent() throws {
    guard let executable = Bundle.main.executablePath else { throw CocoaError(.fileNoSuchFile) }
    let plist: [String: Any] = ["Label": agentLabel, "ProgramArguments": [executable], "RunAtLoad": true]
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try FileManager.default.createDirectory(at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try MacroStore.writePrivate(data, to: agentURL, privateDirectory: false)
}

/// Возвращает успех операции; интерфейс перечитывает реальное состояние после ошибки.
@discardableResult
func setLaunchAtLogin(_ enabled: Bool) -> Bool {
    do {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            if enabled {
                do {
                    if service.status != .enabled { try service.register() }
                } catch {
                    // Например, ad-hoc сборка вне /Applications: остаётся LaunchAgent.
                    try writeLegacyAgent()
                    return true
                }
                // Старый агент запустил бы второй экземпляр вместе с элементом входа.
                try removeLegacyAgent()
                if service.status == .requiresApproval { askForLoginItemApproval() }
                return true
            }
            if service.status == .enabled || service.status == .requiresApproval { try service.unregister() }
            try removeLegacyAgent()
            return true
        }
        if enabled { try writeLegacyAgent() } else { try removeLegacyAgent() }
        return true
    } catch {
        let alert = NSAlert()
        alert.messageText = L("Не удалось изменить автозапуск", "Could not change launch at login")
        alert.informativeText = error.localizedDescription
        alert.runModal()
        return false
    }
}

@available(macOS 13.0, *)
private func askForLoginItemApproval() {
    let alert = NSAlert()
    alert.messageText = L("Разрешите автозапуск", "Allow launch at login")
    alert.informativeText = L("macOS требует подтвердить Dragon Macros в «Системные настройки → Основные → Объекты входа».",
                              "macOS needs you to approve Dragon Macros in System Settings → General → Login Items.")
    alert.addButton(withTitle: L("Открыть настройки", "Open Settings"))
    alert.addButton(withTitle: L("Позже", "Later"))
    if alert.runModal() == .alertFirstButtonReturn { SMAppService.openSystemSettingsLoginItems() }
}

extension Notification.Name { static let dragonMotionChanged = Notification.Name("DragonMotionChanged") }
