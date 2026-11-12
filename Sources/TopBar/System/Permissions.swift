import AppKit
import ApplicationServices

enum Permissions {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt (once per app identity) to grant Accessibility.
    static func request() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
