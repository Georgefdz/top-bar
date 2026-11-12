import AppKit

/// Listens for hover, empty-area clicks and scrolls in the menu bar.
@MainActor
final class RevealTriggers {
    private let settings: SettingsStore
    private let manager: MenuBarManager
    private var monitors: [Any] = []
    private var hoverTask: Task<Void, Never>?

    init(settings: SettingsStore, manager: MenuBarManager) {
        self.settings = settings
        self.manager = manager
    }

    func start() {
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
                MainActor.assumeIsolated { self?.mouseMoved() }
            },
            NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
                MainActor.assumeIsolated { self?.mouseDown() }
            },
            NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                let delta = abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX)
                    ? event.scrollingDeltaY : event.scrollingDeltaX
                MainActor.assumeIsolated { self?.scrolled(delta: delta) }
            },
        ].compactMap { $0 }
    }

    private func mouseMoved() {
        guard settings.showOnHover, !manager.isBusy, manager.state == .collapsed,
              MenuBarGeometry.mouseIsInMenuBar()
        else {
            hoverTask?.cancel()
            hoverTask = nil
            return
        }
        guard hoverTask == nil else { return }
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300)) // ignore cursor just passing through
            guard let self, !Task.isCancelled else { return }
            self.hoverTask = nil
            if MenuBarGeometry.mouseIsInMenuBar(),
               self.manager.isEmptyMenuBarArea(atX: NSEvent.mouseLocation.x) {
                self.manager.reveal(.expanded)
            }
        }
    }

    private func mouseDown() {
        guard settings.showOnClick, !manager.isBusy, MenuBarGeometry.mouseIsInMenuBar(),
              manager.isEmptyMenuBarArea(atX: NSEvent.mouseLocation.x)
        else { return }
        manager.state == .collapsed ? manager.reveal(.expanded) : manager.collapse()
    }

    private func scrolled(delta: CGFloat) {
        guard settings.showOnScroll, !manager.isBusy, abs(delta) > 1,
              MenuBarGeometry.mouseIsInMenuBar()
        else { return }
        if delta > 0, manager.state == .collapsed {
            manager.reveal(.expanded)
        } else if delta < 0, manager.state != .collapsed {
            manager.collapse()
        }
    }
}
