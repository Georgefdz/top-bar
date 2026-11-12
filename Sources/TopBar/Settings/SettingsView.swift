import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: SettingsStore
    let manager: MenuBarManager

    @State private var isTrusted = Permissions.isTrusted
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?
    private let trustTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            if !isTrusted {
                Section {
                    Label("TopBar needs Accessibility access to find and move menu bar items.",
                          systemImage: "exclamationmark.triangle")
                    Button("Open Accessibility Settings") {
                        Permissions.request()
                        Permissions.openSettings()
                    }
                }
            }

            if let error = manager.nativeError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                }
            }

            Section("Menu bar items") {
                let rows = AppRow.rows(items: manager.items, saved: Array(settings.sections.keys))
                if rows.isEmpty {
                    Text("No menu bar items found yet.").foregroundStyle(.secondary)
                }
                ForEach(rows) { row in
                    HStack {
                        Image(nsImage: row.icon).resizable().frame(width: 20, height: 20)
                        Text(row.name)
                        Spacer()
                        Picker(row.name, selection: section(for: row.id)) {
                            ForEach(MenuBarSection.allCases) { Text($0.title).tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                Button("Refresh") { Task { await manager.reconcile() } }
                    .disabled(manager.isBusy || !isTrusted)
            }

            Section("Show hidden items") {
                Toggle("When hovering over an empty area of the menu bar", isOn: $settings.showOnHover)
                Toggle("When clicking an empty area of the menu bar", isOn: $settings.showOnClick)
                Toggle("When scrolling or swiping in the menu bar", isOn: $settings.showOnScroll)
                Toggle("Automatically rehide", isOn: $settings.autoRehide)
                if settings.autoRehide {
                    Stepper("Rehide after \(Int(settings.rehideDelay)) s", value: $settings.rehideDelay, in: 1...30)
                }
                Text("Click the TopBar icon to show hidden items. Option-click also shows always-hidden items.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("General") {
                Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                if let launchError {
                    Text(launchError).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 560)
        .onReceive(trustTimer) { _ in
            let trusted = Permissions.isTrusted
            if trusted && !isTrusted { Task { await manager.reconcile() } }
            isTrusted = trusted
        }
    }

    private func section(for bundleID: String) -> Binding<MenuBarSection> {
        Binding(
            get: { settings.sections[bundleID] ?? .visible },
            set: {
                settings.sections[bundleID] = $0
                Task { await manager.reconcile() }
            }
        )
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.set(enabled)
            launchError = nil
        } catch {
            launchError = error.localizedDescription
        }
        launchAtLogin = LaunchAtLogin.isEnabled
    }
}

/// One row per app: running apps with status items, plus saved apps not running now.
private struct AppRow: Identifiable {
    let id: String
    let name: String
    let icon: NSImage

    static func rows(items: [MenuBarItem], saved: [String]) -> [AppRow] {
        var rows: [String: AppRow] = [:]
        for item in items where rows[item.bundleID] == nil {
            let icon = NSRunningApplication(processIdentifier: item.pid)?.icon
            rows[item.bundleID] = AppRow(id: item.bundleID, name: item.appName, icon: icon ?? placeholder)
        }
        for bundleID in saved where rows[bundleID] == nil {
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            rows[bundleID] = AppRow(
                id: bundleID,
                name: url.map { FileManager.default.displayName(atPath: $0.path) } ?? bundleID,
                icon: url.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? placeholder)
        }
        return rows.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static var placeholder: NSImage {
        NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
    }
}
