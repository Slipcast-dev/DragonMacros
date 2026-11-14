import AppKit
import QuartzCore
import Carbon
import UniformTypeIdentifiers

// MARK: - Цвета (зависят от выбранного стиля)

enum Theme {
    static var isSamurai: Bool { Settings.shared.theme == .samurai }
    static var usesCrimsonHeader: Bool { [.original, .dark].contains(Settings.shared.theme) }
    static var headerText: NSColor { usesCrimsonHeader ? .white : .dragonText }
    static var titleFont: NSFont {
        isSamurai ? (NSFont(name: "Georgia", size: 24) ?? .systemFont(ofSize: 24)) : .systemFont(ofSize: 24, weight: .semibold)
    }
    static var editorFont: NSFont {
        isSamurai ? (NSFont(name: "Georgia", size: 36) ?? .systemFont(ofSize: 36)) : .systemFont(ofSize: 32, weight: .semibold)
    }
    static var styleDescription: String {
        switch Settings.shared.theme {
        case .samurai: return L("Самурай · движение туши и киноварь", "Samurai · ink motion and vermilion")
        case .original: return L("Белые поверхности и красная шапка", "White surfaces and a crimson header")
        case .dark: return L("Чёрные поверхности и красные акценты", "Black surfaces and red accents")
        case .system: return L("Следует светлой или тёмной теме macOS", "Follows the light or dark macOS appearance")
        }
    }
    /// Тёмная палитра: стиль «чёрно-красный» или стиль «как в системе» при тёмной теме macOS.
    static var isDark: Bool {
        switch Settings.shared.theme {
        case .original: return false
        case .samurai, .dark: return true
        case .system: return UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        }
    }
    /// Внешний вид окон: оригинальный и чёрно-красный стили фиксируют светлый/тёмный, системный — следует за macOS.
    static var appearance: NSAppearance? {
        switch Settings.shared.theme {
        case .original: return NSAppearance(named: .aqua)
        case .samurai, .dark: return NSAppearance(named: .darkAqua)
        case .system: return nil
        }
    }
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: 1) }

/// Палитры четырёх стилей. Samurai следует макету, классические темы сохраняют красную шапку.
func hexColor(_ value: UInt32) -> NSColor { rgb(CGFloat(value >> 16 & 255)/255, CGFloat(value >> 8 & 255)/255, CGFloat(value & 255)/255) }
extension NSColor {
    private static func themed(_ samurai: UInt32, _ original: UInt32, _ dark: UInt32, _ systemLight: UInt32, _ systemDark: UInt32) -> NSColor {
        switch Settings.shared.theme {
        case .samurai: return hexColor(samurai)
        case .original: return hexColor(original)
        case .dark: return hexColor(dark)
        case .system: return hexColor(Theme.isDark ? systemDark : systemLight)
        }
    }
    static var dragonRed: NSColor { themed(0xDF4938, 0xA31C37, 0xD52C45, 0xB32239, 0xDF5365) }
    static var dragonDark: NSColor { themed(0x852820, 0x600F23, 0x31090F, 0x7B2034, 0x591F2C) }
    static var dragonBG: NSColor { themed(0x101112, 0xFFFFFF, 0x0D0B0E, 0xF6F6F7, 0x1E1E20) }
    static var dragonSide: NSColor { themed(0x191A1B, 0xF3E9EC, 0x1E1016, 0xE9EAEC, 0x28282A) }
    static var dragonTint: NSColor { themed(0x382421, 0xEED2DA, 0x4F1424, 0xE6DADF, 0x4B303B) }
    static var dragonText: NSColor { themed(0xF0ECE5, 0x241C20, 0xF8E9ED, 0x222225, 0xEEEEF0) }
    static var dragonGray: NSColor { themed(0x91918E, 0x71636B, 0xB2929D, 0x67686D, 0xA7A7AF) }
    static var dragonField: NSColor { themed(0x1A1C1D, 0xFAF7F8, 0x25131B, 0xFFFFFF, 0x303034) }
    static var dragonBorder: NSColor { themed(0x383A3B, 0xC5ADB6, 0x673243, 0xBFC0C5, 0x505055) }
    static var dragonAccentText: NSColor { themed(0xDF978B, 0x9E1833, 0xF66E88, 0x9A263B, 0xED96AA) }
    static var dragonOK: NSColor { Theme.isDark ? hexColor(0x96AA8E) : hexColor(0x466438) }
}

/// Общий контракт движения учитывает системную настройку доступности.
enum Motion {
    static var enabled: Bool { Settings.shared.animationsEnabled && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    static func reveal(_ view: NSView) {
        guard enabled, let layer = view.layer else { return }
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0; animation.toValue = 1; animation.duration = 0.3
        layer.add(animation, forKey: "reveal")
    }
}
