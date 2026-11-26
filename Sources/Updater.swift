import AppKit
import CryptoKit

// MARK: - Обновления из релизов GitHub

/// Последний опубликованный релиз и его файлы.
struct ReleaseInfo: Equatable {
    let version: String
    let pageURL: URL
    let packageName: String
    let packageURL: URL
    let packageSize: Int
    let checksumsURL: URL
}

enum UpdateError: LocalizedError, Equatable {
    case badResponse(Int), invalidRelease, noPackage, untrustedURL, tooLarge, notPackage,
         checksumMissing, checksumMismatch, cancelled

    var errorDescription: String? {
        switch self {
        case .badResponse(let code) where code == 403 || code == 429:
            return L("GitHub временно ограничил число запросов. Попробуйте позже.", "GitHub is rate-limiting requests. Try again later.")
        case .badResponse(let code):
            return L("Сервер GitHub ответил с ошибкой \(code).", "GitHub responded with error \(code).")
        case .invalidRelease: return L("Не удалось разобрать сведения о релизе.", "Could not read the release information.")
        case .noPackage: return L("В релизе нет установщика для macOS.", "The release has no macOS installer.")
        case .untrustedURL: return L("Адрес файла не принадлежит релизам Dragon Macros на GitHub.", "The file address is not a Dragon Macros GitHub release.")
        case .tooLarge: return L("Файл обновления слишком большой.", "The update file is too large.")
        case .notPackage: return L("Загруженный файл не является установщиком macOS.", "The downloaded file is not a macOS installer.")
        case .checksumMissing: return L("В релизе нет контрольной суммы установщика.", "The release has no checksum for the installer.")
        case .checksumMismatch: return L("Контрольная сумма не совпала: файл повреждён или подменён и удалён.", "Checksum mismatch: the file is damaged or altered and was deleted.")
        case .cancelled: return L("Загрузка отменена.", "The download was cancelled.")
        }
    }
}

/// Чистая логика без сети и интерфейса: её проверяют тесты.
enum UpdateLogic {
    static let repository = "Slipcast-dev/DragonMacros"
    static let latestReleaseURL = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    static let maxPackageBytes = 100_000_000
    static let maxChecksumBytes = 64 * 1024

    /// «v3.1» → «3.1». Допускаются только числовые версии из 1–4 частей.
    static func version(fromTag tag: String) -> String? {
        var value = tag.trimmingCharacters(in: .whitespaces)
        if value.lowercased().hasPrefix("v") { value.removeFirst() }
        guard value.range(of: "^[0-9]{1,6}(\\.[0-9]{1,6}){0,3}$", options: .regularExpression) != nil else { return nil }
        return value
    }

    /// Сравнивает версии по числам: 3.1 > 1.0, 1.10 > 1.9, 1.0 == 1.0.0.
    static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let left = a.split(separator: ".").map { Int($0) ?? 0 }, right = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(left.count, right.count) {
            let l = i < left.count ? left[i] : 0, r = i < right.count ? right[i] : 0
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    static func isNewer(_ remote: String, than local: String) -> Bool { compare(remote, local) == .orderedDescending }

    /// Скачиваем только файлы релизов этого репозитория по HTTPS.
    static func isTrustedAssetURL(_ url: URL) -> Bool {
        url.scheme == "https" && url.host?.lowercased() == "github.com"
            && url.port == nil && url.user == nil && url.password == nil
            && !url.pathComponents.contains("..") && !url.pathComponents.contains(".")
            && url.path.hasPrefix("/\(repository)/releases/download/")
    }

    static func packageName(for version: String) -> String { "DragonMacros-\(version)-macOS.pkg" }

    private struct APIRelease: Decodable {
        let tag_name: String
        let html_url: String
        let draft: Bool?
        let prerelease: Bool?
        let assets: [APIAsset]
    }
    private struct APIAsset: Decodable {
        let name: String
        let browser_download_url: String
        let size: Int
    }

    static func parseLatestRelease(_ data: Data) throws -> ReleaseInfo {
        guard let release = try? JSONDecoder().decode(APIRelease.self, from: data),
              release.draft != true, release.prerelease != true,
              let version = version(fromTag: release.tag_name),
              let page = URL(string: release.html_url) else { throw UpdateError.invalidRelease }
        let name = packageName(for: version)
        guard let package = release.assets.first(where: { $0.name == name }),
              let packageURL = URL(string: package.browser_download_url) else { throw UpdateError.noPackage }
        guard let sums = release.assets.first(where: { $0.name == "SHA256SUMS.txt" }),
              let sumsURL = URL(string: sums.browser_download_url) else { throw UpdateError.checksumMissing }
        guard isTrustedAssetURL(packageURL), isTrustedAssetURL(sumsURL) else { throw UpdateError.untrustedURL }
        guard package.size > 0, package.size <= maxPackageBytes else { throw UpdateError.tooLarge }
        return ReleaseInfo(version: version, pageURL: page, packageName: name, packageURL: packageURL,
                           packageSize: package.size, checksumsURL: sumsURL)
    }

    /// Строка формата shasum: «<64 hex>  <имя>» (имя может начинаться с «*»).
    static func checksum(for file: String, in sums: String) -> String? {
        for line in sums.split(whereSeparator: \.isNewline) {
            let parts = line.split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count == 2 else { continue }
            let hash = parts[0].lowercased()
            var name = parts[1].trimmingCharacters(in: .whitespaces)
            if name.hasPrefix("*") { name.removeFirst() }
            if name == file, hash.count == 64, hash.allSatisfy({ $0.isHexDigit }) { return hash }
        }
        return nil
    }

    /// Хеш считается потоково, без чтения установщика в память целиком.
    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Установщик .pkg — это архив xar: первые байты «xar!».
    static func looksLikePackage(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: 4)) == Data("xar!".utf8)
    }
}

extension Notification.Name { static let dragonUpdateStatusChanged = Notification.Name("DragonUpdateStatusChanged") }

/// Проверяет последний релиз на GitHub, скачивает установщик .pkg, сверяет SHA256
/// из того же релиза и открывает его в «Установщике» macOS. Всё состояние — на главном потоке.
final class Updater: NSObject {
    static let shared = Updater()

    private(set) var isChecking = false
    /// Занято с начала загрузки до закрытия окна установки: повторная проверка не начнёт
    /// вторую загрузку и не удалит готовый к установке файл.
    private(set) var isDownloading = false
    private var timer: Timer?
    private var launchCheck: DispatchWorkItem?
    private var pendingOffer: ReleaseInfo?
    private var progressPanel: UpdateProgressPanel?
    private var currentTask: URLSessionTask?
    private var cancelRequested = false
    private var progressObservation: NSKeyValueObservation?

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 15 * 60
        configuration.httpAdditionalHeaders = ["User-Agent": "DragonMacros/\(currentVersion)"]
        return URLSession(configuration: configuration)
    }()

    var currentVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }

    /// atLaunch: первая проверка через несколько секунд после запуска. Затем — раз в сутки.
    /// Выключение отменяет и таймер, и ещё не выполненную отложенную проверку.
    func startAutomaticChecks(atLaunch: Bool = false) {
        timer?.invalidate(); timer = nil
        launchCheck?.cancel(); launchCheck = nil
        guard Settings.shared.checkForUpdates else { return }
        if atLaunch {
            let work = DispatchWorkItem { [weak self] in self?.check(userInitiated: false) }
            launchCheck = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            guard Settings.shared.checkForUpdates else { return }
            self?.check(userInitiated: false)
        }
    }

    /// Строка состояния для окна настроек.
    var statusText: String {
        if isDownloading { return L("Загрузка обновления…", "Downloading the update…") }
        if isChecking { return L("Проверка…", "Checking…") }
        guard let date = Settings.shared.lastUpdateCheck else { return L("Ещё не проверялось", "Not checked yet") }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Settings.shared.language == "ru" ? "ru_RU" : "en_US")
        formatter.dateStyle = .medium; formatter.timeStyle = .short
        return L("Последняя проверка: ", "Last checked: ") + formatter.string(from: date)
    }

    private func notifyStatus() { NotificationCenter.default.post(name: .dragonUpdateStatusChanged, object: nil) }

    /// Небольшие ответы (API, суммы) загружаются в файл, а не в память, и читаются, только если
    /// укладываются в лимит: огромный ответ не займёт память.
    private func fetchSmall(_ request: URLRequest, limit: Int, completion: @escaping (Result<Data, Error>) -> Void) -> URLSessionTask {
        let task = session.downloadTask(with: request) { location, response, error in
            let result: Result<Data, Error> = Result {
                if let error = error {
                    if (error as? URLError)?.code == .cancelled { throw UpdateError.cancelled }
                    throw error
                }
                if let http = response as? HTTPURLResponse, http.statusCode != 200 { throw UpdateError.badResponse(http.statusCode) }
                guard let location = location else { throw UpdateError.invalidRelease }
                let size = (try FileManager.default.attributesOfItem(atPath: location.path)[.size] as? NSNumber)?.intValue ?? 0
                guard size <= limit else { throw UpdateError.tooLarge }
                return try Data(contentsOf: location)
            }
            DispatchQueue.main.async { completion(result) }
        }
        task.resume()
        return task
    }

    /// userInitiated: показывает результат всегда; фоновая проверка молчит, если обновлений нет или произошла ошибка.
    func check(userInitiated: Bool) {
        guard !isChecking, !isDownloading else {
            if userInitiated { bringProgressForward() }
            return
        }
        isChecking = true; notifyStatus()
        var request = URLRequest(url: UpdateLogic.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        _ = fetchSmall(request, limit: 1_000_000) { [weak self] result in
            self?.finishCheck(result.flatMap { data in Result { try UpdateLogic.parseLatestRelease(data) } }, userInitiated: userInitiated)
        }
    }

    private func finishCheck(_ result: Result<ReleaseInfo, Error>, userInitiated: Bool) {
        isChecking = false
        switch result {
        case .success(let release):
            Settings.shared.lastUpdateCheck = Date()
            notifyStatus()
            if UpdateLogic.isNewer(release.version, than: currentVersion) {
                if !userInitiated && Settings.shared.skippedUpdateVersion == release.version { return }
                if userInitiated { pendingOffer = nil; offer(release, userInitiated: true) }
                else { pendingOffer = release; showPendingOffer() }
            } else if userInitiated {
                inform(L("У вас последняя версия", "You’re up to date"),
                       L("Dragon Macros \(currentVersion) — самая новая версия.", "Dragon Macros \(currentVersion) is the latest version."))
            }
        case .failure(let error):
            notifyStatus()
            if userInitiated { inform(L("Не удалось проверить обновления", "Could not check for updates"), error.localizedDescription) }
        }
    }

    /// Фоновая находка не отнимает фокус: окно появляется, только когда пользователь сам
    /// работает с Dragon Macros и поверх не открыто другое модальное окно.
    func showPendingOffer() {
        guard let release = pendingOffer, NSApp.isActive, NSApp.modalWindow == nil, !isDownloading else { return }
        pendingOffer = nil
        offer(release, userInitiated: false)
    }

    private func offer(_ release: ReleaseInfo, userInitiated: Bool) {
        if userInitiated { NSApp.activate(ignoringOtherApps: true) }
        let alert = NSAlert()
        alert.messageText = L("Доступна версия \(release.version)", "Version \(release.version) is available")
        alert.informativeText = L(
            "У вас версия \(currentVersion). Установщик будет загружен из релиза на GitHub, проверен по SHA256 и открыт в «Установщике» macOS. Макросы и настройки сохранятся.",
            "You have version \(currentVersion). The installer is downloaded from the GitHub release, verified with SHA256 and opened in macOS Installer. Macros and settings are kept.")
        alert.addButton(withTitle: L("Загрузить и установить", "Download and Install"))
        alert.addButton(withTitle: L("Что нового", "Release Notes"))
        alert.addButton(withTitle: L("Позже", "Later"))
        if !userInitiated { alert.addButton(withTitle: L("Пропустить эту версию", "Skip This Version")) }
        let skip = NSApplication.ModalResponse(rawValue: NSApplication.ModalResponse.alertThirdButtonReturn.rawValue + 1)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn { download(release) }
        else if response == .alertSecondButtonReturn { NSWorkspace.shared.open(release.pageURL) }
        else if response == skip { Settings.shared.skippedUpdateVersion = release.version }
    }

    // MARK: Загрузка и установка

    private var updatesDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DragonMacros/Updates", isDirectory: true)
    }

    private func download(_ release: ReleaseInfo) {
        guard !isDownloading else { return }
        isDownloading = true; cancelRequested = false; notifyStatus()
        let panel = UpdateProgressPanel(version: release.version) { [weak self] in
            self?.cancelRequested = true
            self?.currentTask?.cancel()
        }
        progressPanel = panel
        panel.show()
        // Сначала контрольные суммы: без них установщик не загружается.
        currentTask = fetchSmall(URLRequest(url: release.checksumsURL), limit: UpdateLogic.maxChecksumBytes) { [weak self] result in
            guard let self = self else { return }
            if self.cancelRequested { return self.finishDownload(.failure(UpdateError.cancelled)) }
            switch result {
            case .failure(let error): self.finishDownload(.failure(error))
            case .success(let data):
                guard let text = String(data: data, encoding: .utf8),
                      let expected = UpdateLogic.checksum(for: release.packageName, in: text) else {
                    return self.finishDownload(.failure(UpdateError.checksumMissing))
                }
                self.downloadPackage(release, expected: expected)
            }
        }
    }

    private func downloadPackage(_ release: ReleaseInfo, expected: String) {
        let fm = FileManager.default
        let directory = updatesDirectory
        let destination = directory.appendingPathComponent(release.packageName)
        let task = session.downloadTask(with: release.packageURL) { [weak self] location, response, error in
            // Временный файл URLSession удаляется после возврата: переносим и проверяем его здесь.
            let result: Result<URL, Error> = Result {
                if let error = error {
                    if (error as? URLError)?.code == .cancelled { throw UpdateError.cancelled }
                    throw error
                }
                if let http = response as? HTTPURLResponse, http.statusCode != 200 { throw UpdateError.badResponse(http.statusCode) }
                guard let location = location else { throw UpdateError.invalidRelease }
                // Папка содержит только последний загруженный установщик: старые удаляются.
                try? fm.removeItem(at: directory)
                try fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                try fm.moveItem(at: location, to: destination)
                do { try Self.verify(destination, expected: expected) }
                catch { try? fm.removeItem(at: destination); throw error }
                return destination
            }
            DispatchQueue.main.async { self?.finishDownload(result, expected: expected) }
        }
        currentTask = task
        progressObservation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            let fraction = progress.fractionCompleted
            DispatchQueue.main.async { self?.progressPanel?.update(fraction: fraction) }
        }
        if cancelRequested { task.cancel() }
        task.resume()
    }

    /// Размер, SHA256 и формат установщика. Повторяется непосредственно перед открытием.
    private static func verify(_ package: URL, expected: String) throws {
        let size = (try FileManager.default.attributesOfItem(atPath: package.path)[.size] as? NSNumber)?.intValue ?? 0
        guard size > 0, size <= UpdateLogic.maxPackageBytes else { throw UpdateError.tooLarge }
        guard try UpdateLogic.sha256(of: package) == expected else { throw UpdateError.checksumMismatch }
        guard UpdateLogic.looksLikePackage(package) else { throw UpdateError.notPackage }
    }

    private func finishDownload(_ result: Result<URL, Error>, expected: String = "") {
        progressObservation = nil
        currentTask = nil
        progressPanel?.close()
        progressPanel = nil
        switch result {
        case .success(let package):
            install(package, expected: expected)
        case .failure(let error):
            if case UpdateError.cancelled = error {} else {
                inform(L("Не удалось загрузить обновление", "Could not download the update"), error.localizedDescription)
            }
        }
        isDownloading = false
        notifyStatus()
    }

    /// Установщик заменяет приложение в /Applications, поэтому Dragon Macros завершается.
    /// Несохранённые правки записываются обычным путём выхода (applicationShouldTerminate).
    private func install(_ package: URL, expected: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("Обновление готово к установке", "The update is ready to install")
        alert.informativeText = L("Контрольная сумма совпала. Dragon Macros закроется и откроется «Установщик» macOS. После установки запустите приложение снова.",
                                  "The checksum matches. Dragon Macros will quit and macOS Installer will open. Launch the app again after installation.")
        alert.addButton(withTitle: L("Установить", "Install"))
        alert.addButton(withTitle: L("Показать в Finder", "Show in Finder"))
        alert.addButton(withTitle: L("Отмена", "Cancel"))
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            // Файл мог измениться, пока было открыто окно: проверяем его ещё раз прямо перед открытием.
            do { try Self.verify(package, expected: expected) }
            catch {
                try? FileManager.default.removeItem(at: package)
                return inform(L("Не удалось установить обновление", "Could not install the update"), error.localizedDescription)
            }
            guard let installer = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.installer") else {
                NSWorkspace.shared.activateFileViewerSelecting([package]); return
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.open([package], withApplicationAt: installer, configuration: configuration) { _, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.inform(L("Не удалось открыть установщик", "Could not open the installer"), error.localizedDescription)
                    } else {
                        NSApp.terminate(nil)
                    }
                }
            }
        case .alertSecondButtonReturn:
            NSWorkspace.shared.activateFileViewerSelecting([package])
        default: break
        }
    }

    private func bringProgressForward() {
        NSApp.activate(ignoringOtherApps: true)
        progressPanel?.show()
    }

    private func inform(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }
}

/// Небольшое окно с ходом загрузки и кнопкой отмены.
final class UpdateProgressPanel: NSWindowController {
    private let bar = NSProgressIndicator()
    private let label = NSTextField(labelWithString: "")
    private let onCancel: () -> Void

    init(version: String, onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 116),
                            styleMask: [.titled], backing: .buffered, defer: false)
        panel.title = L("Обновление Dragon Macros", "Dragon Macros Update")
        panel.isReleasedWhenClosed = false
        panel.center()
        super.init(window: panel)
        let content = panel.contentView!
        label.stringValue = L("Загрузка версии \(version)…", "Downloading version \(version)…")
        label.frame = NSRect(x: 20, y: 78, width: 340, height: 18)
        bar.frame = NSRect(x: 20, y: 52, width: 340, height: 20)
        bar.isIndeterminate = false
        bar.minValue = 0; bar.maxValue = 1
        let cancel = NSButton(title: L("Отмена", "Cancel"), target: self, action: #selector(cancelClicked))
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        cancel.frame = NSRect(x: 270, y: 12, width: 94, height: 30)
        [label, bar, cancel].forEach { content.addSubview($0) }
    }
    required init?(coder: NSCoder) { fatalError() }

    func show() { showWindow(nil); window?.makeKeyAndOrderFront(nil) }
    func update(fraction: Double) { bar.doubleValue = fraction }
    @objc private func cancelClicked() { onCancel() }
}
