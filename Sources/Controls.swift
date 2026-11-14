import AppKit
import QuartzCore
import Carbon
import UniformTypeIdentifiers

// MARK: - Интерфейс: вспомогательные элементы

final class FlippedView: NSView { override var isFlipped: Bool { true } }

final class HeaderView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        if Theme.usesCrimsonHeader {
            NSGradient(starting: .dragonDark, ending: .dragonRed)?.draw(in: bounds, angle: 0)
        } else {
            NSColor.dragonSide.setFill(); bounds.fill()
        }
    }
}

/// Кнопка в шапке в стиле macOS: полупрозрачная «таблетка» с символом SF Symbols, подсветка при наведении и нажатии.
final class HeaderButton: NSButton {
    private let symbol: String
    private let label: String
    private var hover = false

    init(symbol: String, label: String, target: AnyObject, action: Selector) {
        self.symbol = symbol; self.label = label
        super.init(frame: .zero)
        self.target = target; self.action = action
        isBordered = false; title = ""; setButtonType(.momentaryChange)
        setAccessibilityLabel(label.isEmpty ? L("Настройки", "Settings") : label); toolTip = label
    }
    required init?(coder: NSCoder) { fatalError() }

    var idealWidth: CGFloat {
        label.isEmpty ? 44 : ceil(NSAttributedString(string: label, attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium)]).size().width) + 50
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect], owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { hover = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hover = false; needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        let alpha: CGFloat = isHighlighted ? 0.12 : (hover ? 0.07 : 0)
        let r = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: r, xRadius: 7, yRadius: 7)
        NSColor(white: 1, alpha: alpha).setFill(); path.fill()
        NSColor.clear.setStroke(); path.lineWidth = 1; path.stroke()

        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: Theme.headerText]
        let text = NSAttributedString(string: label, attributes: attrs)
        let ts = text.size()
        var iconW: CGFloat = 0, icon: NSImage?
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            let h: CGFloat = 14, w = img.size.height > 0 ? img.size.width / img.size.height * h : h
            let tinted = NSImage(size: NSSize(width: w, height: h), flipped: false) { rect in
                img.draw(in: rect); Theme.headerText.set(); rect.fill(using: .sourceAtop); return true
            }
            icon = tinted; iconW = w
        }
        let gap: CGFloat = icon == nil || label.isEmpty ? 0 : 6
        var x = (bounds.width - iconW - gap - ts.width) / 2
        if let icon = icon {
            icon.draw(in: NSRect(x: x, y: (bounds.height - icon.size.height) / 2, width: iconW, height: icon.size.height))
            x += iconW + gap
        }
        text.draw(at: NSPoint(x: x, y: (bounds.height - ts.height) / 2))
    }
}

final class DragonRow: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        NSColor.dragonTint.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 8, dy: 2), xRadius: 6, yRadius: 6).fill()
        NSColor.dragonRed.setFill()
        NSRect(x: 8, y: 18, width: 2, height: max(0, bounds.height - 36)).fill()
    }
}

/// Поле записи комбинации: клик → нажать клавиши. Esc — отмена, Delete — очистить.
final class HotkeyField: NSView {
    var hotkey: Hotkey? { didSet { needsDisplay = true; setAccessibilityValue(hotkey?.display ?? L("Не задано", "Not set")) } }
    var onChange: ((Hotkey?) -> Void)?
    var onRecording: ((Bool) -> Void)?
    private(set) var recording = false {
        didSet { needsDisplay = true; if oldValue != recording { onRecording?(recording) } }
    }
    private var hint = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true); setAccessibilityRole(.button)
        setAccessibilityLabel(L("Записать сочетание клавиш", "Record hotkey"))
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }
    override func accessibilityPerformPress() -> Bool {
        hint = ""; window?.makeFirstResponder(self); recording = true; return true
    }
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) { hint = ""; window?.makeFirstResponder(self); recording = true }
    override func resignFirstResponder() -> Bool { recording = false; return true }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if recording { keyDown(with: event); return true }
        return false
    }

    private func stop() { recording = false; window?.makeFirstResponder(nil) }

    override func keyDown(with e: NSEvent) {
        guard recording else {
            if e.keyCode == 49 || e.keyCode == 36 { _ = accessibilityPerformPress() }
            else { super.keyDown(with: e) }
            return
        }
        let mods = carbonModifiers(e.modifierFlags)
        if e.keyCode == 53 { stop(); return }
        if mods == 0 && (e.keyCode == 51 || e.keyCode == 117) { hotkey = nil; onChange?(nil); stop(); return }
        if mods == 0 && !functionKeyCodes.contains(e.keyCode) {
            hint = L("Добавьте ⌃, ⌥, ⇧ или ⌘", "Add ⌃, ⌥, ⇧ or ⌘"); needsDisplay = true; NSSound.beep(); return
        }
        let label = specialKeyLabels[e.keyCode] ?? (e.charactersIgnoringModifiers?.uppercased() ?? "?")
        let hk = Hotkey(keyCode: UInt32(e.keyCode), modifiers: mods, label: label)
        hotkey = hk; onChange?(hk); stop()
    }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: r, xRadius: 5, yRadius: 5)
        (recording ? NSColor.dragonTint : NSColor.dragonField).setFill(); path.fill()
        (recording ? NSColor.dragonRed : NSColor.dragonBorder).setStroke()
        path.lineWidth = recording ? 2 : 1; path.stroke()
        // Модификаторы отделены тонкими линиями, а название клавиши остаётся целым.
        if !recording, let key = hotkey {
            let labels = String(key.display.dropLast(key.label.count)).map(String.init) + [key.label]
            var x: CGFloat = 18
            for (index, label) in labels.enumerated() {
                let value = NSAttributedString(string: label, attributes: [
                    .font: NSFont.systemFont(ofSize: 19, weight: .medium), .foregroundColor: NSColor.dragonText])
                let size = value.size()
                value.draw(at: NSPoint(x: x, y: (bounds.height - size.height) / 2))
                x += size.width + 15
                if index < labels.count - 1 {
                    NSColor.dragonBorder.setFill()
                    NSRect(x: x, y: (bounds.height - 23) / 2, width: 1, height: 23).fill()
                    x += 16
                }
            }
            return
        }
        let text: String, color: NSColor, font: NSFont
        if recording {
            text = hint.isEmpty ? L("Нажмите комбинацию…", "Press a key combination…") : hint
            color = .dragonAccentText; font = .systemFont(ofSize: 14)
        } else if let hk = hotkey { text = (String(hk.display.dropLast(hk.label.count)).map(String.init) + [hk.label]).joined(separator: "  "); color = .dragonText; font = .systemFont(ofSize: 17, weight: .semibold) }
        else { text = L("Нажмите, чтобы задать", "Click to set"); color = .dragonGray; font = .systemFont(ofSize: 14) }
        let s = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        let sz = s.size()
        s.draw(at: NSPoint(x: (bounds.width - sz.width) / 2, y: (bounds.height - sz.height) / 2))
    }
}

func styleButton(_ b: NSButton, title: String, filled: Bool, size: CGFloat = 13) {
    b.isBordered = false; b.wantsLayer = true
    b.layer?.cornerRadius = 5; b.layer?.borderWidth = filled ? 0 : 1; b.layer?.borderColor = NSColor.dragonBorder.cgColor
    b.layer?.backgroundColor = (filled ? NSColor.dragonRed : NSColor.clear).cgColor
    let p = NSMutableParagraphStyle(); p.alignment = .center
    b.attributedTitle = NSAttributedString(string: title, attributes: [
        .foregroundColor: filled ? NSColor.white : NSColor.dragonGray,
        .font: NSFont.systemFont(ofSize: size, weight: .semibold), .paragraphStyle: p])
}

func redButton(_ title: String, target: AnyObject, action: Selector) -> NSButton {
    let b = MotionButton(title: title, target: target, action: action)
    styleButton(b, title: title, filled: true)
    return b
}

func caption(_ s: String) -> NSTextField {
    let l = NSTextField(labelWithString: s.uppercased())
    l.font = .systemFont(ofSize: 10.5, weight: .medium); l.textColor = .dragonGray
    return l
}

// MARK: - Главное окно

/// Небольшая подсветка при наведении, без таймеров и изменения геометрии кнопки.
final class MotionButton: NSButton {
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect], owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { setHovered(true) }
    override func mouseExited(with event: NSEvent) { setHovered(false) }
    /// NSView подавляет неявные действия своего backing layer; поэтому переход
    /// задаётся явным CABasicAnimation и действительно проигрывается в AppKit.
    func setHovered(_ active: Bool) {
        wantsLayer = true
        guard let layer = layer else { return }
        let previous = layer.presentation()?.opacity ?? layer.opacity
        let target: Float = active ? 0.85 : 1
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.opacity = target
        CATransaction.commit()
        layer.removeAnimation(forKey: "hover")
        if Motion.enabled {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = previous
            fade.toValue = target
            fade.duration = 0.18
            fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(fade, forKey: "hover")
        }
    }
    override func mouseDown(with event: NSEvent) {
        if Motion.enabled {
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 0.65; animation.toValue = layer?.opacity ?? 1; animation.duration = 0.22
            layer?.add(animation, forKey: "press")
        }
        super.mouseDown(with: event)
    }
}

/// Переключатель сохраняет нативную семантику NSButton checkbox, рисуя компактную
/// дорожку и бегунок вместо системной галочки. Target/action и state остаются AppKit.
final class SamuraiToggle: NSButton {
    override var focusRingMaskBounds: NSRect {
        NSRect(x: 1, y: (bounds.height - 18) / 2, width: 32, height: 18)
    }
    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: focusRingMaskBounds, xRadius: 9, yRadius: 9).fill()
    }
    override func draw(_ dirtyRect: NSRect) {
        let track = NSRect(x: 1, y: (bounds.height - 18) / 2, width: 32, height: 18)
        (state == .on ? NSColor.dragonOK : NSColor.dragonBorder).withAlphaComponent(isEnabled ? 1 : 0.45).setFill()
        NSBezierPath(roundedRect: track, xRadius: 9, yRadius: 9).fill()
        hexColor(0xF3F0E6).setFill()
        let knob = NSRect(x: state == .on ? 18 : 4, y: track.minY + 3, width: 12, height: 12)
        NSBezierPath(ovalIn: knob).fill()
        let text = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 12), .foregroundColor: isEnabled ? NSColor.dragonText : NSColor.dragonGray])
        text.draw(at: NSPoint(x: 45, y: (bounds.height - text.size().height) / 2))
    }
}
