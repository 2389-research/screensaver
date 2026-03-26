// ABOUTME: User-configurable screensaver settings.
// ABOUTME: Foundation-only Codable struct. Storage via ScreenSaverDefaults is in Helpers/PreferencesStorage.swift.

import Foundation

struct Preferences: Codable, Equatable {
    enum ColorSchemeChoice: String, Codable { case dark, light }

    var colorScheme: ColorSchemeChoice = .dark
    var paneDensityMin: Int = 5
    var paneDensityMax: Int = 8
    var useRealSessions: Bool = false
    var sessionDirectoryBookmark: Data? = nil
    var evolutionSpeedMin: TimeInterval = 60
    var evolutionSpeedMax: TimeInterval = 90
    var oledSafeMode: Bool = false
}
