import AppKit
import SwiftUI

/// Owns the app's services and wires them together.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private var controls: ControlItems!
    private var manager: MenuBarManager!
    private var triggers: RevealTriggers!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controls = ControlItems()
        manager = MenuBarManager(controls: controls, settings: settings)
        triggers = RevealTriggers(settings: settings, manager: manager)
        controls.onOpenSettings = { [weak self] in self?.showSettings() }

        triggers.start()
        manager.start()

        if !Permissions.isTrusted {
            Permissions.request()
            showSettings()
        }
    }

    private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(
                rootView: SettingsView(settings: settings, manager: manager)))
            window.title = "TopBar Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
