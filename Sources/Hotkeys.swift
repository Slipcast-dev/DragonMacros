import AppKit
import Carbon
import UniformTypeIdentifiers

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

/// Менеджер перерегистрирует сочетания только при изменении их состава.
/// При записи нового сочетания обработка событий приостанавливается отдельно от паузы.
final class HotkeyCenter {
    static let shared = HotkeyCenter()
    var handler: ((UUID) -> Void)?
    private(set) var failed = Set<UUID>()
    private(set) var systemError: OSStatus?
    private var refs: [UInt32: (ref: EventHotKeyRef, id: UUID)] = [:]
    private var next: UInt32 = 1
    private var installed = false
    private var suspended = false
    private var paused = false
    private var registrationBlocked = false

    private struct Registration: Equatable {
        let id: UUID
        let code: UInt32
        let modifiers: UInt32
    }
    private var registered: [Registration]?
    /// Состав последней регистрации и макросы, сочетания которых ОС отклонила.
    private var pendingTarget: [Registration]?
    private var systemRefused = Set<UUID>()

    private func installHandler() -> Bool {
        guard !installed else { return true }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var key = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &key)
            guard status == noErr else { return status }
            guard key.signature == OSType(0x44524E47) else { return OSStatus(eventNotHandledErr) }
            let number = key.id
            DispatchQueue.main.async { HotkeyCenter.shared.fire(number) }
            return noErr
        }, 1, &spec, nil, nil)
        installed = status == noErr
        if !installed { systemError = status }
        return installed
    }

    private func fire(_ number: UInt32) {
        guard !suspended, !paused, !registrationBlocked, let entry = refs[number] else { return }
        handler?(entry.id)
    }

    /// Не забываем ссылки на сочетания, которые ОС не смогла снять: можно повторить попытку.
    @discardableResult
    func unregisterAll() -> Bool {
        registered = nil
        failed.removeAll()
        var retained: [UInt32: (ref: EventHotKeyRef, id: UUID)] = [:]
        for (number, entry) in refs {
            let status = UnregisterEventHotKey(entry.ref)
            if status != noErr {
                systemError = status
                retained[number] = entry
                failed.insert(entry.id)
            }
        }
        refs = retained
        return retained.isEmpty
    }

    func setRecording(_ recording: Bool, macros: [Macro], paused: Bool) {
        suspended = recording
        if recording { unregisterAll() }
        else { register(macros, paused: paused) }
    }

    func register(_ macros: [Macro], paused: Bool) {
        self.paused = paused
        guard !suspended else { return }
        let desired = macros.filter { $0.enabled && $0.hotkey != nil }.map {
            Registration(id: $0.id, code: $0.hotkey!.keyCode, modifiers: $0.hotkey!.modifiers)
        }
        let target = paused ? [] : desired
        guard registered != target else { return }
        systemError = nil
        guard unregisterAll() else {
            // До успешного снятия старых регистраций события не исполняются.
            registrationBlocked = true
            failed.formUnion(desired.map(\.id))
            return
        }
        registrationBlocked = false
        guard !paused else { registered = []; return }
        guard installHandler() else { failed = Set(desired.map(\.id)); return }
        // Отказ ОС (сочетание занято другим приложением) повторяется при следующем вызове:
        // кэш состава не запоминается, пока все системные регистрации не прошли.
        systemRefused.removeAll()
        for macro in macros where macro.enabled {
            guard let key = macro.hotkey else { continue }
            guard key.isValid else { failed.insert(macro.id); continue }
            var reference: EventHotKeyRef?
            let number = next
            next = next == UInt32.max ? 1 : next + 1
            guard refs[number] == nil else { failed.insert(macro.id); continue }
            let duplicate = desired.first { $0.code == key.keyCode && $0.modifiers == key.modifiers }
            guard duplicate?.id == macro.id else { failed.insert(macro.id); continue }
            let status = RegisterEventHotKey(key.keyCode, key.modifiers,
                EventHotKeyID(signature: OSType(0x44524E47), id: number), GetApplicationEventTarget(), 0, &reference)
            if status == noErr, let reference = reference { refs[number] = (reference, macro.id) }
            else { failed.insert(macro.id); systemRefused.insert(macro.id) }
        }
        registered = systemRefused.isEmpty ? target : nil
        pendingTarget = target
    }

    /// Повторно регистрирует только те сочетания, в которых отказала ОС. Работающие
    /// регистрации не снимаются, поэтому нажатия не теряются во время повтора.
    func retryFailed(_ macros: [Macro], paused: Bool) {
        guard !systemRefused.isEmpty, !suspended, !paused, !self.paused, !registrationBlocked, installed else { return }
        for macro in macros where macro.enabled && systemRefused.contains(macro.id) {
            guard let key = macro.hotkey, key.isValid, !refs.values.contains(where: { $0.id == macro.id }) else { continue }
            var reference: EventHotKeyRef?
            let number = next
            next = next == UInt32.max ? 1 : next + 1
            guard refs[number] == nil else { continue }
            let status = RegisterEventHotKey(key.keyCode, key.modifiers,
                EventHotKeyID(signature: OSType(0x44524E47), id: number), GetApplicationEventTarget(), 0, &reference)
            if status == noErr, let reference = reference {
                refs[number] = (reference, macro.id)
                systemRefused.remove(macro.id)
                failed.remove(macro.id)
            }
        }
        if systemRefused.isEmpty { registered = pendingTarget }
    }

    /// Сочетание реально зарегистрировано первым включённым макросом с этими клавишами;
    /// у остальных показывается конфликт с этим «владельцем».
    static func conflictOwner(for index: Int, in macros: [Macro]) -> Macro? {
        let macro = macros[index]
        guard macro.enabled, let key = macro.hotkey else { return nil }
        return macros[..<index].first { $0.enabled && key.same($0.hotkey) }
    }
}
