import AppKit
import Carbon
import UniformTypeIdentifiers

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
