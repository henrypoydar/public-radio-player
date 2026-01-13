import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Hide dock icon (menu bar only app)
app.setActivationPolicy(.accessory)

app.run()
