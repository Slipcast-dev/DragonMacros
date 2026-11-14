import AppKit
import Carbon
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

// Автозапуск — LaunchAgent в ~/Library/LaunchAgents (работает на macOS 11 и новее).
let agentLabel = "dev.slipcast.dragonmacros"
var agentURL: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist") }
var launchAtLogin: Bool { FileManager.default.fileExists(atPath: agentURL.path) }

/// Возвращает успех операции; интерфейс перечитывает реальное состояние после ошибки.
@discardableResult
func setLaunchAtLogin(_ enabled: Bool) -> Bool {
    do {
        if enabled {
            guard let executable = Bundle.main.executablePath else { throw CocoaError(.fileNoSuchFile) }
            let plist: [String: Any] = ["Label": agentLabel, "ProgramArguments": [executable], "RunAtLoad": true]
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try FileManager.default.createDirectory(at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try MacroStore.writePrivate(data, to: agentURL, privateDirectory: false)
        } else if launchAtLogin {
            try FileManager.default.removeItem(at: agentURL)
        }
        return true
    } catch {
        let alert = NSAlert()
        alert.messageText = L("Не удалось изменить автозапуск", "Could not change launch at login")
        alert.informativeText = error.localizedDescription
        alert.runModal()
        return false
    }
}

extension Notification.Name { static let dragonMotionChanged = Notification.Name("DragonMotionChanged") }
