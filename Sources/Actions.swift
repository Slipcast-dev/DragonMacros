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
