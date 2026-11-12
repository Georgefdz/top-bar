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
        listenForCommands()

        if !Permissions.isTrusted {
            Permissions.request()
            showSettings()
        }
    }

    /// Lets scripts (Scripts/e2e.sh) drive the bar: post `dev.topbar.command` with collapse|expand|showAll.
    private func listenForCommands() {
        DistributedNotificationCenter.default().addObserver(
            forName: .init("dev.topbar.command"), object: nil, queue: .main
        ) { [weak self] note in
            let command = note.object as? String
            MainActor.assumeIsolated {
                switch command {
                case "collapse": self?.manager.collapse()
                case "expand": self?.manager.reveal(.expanded)
                case "showAll": self?.manager.reveal(.showAll)
                default: Log.reconcile.error("unknown command \(command ?? "nil", privacy: .public)")
                }
            }
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
