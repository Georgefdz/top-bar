import AppKit
import ApplicationServices

/// Reads other apps' status items through the Accessibility API.
@MainActor
enum MenuBarItemScanner {
    static func scan() -> [MenuBarItem] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications
            .filter { $0.processIdentifier != ownPID }
            .flatMap(items(of:))
            .sorted { $0.frame.minX < $1.frame.minX }
    }

    /// Right edge of the frontmost app's menus (File, Edit, ...), in global x.
    static func appMenusMaxX() -> CGFloat? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let menuBar = element(application(app.processIdentifier), kAXMenuBarAttribute)
        else { return nil }
        return children(menuBar).compactMap { frame(of: $0)?.maxX }.max()
    }

    private static func items(of app: NSRunningApplication) -> [MenuBarItem] {
        guard let extras = element(application(app.processIdentifier), kAXExtrasMenuBarAttribute)
        else { return [] }
        let bundleID = app.bundleIdentifier ?? app.localizedName ?? "pid-\(app.processIdentifier)"
        return children(extras).compactMap { child in
            frame(of: child).map {
                MenuBarItem(pid: app.processIdentifier, bundleID: bundleID,
                            appName: app.localizedName ?? bundleID, frame: $0)
            }
        }
    }

    private static func application(_ pid: pid_t) -> AXUIElement {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.25) // don't stall on hung apps
        return app
    }

    private static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    private static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let v = value(element, attribute), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }

    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        value(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var origin = CGPoint.zero, size = CGSize.zero
        guard let p = value(element, kAXPositionAttribute), CFGetTypeID(p) == AXValueGetTypeID(),
              let s = value(element, kAXSizeAttribute), CFGetTypeID(s) == AXValueGetTypeID(),
              AXValueGetValue(p as! AXValue, .cgPoint, &origin),
              AXValueGetValue(s as! AXValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }
}
