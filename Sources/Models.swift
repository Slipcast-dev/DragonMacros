import AppKit
import Carbon
import UniformTypeIdentifiers

// MARK: - Модель

enum ActionKind: String, Codable { case app, url }

struct Hotkey: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32      // маски Carbon: cmdKey, shiftKey, optionKey, controlKey
    var label: String
    var display: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + label
    }
    /// Только физические коды клавиш и четыре поддерживаемых модификатора Carbon.
    var isValid: Bool {
        let mask = UInt32(cmdKey | shiftKey | optionKey | controlKey)
        return keyCode <= 127 && modifiers & ~mask == 0
            && (modifiers != 0 || functionKeyCodes.contains(UInt16(keyCode)))
    }
    func same(_ other: Hotkey?) -> Bool {
        guard let other = other else { return false }
        return other.keyCode == keyCode && other.modifiers == modifiers
    }
}

struct Macro: Codable {
    var id = UUID()
    var name = ""          // пустое имя показывается как «Новый макрос» на текущем языке
    var hotkey: Hotkey?
    var kind: ActionKind = .app
    var appPath = ""
    var url = ""
    var enabled = true
    var title: String { name.isEmpty ? L("Новый макрос", "New macro") : name }
}
