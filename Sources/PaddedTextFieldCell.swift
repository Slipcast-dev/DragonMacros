import AppKit

/// Нативное текстовое поле с отступами и вертикальным центрированием текста.
/// Те же границы используются при рисовании, выборе текста и редактировании.
final class PaddedTextFieldCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let inset = rect.insetBy(dx: 12, dy: 0)
        let height = min(inset.height, cellSize(forBounds: inset).height)
        return NSRect(x: inset.minX, y: inset.midY - height / 2, width: inset.width, height: height)
    }

    /// Рисуем текст в тех же координатах, которые используются полевым редактором.
    /// Это исключает двойной inset при повторном вызове NSTextFieldCell.drawInterior.
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        // drawInterior заменяет нативное рисование ячейки вместе с её фоном.
        let outline = NSBezierPath(roundedRect: cellFrame.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5)
        NSColor.dragonField.setFill()
        outline.fill()
        NSColor.dragonBorder.setStroke()
        outline.lineWidth = 1
        outline.stroke()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let value = stringValue.isEmpty ? (placeholderString ?? "") : stringValue
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 14),
            .foregroundColor: stringValue.isEmpty ? NSColor.placeholderTextColor : (textColor ?? .labelColor),
            .paragraphStyle: paragraph]
        NSAttributedString(string: value, attributes: attributes).draw(in: drawingRect(forBounds: cellFrame))
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor: NSText,
                       delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: drawingRect(forBounds: rect), in: controlView, editor: editor, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor: NSText,
                         delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: drawingRect(forBounds: rect), in: controlView, editor: editor,
                     delegate: delegate, start: selStart, length: selLength)
    }
}
