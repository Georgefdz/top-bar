import Foundation
import Observation

/// User preferences, persisted in UserDefaults.
@MainActor
@Observable
final class SettingsStore {
    private enum Keys {
        static let sections = "sections"
        static let showOnHover = "showOnHover"
        static let showOnClick = "showOnClick"
        static let showOnScroll = "showOnScroll"
        static let autoRehide = "autoRehide"
        static let rehideDelay = "rehideDelay"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Bundle ID -> section. Apps not listed are left where the user put them.
    var sections: [String: MenuBarSection] {
        didSet { defaults.set(sections.mapValues(\.rawValue), forKey: Keys.sections) }
    }
    var showOnHover: Bool { didSet { defaults.set(showOnHover, forKey: Keys.showOnHover) } }
    var showOnClick: Bool { didSet { defaults.set(showOnClick, forKey: Keys.showOnClick) } }
    var showOnScroll: Bool { didSet { defaults.set(showOnScroll, forKey: Keys.showOnScroll) } }
    var autoRehide: Bool { didSet { defaults.set(autoRehide, forKey: Keys.autoRehide) } }
    var rehideDelay: Double { didSet { defaults.set(rehideDelay, forKey: Keys.rehideDelay) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.showOnHover: false,
            Keys.showOnClick: true,
            Keys.showOnScroll: true,
            Keys.autoRehide: true,
            Keys.rehideDelay: 3.0,
        ])
        let raw = defaults.dictionary(forKey: Keys.sections) as? [String: String] ?? [:]
        sections = raw.compactMapValues(MenuBarSection.init(rawValue:))
        showOnHover = defaults.bool(forKey: Keys.showOnHover)
        showOnClick = defaults.bool(forKey: Keys.showOnClick)
        showOnScroll = defaults.bool(forKey: Keys.showOnScroll)
        autoRehide = defaults.bool(forKey: Keys.autoRehide)
        rehideDelay = defaults.double(forKey: Keys.rehideDelay)
    }
}
