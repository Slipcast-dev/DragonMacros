import Foundation

/// Ошибки формата и восстановления выводятся пользователю без потери исходных данных.
enum StoreError: LocalizedError {
    case tooManyMacros, invalidHotkey, unsupportedFormat, recoveryBlocked, protectedFile, recovered(URL)

    var errorDescription: String? {
        switch self {
        case .tooManyMacros: return L("Допускается не более 500 макросов. Файл не изменён.", "At most 500 macros are allowed. The file was not changed.")
        case .invalidHotkey: return L("Конфиг содержит недопустимую комбинацию клавиш.", "The config contains an invalid hotkey.")
        case .unsupportedFormat: return L("Неподдерживаемое приложение или версия конфига.", "Unsupported config application or version.")
        case .protectedFile: return L("Выберите другое место: внутренний файл данных нельзя заменять экспортом.", "Choose another location: export cannot replace the internal data file.")
        case .recoveryBlocked: return L("Сохранение заблокировано: не удалось сохранить копию исходного файла. Проверьте доступ к папке данных и перезапустите приложение.", "Saving is blocked: the original file could not be backed up. Check access to the data folder and restart the app.")
        case .recovered(let url): return L("Файл данных повреждён. Исходник сохранён: ", "The data file is damaged. The original was backed up to: ") + url.path
        }
    }
}

/// Хранилище сохраняет предложенный список до изменения состояния и уведомления подписчиков.
/// Передаваемый URL позволяет проверять реальные ошибки файловой системы в изолированной папке.
final class MacroStore {
    static let maxMacros = 500
    static let maxBytes = 2_000_000
    private(set) var macros: [Macro] = []
    var paused = false
    var onChange: (() -> Void)?
    private let fileURL: URL
    private var writesBlocked = false

    init(fileURL: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("DragonMacros/macros.json")) {
        self.fileURL = fileURL
    }

    /// Повреждённый файл копируется под уникальным именем; при неудаче запись запрещается.
    func load() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return }
        writesBlocked = true
        let data = try Self.readBounded(fileURL)
        let decoded: [Macro]
        do {
            decoded = try JSONDecoder().decode([Macro].self, from: data)
            try Self.validate(decoded)
        } catch {
            let backup = fileURL.deletingLastPathComponent()
                .appendingPathComponent("macros.corrupt-\(UUID().uuidString).json")
            // Не удаляем предыдущие копии и не продолжаем при ошибке копирования.
            try fm.copyItem(at: fileURL, to: backup)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
            writesBlocked = false
            throw StoreError.recovered(backup)
        }
        macros = decoded.map { macro in
            var migrated = macro
            if migrated.name == "Новый макрос" { migrated.name = "" }
            return migrated
        }
        writesBlocked = false
    }

    /// Применяет изменение целиком: ошибка записи оставляет прежние данные и регистрации.
    func commit(_ proposed: [Macro]) throws {
        guard !writesBlocked else { throw StoreError.recoveryBlocked }
        try Self.validate(proposed)
        let data = try Self.encode(proposed)
        guard data.count <= Self.maxBytes else { throw CocoaError(.fileReadTooLarge) }
        try Self.writePrivate(data, to: fileURL, privateDirectory: true)
        macros = proposed
        onChange?()
    }

    private struct ConfigFile: Codable {
        var app = "DragonMacros"
        var version = 1
        var macros: [Macro]
    }

    func exportConfig(to url: URL) throws {
        guard url.standardizedFileURL.resolvingSymlinksInPath() != fileURL.standardizedFileURL.resolvingSymlinksInPath() else {
            throw StoreError.protectedFile
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(ConfigFile(macros: macros))
        guard data.count <= Self.maxBytes else { throw CocoaError(.fileReadTooLarge) }
        try Self.writePrivate(data, to: url, privateDirectory: false)
    }

    /// Проверяет формат полностью: превышение лимита не обрезает макросы молча.
    static func readConfig(from url: URL) throws -> [Macro] {
        let data = try readBounded(url)
        var list: [Macro]
        if data.first(where: { ![9, 10, 13, 32].contains($0) }) == 123 {
            let config = try JSONDecoder().decode(ConfigFile.self, from: data)
            guard config.app == "DragonMacros", config.version == 1 else { throw StoreError.unsupportedFormat }
            list = config.macros
        } else {
            list = try JSONDecoder().decode([Macro].self, from: data)
        }
        // Идентификаторы из внешнего файла не считаются доверенными.
        for i in list.indices { list[i].id = UUID() }
        try validate(list)
        return list
    }

    static func validate(_ list: [Macro]) throws {
        guard list.count <= maxMacros else { throw StoreError.tooManyMacros }
        guard Set(list.map(\.id)).count == list.count else { throw StoreError.unsupportedFormat }
        for macro in list {
            if let key = macro.hotkey, !key.isValid { throw StoreError.invalidHotkey }
        }
    }

    /// Читает максимум лимит + 1 байт, не полагаясь на устаревший размер из метаданных.
    private static func readBounded(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while data.count <= maxBytes {
            let chunk = try handle.read(upToCount: min(64 * 1024, maxBytes + 1 - data.count)) ?? Data()
            if chunk.isEmpty { break }
            data.append(chunk)
        }
        guard data.count <= maxBytes else { throw CocoaError(.fileReadTooLarge) }
        return data
    }

    private static func encode(_ list: [Macro]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(list)
    }

    /// Приватный временный файл получает права до записи; rename атомарно заменяет целевой.
    /// Каталог экспорта принадлежит пользователю: его права не меняем.
    static func writePrivate(_ data: Data, to url: URL, privateDirectory: Bool) throws {
        let fm = FileManager.default
        let directory = url.deletingLastPathComponent()
        if privateDirectory {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true,
                                   attributes: [.posixPermissions: 0o700])
            try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        }
        let temporary = directory.appendingPathComponent(".dragonmacros-\(UUID().uuidString).tmp")
        guard fm.createFile(atPath: temporary.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
            throw CocoaError(.fileWriteNoPermission)
        }
        defer { try? fm.removeItem(at: temporary) }
        let handle = try FileHandle(forWritingTo: temporary)
        do {
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
        } catch {
            try? handle.close()
            throw error
        }
        // POSIX rename сохраняет права приватного временного файла при замене.
        guard rename(temporary.path, url.path) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }
}
