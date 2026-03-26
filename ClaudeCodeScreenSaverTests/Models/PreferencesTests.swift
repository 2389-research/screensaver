// ABOUTME: Tests for Preferences Codable round-trip and default values.
// ABOUTME: Verifies serialization/deserialization produces identical structs.

import XCTest

final class PreferencesTests: XCTestCase {
    func testDefaultValues() {
        let prefs = Preferences()
        XCTAssertEqual(prefs.colorScheme, .dark)
        XCTAssertEqual(prefs.paneDensityMin, 5)
        XCTAssertEqual(prefs.paneDensityMax, 8)
        XCTAssertFalse(prefs.useRealSessions)
        XCTAssertNil(prefs.sessionDirectoryBookmark)
        XCTAssertEqual(prefs.evolutionSpeedMin, 60)
        XCTAssertEqual(prefs.evolutionSpeedMax, 90)
        XCTAssertFalse(prefs.oledSafeMode)
    }

    func testCodableRoundTrip() throws {
        var prefs = Preferences()
        prefs.colorScheme = .light
        prefs.paneDensityMin = 3
        prefs.paneDensityMax = 12
        prefs.useRealSessions = true
        prefs.sessionDirectoryBookmark = Data([0x01, 0x02, 0x03])
        prefs.evolutionSpeedMin = 30
        prefs.evolutionSpeedMax = 60
        prefs.oledSafeMode = true

        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(Preferences.self, from: data)
        XCTAssertEqual(prefs, decoded)
    }

    func testPartialDecodeFallsBackToDefaults() throws {
        // Simulate a future version adding a new field — old data should still decode
        let json = #"{"colorScheme":"dark","paneDensityMin":5,"paneDensityMax":8,"useRealSessions":false,"evolutionSpeedMin":60,"evolutionSpeedMax":90,"oledSafeMode":false}"#
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Preferences.self, from: data)
        XCTAssertEqual(decoded.colorScheme, .dark)
        XCTAssertNil(decoded.sessionDirectoryBookmark)
    }
}
