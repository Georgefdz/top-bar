import AppKit

/// TopBar's own status items: the toggle icon and the two separators.
/// Legacy hiding (before macOS 27): a separator with a huge length pushes every item to its left off-screen.
@MainActor
final class ControlItems: NSObject {
    enum State { case collapsed, expanded, showAll }

    private static let separatorLength: CGFloat = 12
    private static let collapsedLength: CGFloat = 10_000

    var onClick: ((_ withOption: Bool) -> Void)?
    var onOpenSettings: (() -> Void)?
    private(set) var state: State = .collapsed

    /// False when the system hides items for us (macOS 27 native visibility).
    var usesSeparators = true {
        didSet {
            hiddenSeparator.isVisible = usesSeparators
            alwaysHiddenSeparator.isVisible = usesSeparators
            apply(state)
        }
    }

    private let icon: NSStatusItem
    private let hiddenSeparator: NSStatusItem
    private let alwaysHiddenSeparator: NSStatusItem

    override init() {
        // Created right to left: macOS places each new item left of the previous ones.
        icon = Self.makeItem("TopBarIcon", length: NSStatusItem.variableLength)
        hiddenSeparator = Self.makeItem("TopBarHiddenSeparator", length: Self.separatorLength)
        alwaysHiddenSeparator = Self.makeItem("TopBarAlwaysHiddenSeparator", length: Self.separatorLength)
        super.init()
        icon.button?.target = self
        icon.button?.action = #selector(iconClicked)
        icon.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        apply(.collapsed)
    }

    func apply(_ newState: State) {
        state = newState
        if usesSeparators {
            // Collapsed: H alone hides both sections, AH stays short so the bar doesn't overflow.
            setCollapsed(hiddenSeparator, newState == .collapsed, glyph: "│")
            setCollapsed(alwaysHiddenSeparator, newState == .expanded, glyph: "┆")
        }
        let symbol = newState == .collapsed ? "chevron.left" : "chevron.right"
        icon.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "TopBar")
    }

    /// Valid only while both separators are short (`.showAll`).
    var separatorFrames: SeparatorFrames? {
        guard let h = xRange(hiddenSeparator), let ah = xRange(alwaysHiddenSeparator) else { return nil }
        return SeparatorFrames(hidden: h, alwaysHidden: ah)
    }

    /// Screen x ranges our visible items occupy, for empty-area hit tests.
    /// Our icon's window frame in AppKit coordinates (nil if macOS removed it).
    var iconFrame: CGRect? { icon.button?.window?.frame }

    var occupiedRanges: [ClosedRange<CGFloat>] {
        [icon, hiddenSeparator, alwaysHiddenSeparator]
            .filter { $0.length < Self.collapsedLength }
            .compactMap(xRange)
    }

    private static func makeItem(_ name: String, length: CGFloat) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: length)
        item.autosaveName = name
        return item
    }

    private func setCollapsed(_ item: NSStatusItem, _ collapsed: Bool, glyph: String) {
        item.length = collapsed ? Self.collapsedLength : Self.separatorLength
        item.button?.title = collapsed ? "" : glyph
    }

    private func xRange(_ item: NSStatusItem) -> ClosedRange<CGFloat>? {
        guard let frame = item.button?.window?.frame else { return nil }
        return frame.minX...frame.maxX
    }

    @objc private func iconClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            onClick?(event.modifierFlags.contains(.option))
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit TopBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        icon.menu = menu
        icon.button?.performClick(nil)
        icon.menu = nil
    }

    @objc private func openSettings() { onOpenSettings?() }
}
