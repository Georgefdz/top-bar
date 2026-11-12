import CoreGraphics

/// A status item owned by another app. `frame` is in global top-left-origin
/// coordinates (Accessibility / CGEvent space); x matches AppKit's x.
struct MenuBarItem: Identifiable, Equatable {
    let pid: pid_t
    let bundleID: String
    let appName: String
    let frame: CGRect

    var id: String { "\(bundleID)#\(Int(frame.minX))" }
}
