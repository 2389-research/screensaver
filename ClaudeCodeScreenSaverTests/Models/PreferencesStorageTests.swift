// ABOUTME: Tests for platform-specific Preferences persistence via ScreenSaverDefaults.
// ABOUTME: Verifies save/load round-trip and default value handling.

import XCTest

final class PreferencesStorageTests: XCTestCase {
    private let testBundleID = "com.2389.ClaudeCodeScreenSaver.test"

    func testSaveAndLoadRoundTrip() {
        var prefs = Preferences()
        prefs.colorScheme = .light
        prefs.paneDensityMax = 10

        PreferencesStorage.save(prefs, bundleIdentifier: testBundleID)
        let loaded = PreferencesStorage.load(bundleIdentifier: testBundleID)

        XCTAssertEqual(loaded.colorScheme, .light)
        XCTAssertEqual(loaded.paneDensityMax, 10)
    }

    func testLoadFromEmptyReturnsDefaults() {
        let loaded = PreferencesStorage.load(bundleIdentifier: "com.2389.nonexistent.test")
        XCTAssertEqual(loaded, Preferences())
    }
}
