import Carbon
import Foundation

// Автономный раннер позволяет запускать проверки с Command Line Tools без XCTest/Xcode.
private var assertionFailures = 0

class TestCase {
    func setUpWithError() throws {}
    func tearDownWithError() throws {}
}

struct SkipTest: Error {
    let reason: String
    init(_ reason: String) { self.reason = reason }
}

private struct AssertionError: Error {}

func recordFailure(_ message: String, file: StaticString = #filePath, line: UInt = #line) {
    assertionFailures += 1
    print("\(file):\(line): \(message)")
}

func expectEqual<T: Equatable>(_ actual: @autoclosure () throws -> T,
                               _ expected: @autoclosure () throws -> T,
                               file: StaticString = #filePath, line: UInt = #line) {
    do {
        let a = try actual(), b = try expected()
        if a != b { recordFailure("Ожидалось \(b), получено \(a)", file: file, line: line) }
    } catch { recordFailure("Ошибка сравнения: \(error)", file: file, line: line) }
}

func expectTrue(_ value: @autoclosure () throws -> Bool,
                file: StaticString = #filePath, line: UInt = #line) {
    expectEqual(try value(), true, file: file, line: line)
}

func expectFalse(_ value: @autoclosure () throws -> Bool,
                 file: StaticString = #filePath, line: UInt = #line) {
    expectEqual(try value(), false, file: file, line: line)
}

func expectThrows<T>(_ operation: @autoclosure () throws -> T,
                     file: StaticString = #filePath, line: UInt = #line,
                     inspect: (Error) -> Void = { _ in }) {
    do {
        _ = try operation()
        recordFailure("Ожидалась ошибка", file: file, line: line)
    } catch { inspect(error) }
}

func expectNoThrow<T>(_ operation: @autoclosure () throws -> T,
                      file: StaticString = #filePath, line: UInt = #line) {
    do { _ = try operation() }
    catch { recordFailure("Неожиданная ошибка: \(error)", file: file, line: line) }
}

func requireValue<T>(_ value: @autoclosure () throws -> T?,
                     file: StaticString = #filePath, line: UInt = #line) throws -> T {
    if let value = try value() { return value }
    recordFailure("Ожидалось непустое значение", file: file, line: line)
    throw AssertionError()
}

/// Интеграционные проверки работают только с уникальной временной папкой.
/// Системные настройки, реальные макросы и регистрация глобальных клавиш не затрагиваются.
final class MacroStoreTests: TestCase {
    private var directory: URL!
    private var fileURL: URL { directory.appendingPathComponent("data/macros.json") }
    private let fm = FileManager.default

    override func setUpWithError() throws {
        directory = fm.temporaryDirectory.appendingPathComponent("DragonMacrosTests-\(UUID().uuidString)")
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory = directory { try fm.removeItem(at: directory) }
    }

    private func macro(_ name: String = "Почта") -> Macro {
        var value = Macro()
        value.name = name
        value.kind = .url
        value.url = "https://example.com/"
        value.hotkey = Hotkey(keyCode: 0, modifiers: UInt32(cmdKey | optionKey), label: "A")
        return value
    }

    private func writeLegacy(_ list: [Macro], name: String = "import.json") throws -> URL {
        let url = directory.appendingPathComponent(name)
        try JSONEncoder().encode(list).write(to: url)
        return url
    }

    private func permissions(_ url: URL) throws -> Int {
        let attributes = try fm.attributesOfItem(atPath: url.path)
        return (attributes[.posixPermissions] as? NSNumber)?.intValue ?? -1
    }

    func testRoundTripPreservesDataAndUsesPrivatePermissions() throws {
        let original = macro()
        let store = MacroStore(fileURL: fileURL)
        var notifications = 0
        store.onChange = { notifications += 1 }
        try store.commit([original])
        expectEqual(notifications, 1)
        expectEqual(try permissions(fileURL), 0o600)
        expectEqual(try permissions(fileURL.deletingLastPathComponent()), 0o700)

        let reloaded = MacroStore(fileURL: fileURL)
        try reloaded.load()
        expectEqual(reloaded.macros.count, 1)
        expectEqual(reloaded.macros.first?.id, original.id)
        expectEqual(reloaded.macros.first?.name, original.name)
        expectEqual(reloaded.macros.first?.url, original.url)
        expectEqual(reloaded.macros.first?.hotkey, original.hotkey)
    }

    func testFailedWriteKeepsMemoryAndDoesNotNotify() throws {
        let store = MacroStore(fileURL: fileURL)
        let original = macro("Сохранённый")
        try store.commit([original])
        var notifications = 0
        store.onChange = { notifications += 1 }
        // Каталог на месте целевого файла детерминированно запрещает атомарную замену,
        // даже если тест запущен пользователем с расширенными правами.
        try fm.removeItem(at: fileURL)
        try fm.createDirectory(at: fileURL, withIntermediateDirectories: false)
        expectThrows(try store.commit([macro("Не сохранён")]))
        expectEqual(store.macros.map(\.id), [original.id])
        expectEqual(store.macros.first?.name, "Сохранённый")
        expectEqual(notifications, 0)
        let children = try fm.contentsOfDirectory(atPath: fileURL.deletingLastPathComponent().path)
        expectFalse(children.contains { $0.hasSuffix(".tmp") })
    }

    func testCorruptionCreatesUniqueBackupsAndPreservesOriginal() throws {
        let parent = fileURL.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        let damaged = Data("{broken JSON".utf8)
        try damaged.write(to: fileURL)
        for _ in 0..<2 {
            let store = MacroStore(fileURL: fileURL)
            expectThrows(try store.load()) { error in
                guard case StoreError.recovered = error else { return recordFailure("Ожидалось сообщение о резервной копии: \(error)") }
            }
        }
        let backups = try fm.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("macros.corrupt-") }
        expectEqual(backups.count, 2)
        expectEqual(try Data(contentsOf: fileURL), damaged)
        for backup in backups {
            expectEqual(try Data(contentsOf: backup), damaged)
            expectEqual(try permissions(backup), 0o600)
        }
        // После успешного резервирования допускается явное сохранение новых данных.
        let recovered = MacroStore(fileURL: fileURL)
        expectThrows(try recovered.load())
        try recovered.commit([macro()])
        expectEqual(recovered.macros.count, 1)
    }

    func testBackupFailureBlocksSubsequentSave() throws {
        let parent = fileURL.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        let damaged = Data("damaged".utf8)
        try damaged.write(to: fileURL)
        try fm.setAttributes([.posixPermissions: 0o500], ofItemAtPath: parent.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: parent.path) }
        if fm.isWritableFile(atPath: parent.path) {
            throw SkipTest("Пользователь обходит POSIX-права; отказ резервирования не воспроизводим.")
        }
        let store = MacroStore(fileURL: fileURL)
        expectThrows(try store.load())
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: parent.path)
        expectThrows(try store.commit([macro()])) { error in
            guard case StoreError.recoveryBlocked = error else { return recordFailure("Ожидалась блокировка записи: \(error)") }
        }
        expectEqual(try Data(contentsOf: fileURL), damaged)
    }

    func testImportRejectsMoreThan500WithoutTruncation() throws {
        let url = try writeLegacy((0..<501).map { macro("Макрос \($0)") })
        expectThrows(try MacroStore.readConfig(from: url)) { error in
            guard case StoreError.tooManyMacros = error else { return recordFailure("Неверная ошибка: \(error)") }
        }
        let boundary = try writeLegacy((0..<500).map { macro("Макрос \($0)") }, name: "boundary.json")
        expectEqual(try MacroStore.readConfig(from: boundary).count, 500)
    }

    func testOversizedInputIsRejected() throws {
        let url = directory.appendingPathComponent("oversized.json")
        try Data(repeating: 32, count: 2_000_001).write(to: url)
        expectThrows(try MacroStore.readConfig(from: url)) { error in
            expectEqual((error as NSError).code, CocoaError.fileReadTooLarge.rawValue)
        }
    }

    func testWrappedImportValidatesApplicationAndVersion() throws {
        let exported = directory.appendingPathComponent("wrapped.json")
        let store = MacroStore(fileURL: fileURL)
        try store.commit([macro()])
        try store.exportConfig(to: exported)
        let original = try requireValue(JSONSerialization.jsonObject(with: Data(contentsOf: exported)) as? [String: Any])
        for (key, value) in [("app", "OtherApp" as Any), ("version", 2 as Any)] {
            var invalid = original
            invalid[key] = value
            try JSONSerialization.data(withJSONObject: invalid).write(to: exported)
            expectThrows(try MacroStore.readConfig(from: exported)) { error in
                guard case StoreError.unsupportedFormat = error else { return recordFailure("Неверная ошибка: \(error)") }
            }
        }
    }

    func testLegacyImportRegeneratesDuplicateIdentifiers() throws {
        let item = macro()
        let url = try writeLegacy([item, item])
        let imported = try MacroStore.readConfig(from: url)
        expectEqual(imported.count, 2)
        expectEqual(Set(imported.map(\.id)).count, 2)
        expectFalse(imported.contains { $0.id == item.id })
        expectEqual(imported.map(\.name), [item.name, item.name])
    }

    func testExportCanBeImportedAndDoesNotChangeDirectoryPermissions() throws {
        let exportDirectory = directory.appendingPathComponent("public-export")
        try fm.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: exportDirectory.path)
        let exportURL = exportDirectory.appendingPathComponent("macros.json")
        let store = MacroStore(fileURL: fileURL)
        try store.commit([macro()])
        try store.exportConfig(to: exportURL)
        expectEqual(try permissions(exportDirectory), 0o755)
        expectEqual(try permissions(exportURL), 0o600)
        expectEqual(try MacroStore.readConfig(from: exportURL).first?.url, "https://example.com/")
    }

    func testInvalidHotkeysAreRejectedBeforeCommitOrImport() throws {
        let invalidKeys = [
            Hotkey(keyCode: 128, modifiers: UInt32(cmdKey), label: "?"),
            Hotkey(keyCode: 0, modifiers: 1, label: "A"),
            Hotkey(keyCode: 0, modifiers: 0, label: "A")
        ]
        let store = MacroStore(fileURL: fileURL)
        for key in invalidKeys {
            var item = macro()
            item.hotkey = key
            expectThrows(try store.commit([item]))
            let url = try writeLegacy([item])
            expectThrows(try MacroStore.readConfig(from: url))
        }
        var function = macro()
        function.hotkey = Hotkey(keyCode: 122, modifiers: 0, label: "F1")
        expectNoThrow(try store.commit([function]))
    }

    func testCommitRejectsDuplicateIDsAndPreservesPreviousFile() throws {
        let original = macro()
        let store = MacroStore(fileURL: fileURL)
        try store.commit([original])
        let saved = try Data(contentsOf: fileURL)
        expectThrows(try store.commit([original, original]))
        expectEqual(try Data(contentsOf: fileURL), saved)
        expectEqual(store.macros.count, 1)
    }

    func testExportCannotReplaceInternalStoreDirectlyOrThroughDirectorySymlink() throws {
        let store = MacroStore(fileURL: fileURL)
        let original = macro("Внутренние данные")
        try store.commit([original])
        let saved = try Data(contentsOf: fileURL)
        let alias = directory.appendingPathComponent("data-alias")
        try fm.createSymbolicLink(at: alias, withDestinationURL: fileURL.deletingLastPathComponent())
        var notifications = 0
        store.onChange = { notifications += 1 }
        for target in [fileURL, alias.appendingPathComponent("macros.json")] {
            expectThrows(try store.exportConfig(to: target)) { error in
                guard case StoreError.protectedFile = error else {
                    return recordFailure("Ожидалась защита внутреннего файла: \(error)")
                }
            }
            expectEqual(try Data(contentsOf: fileURL), saved)
            expectEqual(store.macros.map(\.id), [original.id])
            expectEqual(store.macros.first?.name, original.name)
            expectEqual(notifications, 0)
            let reloaded = MacroStore(fileURL: fileURL)
            try reloaded.load()
            expectEqual(reloaded.macros.map(\.id), [original.id])
        }
    }

    func testAddingPast500PreservesPreviousStateAndFile() throws {
        let store = MacroStore(fileURL: fileURL)
        let original = (0..<500).map { macro("Макрос \($0)") }
        try store.commit(original)
        let saved = try Data(contentsOf: fileURL)
        var notifications = 0
        store.onChange = { notifications += 1 }
        expectThrows(try store.commit(store.macros + [macro("Лишний")])) { error in
            guard case StoreError.tooManyMacros = error else {
                return recordFailure("Ожидался отказ из-за лимита: \(error)")
            }
        }
        expectEqual(store.macros.map(\.id), original.map(\.id))
        expectEqual(try Data(contentsOf: fileURL), saved)
        expectEqual(notifications, 0)
    }

    func testMissingStoreLoadsEmptyAndOldDefaultNameMigrates() throws {
        let store = MacroStore(fileURL: fileURL)
        expectNoThrow(try store.load())
        expectTrue(store.macros.isEmpty)
        try store.commit([macro("Новый макрос")])
        let reloaded = MacroStore(fileURL: fileURL)
        try reloaded.load()
        expectEqual(reloaded.macros.first?.name, "")
    }

    /// Каждая проверка использует отдельный домен; пользовательские настройки не читаются и не меняются.
    private func withDefaults(_ body: (UserDefaults, String) throws -> Void) throws {
        let suite = "dev.slipcast.dragonmacros.tests.\(UUID().uuidString)"
        let defaults = try requireValue(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults, suite)
    }

    func testSamuraiMigrationPreservesUnrelatedPreferences() throws {
        try withDefaults { defaults, suite in
            defaults.set("dark", forKey: "theme")
            defaults.set("en", forKey: "language")
            defaults.set(false, forKey: "showInDock")
            defaults.set(false, forKey: "showMenuBarIcon")
            defaults.set(true, forKey: "startMinimized")
            let settings = Settings(defaults: defaults)
            expectEqual(settings.theme, .samurai)
            expectTrue(defaults.bool(forKey: "samuraiDesignV1"))
            expectEqual(settings.language, "en")
            expectFalse(settings.showInDock)
            expectFalse(settings.showMenuBarIcon)
            expectTrue(settings.startMinimized)
            let another = Settings(defaults: try requireValue(UserDefaults(suiteName: suite)))
            expectEqual(another.language, "en")
            expectFalse(another.showInDock)
            expectTrue(another.startMinimized)
        }
    }

    func testThemeChoiceAfterMigrationSurvivesNewSettingsInstance() throws {
        try withDefaults { defaults, suite in
            let first = Settings(defaults: defaults)
            expectEqual(first.theme, .samurai)
            first.theme = .original
            let second = Settings(defaults: try requireValue(UserDefaults(suiteName: suite)))
            expectEqual(second.theme, .original)
            expectTrue(defaults.bool(forKey: "samuraiDesignV1"))
        }
    }

    func testAnimationPreferenceDefaultsToEnabledAndPersistsWithNotification() throws {
        try withDefaults { defaults, suite in
            let settings = Settings(defaults: defaults)
            expectTrue(settings.animationsEnabled)
            // Уведомление доставляется синхронно, без run loop и без графического приложения.
            final class Counter { var value = 0 }
            let counter = Counter()
            let observer = NotificationCenter.default.addObserver(forName: .dragonMotionChanged,
                                                                  object: nil, queue: nil) { _ in
                counter.value += 1
            }
            defer { NotificationCenter.default.removeObserver(observer) }
            settings.animationsEnabled = false
            expectEqual(counter.value, 1)
            expectFalse(settings.animationsEnabled)
            let reloaded = Settings(defaults: try requireValue(UserDefaults(suiteName: suite)))
            expectFalse(reloaded.animationsEnabled)
            expectEqual(counter.value, 1)
        }
    }

    func testOversizedStoreIsBackedUpAndDoesNotBlockSaving() throws {
        try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let oversized = Data(repeating: 32, count: 2_000_001)
        try oversized.write(to: fileURL)
        let store = MacroStore(fileURL: fileURL)
        var backup: URL?
        expectThrows(try store.load()) { error in
            guard case StoreError.recovered(let url) = error else { return recordFailure("Ожидалась резервная копия: \(error)") }
            backup = url
        }
        let copy = try requireValue(backup)
        expectEqual(try Data(contentsOf: copy).count, oversized.count)
        expectNoThrow(try store.commit([macro()]))
        expectEqual(store.macros.count, 1)
    }

    func testURLPolicyAllowsWebBlocksLocalAndAsksForOtherSchemes() throws {
        func policy(_ raw: String, trusted: Set<String> = []) throws -> URLPolicy {
            urlPolicy(for: try requireValue(normalizedMacroURL(raw)), trusted: trusted)
        }
        expectEqual(try policy("example.com"), .open)
        expectEqual(try policy("HTTPS://example.com"), .open)
        expectEqual(try policy("mailto:a@example.com"), .open)
        expectEqual(try policy("file:///etc/passwd"), .blocked)
        expectEqual(try policy("javascript:alert(1)"), .blocked)
        expectEqual(try policy("data:text/html,x"), .blocked)
        expectEqual(try policy("smb://server/share"), .confirm("smb"))
        expectEqual(try policy("x-apple.systempreferences:com.apple.preference.security"), .confirm("x-apple.systempreferences"))
        expectEqual(try policy("smb://server/share", trusted: ["smb:server"]), .open)
        expectEqual(try policy("smb://other/share", trusted: ["smb:server"]), .confirm("smb"))
        expectEqual(try policy("ssh://host", trusted: ["ssh:host"]), .confirm("ssh"))
        expectEqual(try policy("tel:5551234", trusted: ["tel:"]), .open)
        expectEqual(try policy("tel:5551234"), .confirm("tel"))
        expectEqual(try policy("file:///tmp", trusted: ["file:"]), .blocked)
        expectEqual(try policy("tel:+100"), .confirm("tel"))
        expectEqual(try requireValue(normalizedMacroURL("localhost:8080/app")).absoluteString, "https://localhost:8080/app")
        expectEqual(try requireValue(normalizedMacroURL("example.com:443")).scheme, "https")
        expectTrue(normalizedMacroURL("   ") == nil)
    }

    func testOnlyLaterDuplicateHotkeysReportConflict() throws {
        var first = macro("Первый"), second = macro("Второй"), disabled = macro("Выключен")
        disabled.enabled = false
        var other = macro("Другой")
        other.hotkey = Hotkey(keyCode: 1, modifiers: UInt32(cmdKey), label: "S")
        second.hotkey = first.hotkey
        first.name = "Первый"
        let list = [disabled, first, other, second]
        expectTrue(HotkeyCenter.conflictOwner(for: 0, in: list) == nil)
        expectTrue(HotkeyCenter.conflictOwner(for: 1, in: list) == nil)
        expectTrue(HotkeyCenter.conflictOwner(for: 2, in: list) == nil)
        expectEqual(HotkeyCenter.conflictOwner(for: 3, in: list)?.id, first.id)
    }

    func testPauseAndTrustedSchemesPersist() throws {
        try withDefaults { defaults, suite in
            let settings = Settings(defaults: defaults)
            expectFalse(settings.macrosPaused)
            expectEqual(settings.trustedURLTargets, [])
            settings.macrosPaused = true
            settings.trustedURLTargets.insert("SMB:nas")
            let reloaded = Settings(defaults: try requireValue(UserDefaults(suiteName: suite)))
            expectTrue(reloaded.macrosPaused)
            expectEqual(reloaded.trustedURLTargets, ["smb:nas"])
        }
    }

    static var allTests = [
        ("testSamuraiMigrationPreservesUnrelatedPreferences", testSamuraiMigrationPreservesUnrelatedPreferences),
        ("testThemeChoiceAfterMigrationSurvivesNewSettingsInstance", testThemeChoiceAfterMigrationSurvivesNewSettingsInstance),
        ("testAnimationPreferenceDefaultsToEnabledAndPersistsWithNotification", testAnimationPreferenceDefaultsToEnabledAndPersistsWithNotification),
        ("testExportCannotReplaceInternalStoreDirectlyOrThroughDirectorySymlink", testExportCannotReplaceInternalStoreDirectlyOrThroughDirectorySymlink),
        ("testAddingPast500PreservesPreviousStateAndFile", testAddingPast500PreservesPreviousStateAndFile),
        ("testRoundTripPreservesDataAndUsesPrivatePermissions", testRoundTripPreservesDataAndUsesPrivatePermissions),
        ("testFailedWriteKeepsMemoryAndDoesNotNotify", testFailedWriteKeepsMemoryAndDoesNotNotify),
        ("testCorruptionCreatesUniqueBackupsAndPreservesOriginal", testCorruptionCreatesUniqueBackupsAndPreservesOriginal),
        ("testBackupFailureBlocksSubsequentSave", testBackupFailureBlocksSubsequentSave),
        ("testImportRejectsMoreThan500WithoutTruncation", testImportRejectsMoreThan500WithoutTruncation),
        ("testOversizedInputIsRejected", testOversizedInputIsRejected),
        ("testWrappedImportValidatesApplicationAndVersion", testWrappedImportValidatesApplicationAndVersion),
        ("testLegacyImportRegeneratesDuplicateIdentifiers", testLegacyImportRegeneratesDuplicateIdentifiers),
        ("testExportCanBeImportedAndDoesNotChangeDirectoryPermissions", testExportCanBeImportedAndDoesNotChangeDirectoryPermissions),
        ("testInvalidHotkeysAreRejectedBeforeCommitOrImport", testInvalidHotkeysAreRejectedBeforeCommitOrImport),
        ("testCommitRejectsDuplicateIDsAndPreservesPreviousFile", testCommitRejectsDuplicateIDsAndPreservesPreviousFile),
        ("testMissingStoreLoadsEmptyAndOldDefaultNameMigrates", testMissingStoreLoadsEmptyAndOldDefaultNameMigrates),
        ("testOversizedStoreIsBackedUpAndDoesNotBlockSaving", testOversizedStoreIsBackedUpAndDoesNotBlockSaving),
        ("testURLPolicyAllowsWebBlocksLocalAndAsksForOtherSchemes", testURLPolicyAllowsWebBlocksLocalAndAsksForOtherSchemes),
        ("testOnlyLaterDuplicateHotkeysReportConflict", testOnlyLaterDuplicateHotkeysReportConflict),
        ("testPauseAndTrustedSchemesPersist", testPauseAndTrustedSchemesPersist)
    ]
}

// Каждая проверка получает новый экземпляр и отдельную временную папку.
var failedTests = 0
var skippedTests = 0
for (name, method) in MacroStoreTests.allTests {
    let test = MacroStoreTests()
    let before = assertionFailures
    var skipped = false
    do {
        try test.setUpWithError()
        try method(test)()
    } catch let error as SkipTest {
        skipped = true
        skippedTests += 1
        print("SKIP: \(name): \(error.reason)")
    } catch {
        recordFailure("\(name): неожиданная ошибка \(error)")
    }
    do { try test.tearDownWithError() }
    catch { recordFailure("\(name): очистка временной папки: \(error)") }
    if assertionFailures > before {
        failedTests += 1
        print("FAIL: \(name)")
    } else if !skipped {
        print("PASS: \(name)")
    }
}
print("Проверок: \(MacroStoreTests.allTests.count); ошибок: \(failedTests); пропущено: \(skippedTests)")
exit(failedTests == 0 ? 0 : 1)
