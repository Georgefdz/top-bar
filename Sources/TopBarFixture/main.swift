import AppKit

// A known status item for Scripts/e2e.sh to hide and look for (via OCR). Bundle id dev.topbar.Fixture.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
item.button?.title = "Q7Z9Q" // no letters with Cyrillic lookalikes, which OCR sometimes returns
app.run()
