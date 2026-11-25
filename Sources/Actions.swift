import AppKit
import Carbon
import UniformTypeIdentifiers

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
        guard let u = normalizedMacroURL(m.url) else { NSSound.beep(); return }
        switch urlPolicy(for: u, trusted: Settings.shared.trustedURLTargets) {
        case .open: NSWorkspace.shared.open(u)
        case .blocked: NSSound.beep()
        case .confirm(let scheme): if confirmScheme(scheme, url: u) { NSWorkspace.shared.open(u) }
        }
    }
}

/// Добавляет https:// к адресу без схемы и экранирует недопустимые символы.
func normalizedMacroURL(_ raw: String) -> URL? {
    var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !s.isEmpty else { return nil }
    // Схема без «//» (mailto:, tel:, javascript:) сохраняется; «host:8080» — это адрес с портом.
    let lower = s.lowercased()
    let hostless = ["mailto:", "tel:", "sms:", "facetime:", "facetime-audio:"].contains { lower.hasPrefix($0) }
    let looksLikePort = s.range(of: "^[A-Za-z0-9.-]+:[0-9]+([/?#]|$)", options: .regularExpression) != nil
    let hasScheme = hostless || (!looksLikePort && s.range(of: "^[A-Za-z][A-Za-z0-9+.-]*:", options: .regularExpression) != nil)
    if !s.contains("://") && !hasScheme { s = "https://" + s }
    let extra = CharacterSet(charactersIn: "%#:/?&=@+;,~")
    let allowed = CharacterSet.urlQueryAllowed.union(.urlHostAllowed).union(.urlPathAllowed).union(extra)
    return URL(string: s) ?? s.addingPercentEncoding(withAllowedCharacters: allowed).flatMap { URL(string: $0) }
}

enum URLPolicy: Equatable { case open, blocked, confirm(String) }

/// Ключ доверия — схема вместе с хостом: «Всегда открывать smb://nas» не разрешает
/// smb://другой-сервер из чужого конфига. У ссылок без хоста (tel:, приложения) — только схема.
func trustKey(for url: URL) -> String? {
    guard let scheme = url.scheme?.lowercased(), !scheme.isEmpty else { return nil }
    return scheme + ":" + (url.host?.lowercased() ?? "")
}

/// Схемы, для которых «Всегда открывать» не предлагается: они меняют систему или подключаются к узлам.
let alwaysConfirmSchemes: Set<String> = ["ssh", "x-apple.systempreferences", "x-apple-helpviewer", "applescript", "shortcuts"]

/// Список разрешённых схем: сайты и почта открываются сразу. Локальные файлы и скрипты
/// запрещены всегда. Прочие схемы (smb, ssh, настройки системы, схемы приложений) могут
/// прийти из чужого конфига, поэтому открываются только после подтверждения пользователя.
func urlPolicy(for url: URL, trusted: Set<String>) -> URLPolicy {
    guard let scheme = url.scheme?.lowercased(), !scheme.isEmpty else { return .blocked }
    if ["http", "https", "mailto"].contains(scheme) { return .open }
    if ["file", "javascript", "data", "vbscript"].contains(scheme) { return .blocked }
    if !alwaysConfirmSchemes.contains(scheme), let key = trustKey(for: url), trusted.contains(key) { return .open }
    return .confirm(scheme)
}

/// Повторное нажатие сочетания во время вопроса не открывает второе окно поверх первого.
private var isConfirmingScheme = false

private func confirmScheme(_ scheme: String, url: URL) -> Bool {
    guard !isConfirmingScheme else { return false }
    isConfirmingScheme = true
    defer { isConfirmingScheme = false }
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = L("Открыть ссылку «\(scheme):»?", "Open a “\(scheme):” link?")
    alert.informativeText = L("Это не адрес сайта: ссылку обработает другое приложение или служба macOS.\n\n",
                              "This is not a website: another app or macOS service will handle it.\n\n") + url.absoluteString
    alert.addButton(withTitle: L("Открыть", "Open"))
    alert.addButton(withTitle: L("Отмена", "Cancel"))
    let target = url.host.map { "\(scheme)://\($0)" } ?? "\(scheme):"
    let canTrust = !alwaysConfirmSchemes.contains(scheme)
    if canTrust { alert.addButton(withTitle: L("Всегда открывать «\(target)»", "Always open “\(target)”")) }
    switch alert.runModal() {
    case .alertFirstButtonReturn: return true
    case .alertThirdButtonReturn where canTrust:
        if let key = trustKey(for: url) { Settings.shared.trustedURLTargets.insert(key) }
        return true
    default: return false
    }
}
