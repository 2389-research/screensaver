// ABOUTME: Tests for Preferences Codable round-trip and default values.
// ABOUTME: Verifies serialization/deserialization produces identical structs.

import XCTest

final class PreferencesTests: XCTestCase {
    func testDefaultValues() {
        let prefs = Preferences()
        XCTAssertEqual(prefs.colorScheme, .dark)
        XCTAssertEqual(prefs.paneDensityMax, 8)
        XCTAssertEqual(prefs.evolutionSpeedMin, 60)
        XCTAssertEqual(prefs.evolutionSpeedMax, 90)
    }

    func testCodableRoundTrip() throws {
        var prefs = Preferences()
        prefs.colorScheme = .light
        prefs.paneDensityMax = 12
        prefs.evolutionSpeedMin = 30
        prefs.evolutionSpeedMax = 60

        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(Preferences.self, from: data)
        XCTAssertEqual(prefs, decoded)
    }

    func testPartialDecodeFallsBackToDefaults() throws {
        let json = #"{"colorScheme":"dark","paneDensityMax":8,"evolutionSpeedMin":60,"evolutionSpeedMax":90}"#
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Preferences.self, from: data)
        XCTAssertEqual(decoded.colorScheme, .dark)
        XCTAssertEqual(decoded.paneDensityMax, 8)
    }
}
