import AppKit
import Observation

/// Coordinates reveal/collapse, auto-rehide, and applying saved sections.
/// macOS 27+: the system hides non-allow-listed apps (`NativeVisibility`).
/// Older macOS: icons are Cmd-dragged behind separator items (legacy path).
@MainActor
@Observable
final class MenuBarManager {
    private(set) var items: [MenuBarItem] = []
    private(set) var isBusy = false

    @ObservationIgnored private let controls: ControlItems
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let native = NativeVisibility.isAvailable ? NativeVisibility() : nil
    @ObservationIgnored private var rehideTask: Task<Void, Never>?
    @ObservationIgnored private var launchObserver: NSObjectProtocol?

    var state: ControlItems.State { controls.state }

    init(controls: ControlItems, settings: SettingsStore) {
        self.controls = controls
        self.settings = settings
        controls.usesSeparators = native == nil
        controls.onClick = { [weak self] withOption in self?.iconClicked(withOption: withOption) }
        Log.reconcile.notice("native visibility: \(self.native != nil)")
    }

    func start() {
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.native != nil {
                    self.setState(self.state) // refresh the allow-list so the new app is shown unless hidden
                } else if let bundleID, self.settings.sections[bundleID] != nil {
                    Task {
                        try? await Task.sleep(for: .seconds(2)) // give the app time to add its status item
                        await self.reconcile()
                    }
                }
            }
        }
        setState(.collapsed)
        Task { await reconcile() }
    }

    func reveal(_ newState: ControlItems.State) {
        setState(newState)
        scheduleRehide()
    }

    func collapse() {
        rehideTask?.cancel()
        setState(.collapsed)
    }

    /// Scans items for the settings list and applies saved sections.
    func reconcile() async {
        if native != nil {
            if Permissions.isTrusted { items = MenuBarItemScanner.scan() }
            setState(state)
            return
        }
        await reconcileByDragging()
    }

    /// True when x is in the menu bar but not on app menus or any status item.
    func isEmptyMenuBarArea(atX x: CGFloat) -> Bool {
        guard Permissions.isTrusted else { return false }
        let occupied = MenuBarItemScanner.scan().map { $0.frame.minX...$0.frame.maxX } + controls.occupiedRanges
        return MenuBarGeometry.isEmptyArea(x: x, appMenusMaxX: MenuBarItemScanner.appMenusMaxX() ?? 0,
                                           occupied: occupied)
    }

    private func setState(_ newState: ControlItems.State) {
        controls.apply(newState)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [controls] in
            Log.reconcile.notice("state \(String(describing: newState), privacy: .public) icon \(NSStringFromRect(controls.iconFrame ?? .zero), privacy: .public)")
        }
        guard let native else { return }
        let running = NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        native.apply(allowedBundles: MenuBarSection.allowedBundles(
            running: running, sections: settings.sections, blocking: Self.blocked(in: newState)))
        if newState != .showAll { Task { await arrangeAroundChevron(for: newState) } }
    }

    private static func blocked(in state: ControlItems.State) -> Set<MenuBarSection> {
        switch state {
        case .collapsed: [.hidden, .alwaysHidden]
        case .expanded: [.alwaysHidden]
        case .showAll: []
        }
    }

    /// macOS 27 re-shows icons wherever it likes. Collapsed: drag the chevron left of every shown icon.
    /// Expanded: drag revealed Hidden icons to the chevron's left, one per pass.
    private func arrangeAroundChevron(for target: ControlItems.State) async {
        guard Permissions.isTrusted, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        await settle() // let macOS finish reflowing after the restriction changes
        let blocked = Self.blocked(in: target)
        for _ in 0..<10 {
            guard state == target, let icon = controls.iconFrame else { return }
            // Hidden icons may still report stale positions, so keep only allowed, on-screen ones.
            let shown = MenuBarItemScanner.scan().filter {
                $0.frame.minY >= 0 && !blocked.contains(settings.sections[$0.bundleID] ?? .visible)
            }
            let move = target == .collapsed
                ? MovePlanner.chevronLeftmostMove(icon: icon, shownItems: shown)
                : MovePlanner.revealedItemMove(icon: icon, shownItems: shown, sections: settings.sections)
            guard let move else { return }
            Log.reconcile.notice("arrange \(move.item.bundleID, privacy: .public) to x \(move.destinationX)")
            await MenuBarItemMover.perform(move)
            await settle()
        }
    }

    /// Legacy: briefly shows everything, then moves items in the wrong section.
    private func reconcileByDragging() async {
        guard Permissions.isTrusted, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        let previous = controls.state
        rehideTask?.cancel()
        setState(.showAll)
        await settle()

        // Re-plan after every move, since each move shifts the others. Each app gets a few tries.
        var attempts: [String: Int] = [:]
        while true {
            items = MenuBarItemScanner.scan()
            guard let separators = controls.separatorFrames,
                  let move = MovePlanner.moves(items: items, separators: separators, desired: settings.sections)
                      .first(where: { attempts[$0.item.bundleID, default: 0] < 3 })
            else { break }
            attempts[move.item.bundleID, default: 0] += 1
            Log.reconcile.notice("move \(move.item.bundleID, privacy: .public) to x \(move.destinationX)")
            await MenuBarItemMover.perform(move)
            await settle()
        }

        setState(previous)
        if previous != .collapsed { scheduleRehide() }
    }

    private func iconClicked(withOption: Bool) {
        if withOption {
            state == .showAll ? collapse() : reveal(.showAll)
        } else {
            state == .collapsed ? reveal(.expanded) : collapse()
        }
    }

    // shortcut: rehides even if a hidden item's menu is open; detect open menus if that bites.
    private func scheduleRehide() {
        rehideTask?.cancel()
        guard settings.autoRehide else { return }
        rehideTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self.settings.rehideDelay))
                guard !Task.isCancelled else { return }
                if !MenuBarGeometry.mouseIsInMenuBar() {
                    self.setState(.collapsed)
                    return
                }
            }
        }
    }

    private func settle() async {
        try? await Task.sleep(for: .milliseconds(250))
    }
}
