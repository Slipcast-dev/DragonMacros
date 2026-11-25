import AppKit
import QuartzCore

/// Нативный перенос art390×610 из утверждённого HTML. Все рисунки и траектории
/// заданы в локальных координатах композиции, а не растянуты на ширину редактора.
final class SamuraiBackdrop: NSView {
    private let artwork = CALayer()
    private let sun = CAGradientLayer()
    private let texture = CAShapeLayer()
    private let orbit = CAShapeLayer()
    private let orbitDot = CAShapeLayer()
    private var strokes: [CAShapeLayer] = []
    private var specks: [CALayer] = []
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
    private var windowObservations: [NSKeyValueObservation] = []
    private var motionEnabled = true
    private(set) var motionIsRunning = false
    var artworkFrame: CGRect { artwork.frame }
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        setAccessibilityElement(false)
        artwork.name = "samurai.artwork"
        layer?.addSublayer(artwork)
        makeArtwork()
        let center = NotificationCenter.default
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification,
                     NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification,
                     NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                     NSWindow.willCloseNotification, NSWindow.didChangeOcclusionStateNotification, .dragonMotionChanged] {
            tokens.append((center, center.addObserver(forName: name, object: nil, queue: .main) { [weak self] event in
                guard let self = self else { return }
                if event.name == NSWindow.willCloseNotification, let closing = event.object as? NSWindow,
                   closing === self.window {
                    self.reconcileMotion(isActive: false)
                } else {
                    self.updateMotion()
                }
            }))
        }
        let workspace = NSWorkspace.shared.notificationCenter
        tokens.append((workspace, workspace.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil, queue: .main) { [weak self] _ in self?.updateMotion() }))
    }

    required init?(coder: NSCoder) { fatalError("Programmatic view") }
    deinit { tokens.forEach { $0.0.removeObserver($0.1) } }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowObservations.removeAll()
        if let window = window {
            windowObservations.append(window.observe(\.isVisible, options: [.new]) { [weak self] _, _ in self?.updateMotion() })
            windowObservations.append(window.observe(\.isMiniaturized, options: [.new]) { [weak self] _, _ in self?.updateMotion() })
        }
        needsLayout = true
        updateMotion()
    }

    override func viewDidHide() { super.viewDidHide(); updateMotion() }
    override func viewDidUnhide() { super.viewDidUnhide(); updateMotion() }
    func setMotionEnabled(_ enabled: Bool) { motionEnabled = enabled; updateMotion() }

    private func makeArtwork() {
        sun.name = "samurai.sun"
        sun.frame = CGRect(x: 90, y: 60, width: 260, height: 260)
        sun.type = .radial
        sun.colors = [hexColor(0xC54F3D).cgColor, hexColor(0x852820).cgColor, hexColor(0x61231E).cgColor]
        sun.locations = [0, 0.65, 1]
        sun.startPoint = CGPoint(x: 0.36, y: 0.32)
        sun.endPoint = CGPoint(x: 1, y: 1)
        sun.cornerRadius = 130
        sun.masksToBounds = true
        artwork.addSublayer(sun)
        // Тонкая текстура остаётся внутри диска: это не тёмные полосы через рисунок.
        let grain = CGMutablePath()
        for y in stride(from: 5, through: 260, by: 6) {
            grain.move(to: CGPoint(x: 0, y: CGFloat(y)))
            grain.addLine(to: CGPoint(x: 260, y: CGFloat(y) - 18))
        }
        texture.path = grain
        texture.strokeColor = hexColor(0x0D1215).withAlphaComponent(0.08).cgColor
        texture.lineWidth = 0.5
        texture.frame = sun.bounds
        sun.addSublayer(texture)

        orbit.name = "samurai.orbit"
        orbit.frame = CGRect(x: 58, y: 28, width: 324, height: 324)
        orbit.path = CGPath(ellipseIn: CGRect(x: 0.5, y: 0.5, width: 323, height: 323), transform: nil)
        orbit.fillColor = nil
        orbit.strokeColor = hexColor(0xA88451).withAlphaComponent(0.2).cgColor
        orbit.lineWidth = 1
        orbit.transform = CATransform3DMakeRotation(-25 * .pi / 180, 0, 0, 1)
        artwork.addSublayer(orbit)
        orbitDot.path = CGPath(ellipseIn: CGRect(x: 12, y: 91, width: 4, height: 4), transform: nil)
        orbitDot.fillColor = hexColor(0xB38C59).cgColor
        orbit.addSublayer(orbitDot)

        let points: [[CGPoint]] = [
            [CGPoint(x: 12, y: 185), CGPoint(x: 92, y: 161), CGPoint(x: 177, y: 75), CGPoint(x: 368, y: 42)],
            [CGPoint(x: 25, y: 219), CGPoint(x: 120, y: 170), CGPoint(x: 263, y: 87), CGPoint(x: 382, y: 87)],
            [CGPoint(x: 37, y: 224), CGPoint(x: 138, y: 194), CGPoint(x: 206, y: 150), CGPoint(x: 347, y: 120)]
        ]
        for index in 0..<3 {
            let stroke = CAShapeLayer()
            stroke.name = "samurai.ink.\(index)"
            stroke.frame = CGRect(x: 9, y: 256, width: 390, height: 240)
            let path = CGMutablePath()
            path.move(to: points[index][0])
            path.addCurve(to: points[index][3], control1: points[index][1], control2: points[index][2])
            stroke.path = path
            stroke.fillColor = nil
            stroke.strokeColor = hexColor([0x111314, 0x1E2220, 0x867354][index]).cgColor
            stroke.lineWidth = [25, 11, 2][index]
            stroke.lineCap = .round
            stroke.opacity = index == 2 ? 0.4 : 1
            artwork.addSublayer(stroke)
            strokes.append(stroke)
        }
        // Вертикальная надпись и подпись не участвуют в accessibility-дереве.
        for (index, glyph) in ["一", "瞬"].enumerated() {
            let label = CATextLayer()
            label.string = glyph
            label.font = NSFont(name: "HiraginoMinchoProN-W3", size: 50) ?? NSFont.systemFont(ofSize: 50)
            label.fontSize = 50
            label.foregroundColor = hexColor(0xA08B69).withAlphaComponent(0.3).cgColor
            label.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
            label.frame = CGRect(x: 162, y: 470 + index * 57, width: 60, height: 62)
            artwork.addSublayer(label)
        }
        let caption = CATextLayer()
        caption.string = L("ОДНО ДВИЖЕНИЕ", "ONE MOTION")
        caption.fontSize = 8
        caption.foregroundColor = hexColor(0x777365).cgColor
        caption.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        caption.frame = CGRect(x: 142, y: 588, width: 180, height: 18)
        artwork.addSublayer(caption)
        for x: CGFloat in [130, 290, 210] {
            let speck = CALayer()
            speck.frame = CGRect(x: x, y: 600, width: 2, height: 9)
            speck.backgroundColor = hexColor(0xC77A55).withAlphaComponent(0.36).cgColor
            speck.opacity = 0
            artwork.addSublayer(speck)
            specks.append(speck)
        }
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let compact = bounds.width <= 747
        let right: CGFloat = compact ? -155 : -80
        artwork.frame = CGRect(x: bounds.width - 390 - right, y: 15, width: 390, height: 610)
        artwork.opacity = compact ? 0.22 : 0.85
        CATransaction.commit()
        updateMotion()
    }

    private func updateMotion() {
        // Окно, полностью закрытое другими окнами, не тратит GPU на фоновое движение.
        reconcileMotion(isActive: NSApp.isActive && window?.isVisible == true && window?.isMiniaturized == false
            && window?.occlusionState.contains(.visible) == true)
    }

    /// Детерминированная граница жизненного цикла: тест может передать активность,
    /// не переключая реальные окна/приложения. Предпочтения доступности действуют всегда.
    func reconcileMotion(isActive: Bool) {
        let active = isActive && motionEnabled && Motion.enabled && Settings.shared.theme == .samurai
            && !isHiddenOrHasHiddenAncestor
        guard active else {
            removeAnimations(in: artwork)
            motionIsRunning = false
            return
        }
        guard !motionIsRunning else { return }
        motionIsRunning = true
        let breathe = CABasicAnimation(keyPath: "transform.translation.y")
        breathe.fromValue = 0; breathe.toValue = -7; breathe.duration = 4.5
        breathe.autoreverses = true; breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        sun.add(breathe, forKey: "breathe")
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = -25 * Double.pi / 180
        rotation.toValue = 335 * Double.pi / 180
        rotation.duration = 40; rotation.repeatCount = .infinity
        orbit.add(rotation, forKey: "orbit")
        for (index, stroke) in strokes.enumerated() {
            let reveal = CABasicAnimation(keyPath: "strokeEnd")
            reveal.fromValue = 0; reveal.toValue = 1; reveal.duration = 2.2
            reveal.beginTime = stroke.convertTime(CACurrentMediaTime(), from: nil) + 0.8 + Double(index) * 0.3
            reveal.fillMode = .backwards
            reveal.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.75, 0.25, 1)
            stroke.add(reveal, forKey: "brush")
        }
        for (index, speck) in specks.enumerated() {
            let duration = [11.0, 14.0, 17.0][index]
            let drift = CAKeyframeAnimation(keyPath: "transform")
            drift.values = [NSValue(caTransform3D: CATransform3DMakeRotation(-25 * .pi / 180, 0, 0, 1)),
                            NSValue(caTransform3D: CATransform3DRotate(CATransform3DMakeTranslation(-65, -550, 0), 100 * .pi / 180, 0, 0, 1))]
            drift.duration = duration
            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [0, 0.6, 0.6, 0]; opacity.keyTimes = [0, 0.15, 0.75, 1]
            opacity.duration = duration
            let group = CAAnimationGroup()
            group.animations = [drift, opacity]; group.duration = duration; group.repeatCount = .infinity
            group.timeOffset = [2.0, 7.0, 4.0][index]
            speck.add(group, forKey: "drift")
        }
    }

    private func removeAnimations(in layer: CALayer) {
        layer.removeAllAnimations()
        layer.sublayers?.forEach { removeAnimations(in: $0) }
    }
}
