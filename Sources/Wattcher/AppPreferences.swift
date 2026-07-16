import Foundation

@MainActor
final class AppPreferences {
    private enum Key {
        static let showAllPorts = "showAllPorts"
        static let liveRefreshInterval = "liveRefreshInterval"
        static let refreshedLowImpactDefault = "refreshedLowImpactDefault"
        static let closeAfterOpening = "closeAfterOpening"
        static let globalShortcutEnabled = "globalShortcutEnabled"
        static let globalShortcut = "globalShortcut"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if !defaults.bool(forKey: Key.refreshedLowImpactDefault) {
            defaults.set(10.0, forKey: Key.liveRefreshInterval)
            defaults.set(true, forKey: Key.refreshedLowImpactDefault)
        }
        if defaults.object(forKey: Key.closeAfterOpening) == nil {
            defaults.set(true, forKey: Key.closeAfterOpening)
        }
    }

    var showAllPorts: Bool {
        get { defaults.bool(forKey: Key.showAllPorts) }
        set { defaults.set(newValue, forKey: Key.showAllPorts) }
    }

    var liveRefreshInterval: TimeInterval {
        get { max(2, defaults.double(forKey: Key.liveRefreshInterval)) }
        set { defaults.set(newValue, forKey: Key.liveRefreshInterval) }
    }

    var closeAfterOpening: Bool {
        get { defaults.bool(forKey: Key.closeAfterOpening) }
        set { defaults.set(newValue, forKey: Key.closeAfterOpening) }
    }

    var globalShortcutEnabled: Bool {
        get { defaults.bool(forKey: Key.globalShortcutEnabled) }
        set { defaults.set(newValue, forKey: Key.globalShortcutEnabled) }
    }

    var globalShortcut: GlobalShortcut {
        get {
            guard let value = defaults.string(forKey: Key.globalShortcut),
                  let shortcut = GlobalShortcut(rawValue: value)
            else { return .controlOptionW }
            return shortcut
        }
        set { defaults.set(newValue.rawValue, forKey: Key.globalShortcut) }
    }
}
