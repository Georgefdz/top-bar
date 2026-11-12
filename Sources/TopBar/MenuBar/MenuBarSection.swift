enum MenuBarSection: String, CaseIterable, Identifiable {
    case visible, hidden, alwaysHidden

    var id: String { rawValue }

    var title: String {
        switch self {
        case .visible: "Visible"
        case .hidden: "Hidden"
        case .alwaysHidden: "Always Hidden"
        }
    }
}

extension MenuBarSection {
    /// Bundle IDs to keep visible when `blocked` sections are hidden; `nil` means no restriction.
    /// Apps without a saved section stay visible.
    static func allowedBundles(running: [String], sections: [String: MenuBarSection],
                               blocking blocked: Set<MenuBarSection>) -> [String]? {
        guard !blocked.isEmpty else { return nil }
        return Set(running).filter { sections[$0].map { !blocked.contains($0) } ?? true }.sorted()
    }
}
