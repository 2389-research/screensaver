// ABOUTME: Platform-specific load/save for Preferences via ScreenSaverDefaults.
// ABOUTME: Isolated here because it requires ScreenSaver.framework import.

import Foundation
import ScreenSaver

enum PreferencesStorage {
    static func load(bundleIdentifier: String) -> Preferences {
        guard let defaults = ScreenSaverDefaults(forModuleWithName: bundleIdentifier),
              let data = defaults.data(forKey: "preferences") else {
            return Preferences()
        }
        return (try? JSONDecoder().decode(Preferences.self, from: data)) ?? Preferences()
    }

    static func save(_ prefs: Preferences, bundleIdentifier: String) {
        guard let defaults = ScreenSaverDefaults(forModuleWithName: bundleIdentifier),
              let data = try? JSONEncoder().encode(prefs) else { return }
        defaults.set(data, forKey: "preferences")
        defaults.synchronize()
    }
}
