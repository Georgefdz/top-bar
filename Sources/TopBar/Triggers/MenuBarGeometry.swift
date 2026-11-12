import AppKit

enum MenuBarGeometry {
    /// `point` and `screenFrame` in AppKit (bottom-left origin) coordinates.
    static func isInMenuBar(_ point: CGPoint, screenFrame: CGRect, menuBarHeight: CGFloat) -> Bool {
        point.x >= screenFrame.minX && point.x <= screenFrame.maxX
            && point.y >= screenFrame.maxY - menuBarHeight && point.y <= screenFrame.maxY
    }

    static func isEmptyArea(x: CGFloat, appMenusMaxX: CGFloat, occupied: [ClosedRange<CGFloat>]) -> Bool {
        x > appMenusMaxX && !occupied.contains { $0.contains(x) }
    }

    @MainActor
    static func mouseIsInMenuBar() -> Bool {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.contains { screen in
            let height = screen.frame.maxY - screen.visibleFrame.maxY
            return isInMenuBar(point, screenFrame: screen.frame,
                               menuBarHeight: height > 0 ? height : NSStatusBar.system.thickness)
        }
    }

    /// True while any app shows a menu (a status item's menu included). Needs no permissions.
    static func menuIsOpen() -> Bool {
        let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.contains { $0[kCGWindowLayer as String] as? Int == menuLevel }
    }
}
