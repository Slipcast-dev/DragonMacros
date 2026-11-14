import AppKit

// Точка входа: интерфейс и обработчики работают в главном потоке AppKit.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
