import AppKit

/// Компактный счётчик: текст центрируется по фактическим метрикам шрифта,
/// а не по базовой линии NSTextField, которая при малой высоте смещала цифры вверх.
final class CenteredBadge: NSView {
    var stringValue = "" {
        didSet { needsDisplay = true; setAccessibilityValue(stringValue) }
    }
    var font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
    var textColor = NSColor.dragonText

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }
    required init?(coder: NSCoder) { fatalError("Programmatic view") }

    var textRect: NSRect {
        let size = NSAttributedString(string: stringValue, attributes: [.font: font]).size()
        return NSRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
        NSColor.dragonBorder.setStroke()
        outline.lineWidth = 1
        outline.stroke()
        NSAttributedString(string: stringValue, attributes: [.font: font, .foregroundColor: textColor]).draw(in: textRect)
    }
}
