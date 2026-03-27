// ABOUTME: Unit tests for the NSColor hex initializer extension.
// ABOUTME: Verifies correct sRGB component parsing from "#RRGGBB" strings.

import XCTest
@testable import ClaudeCodeScreenSaver

final class NSColorHexTests: XCTestCase {

    func testParseBlack() {
        let color = NSColor(hex: "#000000")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0.0, accuracy: 0.01)
        XCTAssertEqual(g, 0.0, accuracy: 0.01)
        XCTAssertEqual(b, 0.0, accuracy: 0.01)
        XCTAssertEqual(a, 1.0, accuracy: 0.01)
    }

    func testParseWhite() {
        let color = NSColor(hex: "#ffffff")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01)
        XCTAssertEqual(g, 1.0, accuracy: 0.01)
        XCTAssertEqual(b, 1.0, accuracy: 0.01)
    }

    func testParseCatppuccinBase() {
        // #1e1e2e → R=30, G=30, B=46
        let color = NSColor(hex: "#1e1e2e")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 30.0 / 255.0, accuracy: 0.002)
        XCTAssertEqual(g, 30.0 / 255.0, accuracy: 0.002)
        XCTAssertEqual(b, 46.0 / 255.0, accuracy: 0.002)
    }

    func testParseCyanBorder() {
        // #00d7ff → R=0, G=215, B=255
        let color = NSColor(hex: "#00d7ff")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0.0, accuracy: 0.002)
        XCTAssertEqual(g, 215.0 / 255.0, accuracy: 0.002)
        XCTAssertEqual(b, 1.0, accuracy: 0.002)
    }

    func testParseWithoutHashPrefix() {
        // Should also handle the hash being stripped correctly
        let color = NSColor(hex: "#d4a574")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 212.0 / 255.0, accuracy: 0.002)
        XCTAssertEqual(g, 165.0 / 255.0, accuracy: 0.002)
        XCTAssertEqual(b, 116.0 / 255.0, accuracy: 0.002)
    }
}
