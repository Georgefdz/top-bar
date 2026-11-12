import CoreGraphics

/// Horizontal extents of the two separator status items.
struct SeparatorFrames: Equatable {
    let hidden: ClosedRange<CGFloat>
    let alwaysHidden: ClosedRange<CGFloat>
}

struct Move: Equatable {
    let item: MenuBarItem
    let destinationX: CGFloat
}

/// Pure logic: which items sit in the wrong section and where to drop them.
/// Layout: [always-hidden] |AH| [hidden] |H| [visible] [TopBar icon]
enum MovePlanner {
    static let dropOffset: CGFloat = 2

    static func section(ofX x: CGFloat, separators: SeparatorFrames) -> MenuBarSection {
        if x >= separators.hidden.upperBound { return .visible }
        if x >= separators.alwaysHidden.upperBound { return .hidden }
        return .alwaysHidden
    }

    /// Items with no saved section are left where the user put them.
    static func moves(items: [MenuBarItem], separators: SeparatorFrames,
                      desired: [String: MenuBarSection]) -> [Move] {
        items.compactMap { item in
            guard let target = desired[item.bundleID],
                  section(ofX: item.frame.midX, separators: separators) != target
            else { return nil }
            return Move(item: item, destinationX: destinationX(for: target, separators: separators))
        }
    }

    // shortcut: drops just beside a separator and relies on macOS reflow; if drops miss on some layouts, target a neighbor item's edge instead.
    static func destinationX(for target: MenuBarSection, separators: SeparatorFrames) -> CGFloat {
        switch target {
        case .visible: separators.hidden.upperBound + dropOffset
        case .hidden: separators.hidden.lowerBound - dropOffset
        case .alwaysHidden: separators.alwaysHidden.lowerBound - dropOffset
        }
    }
}

extension MovePlanner {
    /// Drag that puts TopBar's chevron left of every shown icon, or nil if it already is.
    /// `icon` and `shownItems` share x; y comes from the items (AX space).
    static func chevronLeftmostMove(icon: CGRect, shownItems: [MenuBarItem]) -> Move? {
        guard let leftmost = shownItems.min(by: { $0.frame.minX < $1.frame.minX }),
              leftmost.frame.minX < icon.minX
        else { return nil }
        let chevron = MenuBarItem(pid: 0, bundleID: "TopBar", appName: "TopBar",
                                  frame: CGRect(x: icon.minX, y: leftmost.frame.minY,
                                                width: icon.width, height: leftmost.frame.height))
        // Just inside the leftmost icon's left edge: dragging past its middle makes macOS swap them.
        return Move(item: chevron, destinationX: leftmost.frame.minX + 1)
    }
}

extension MovePlanner {
    /// While expanded, revealed Hidden icons belong left of the chevron. Returns the drag for the
    /// leftmost one still on its right (moving leftmost-first keeps their order), or nil when done.
    static func revealedItemMove(icon: CGRect, shownItems: [MenuBarItem],
                                 sections: [String: MenuBarSection]) -> Move? {
        guard let item = shownItems
            .filter({ sections[$0.bundleID] == .hidden && $0.frame.minX > icon.minX })
            .min(by: { $0.frame.minX < $1.frame.minX })
        else { return nil }
        return Move(item: item, destinationX: icon.minX + 1)
    }
}
