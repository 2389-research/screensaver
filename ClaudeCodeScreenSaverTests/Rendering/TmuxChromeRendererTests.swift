// ABOUTME: Tests for tmux status bar text formatting and active pane management.
// ABOUTME: These tests are NOT optional — tmux chrome authenticity is critical.

import XCTest
import CoreText

final class TmuxChromeRendererTests: XCTestCase {

    func testStatusBarLeftTextFormat() {
        let chrome = TmuxChromeRenderer(sessionName: "rest-api", windowCount: 4, activeWindow: 0, lastWindow: 1)
        let left = chrome.statusBarLeftText()
        XCTAssertTrue(left.hasPrefix("[rest-api]"), "Should start with session name, got: \(left)")
        XCTAssertTrue(left.contains("0:agent*"), "Active window should have * flag")
        XCTAssertTrue(left.contains("1:agent-"), "Last window should have - flag")
        XCTAssertTrue(left.contains("2:agent ") || left.contains("2:agent"), "Other windows should have no flag")
    }

    func testStatusBarRightTextHasTimeAndDate() {
        let chrome = TmuxChromeRenderer(sessionName: "test", windowCount: 1, activeWindow: 0, lastWindow: 0)
        let right = chrome.statusBarRightText()
        // Should match HH:MM DD-Mon-YYYY format
        // Example: "14:32 25-Mar-2026"
        let pattern = "\\d{2}:\\d{2} \\d{2}-[A-Z][a-z]{2}-\\d{4}"
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.numberOfMatches(in: right, range: NSRange(right.startIndex..., in: right))
        XCTAssertEqual(matches, 1, "Right text should match time+date format, got: \(right)")
    }

    func testStatusBarRightTextHasNoHostname() {
        let chrome = TmuxChromeRenderer(sessionName: "test", windowCount: 1, activeWindow: 0, lastWindow: 0)
        let right = chrome.statusBarRightText()
        let hostname = ProcessInfo.processInfo.hostName
        XCTAssertFalse(right.contains(hostname), "Status bar should NOT contain hostname")
    }

    func testStatusBarRightTextHasFourDigitYear() {
        let chrome = TmuxChromeRenderer(sessionName: "test", windowCount: 1, activeWindow: 0, lastWindow: 0)
        let right = chrome.statusBarRightText()
        // Should contain 4-digit year (2025, 2026, etc.)
        let yearPattern = "\\d{4}$"
        let regex = try! NSRegularExpression(pattern: yearPattern)
        let matches = regex.numberOfMatches(in: right, range: NSRange(right.startIndex..., in: right))
        XCTAssertEqual(matches, 1, "Should end with 4-digit year, got: \(right)")
    }

    func testStatusBarHeightIsOneLine() {
        let font = CTFontCreateWithName("Menlo" as CFString, 12.0, nil)
        let lineHeight = CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
        let chrome = TmuxChromeRenderer(sessionName: "test", windowCount: 1, activeWindow: 0, lastWindow: 0)
        let barHeight = chrome.statusBarHeight(for: font)
        XCTAssertEqual(barHeight, lineHeight, accuracy: 2.0)
    }

    func testSessionNameDerivedFromFileName() {
        let chrome = TmuxChromeRenderer(sessionName: "build-rest-api", windowCount: 4, activeWindow: 0, lastWindow: 1)
        let left = chrome.statusBarLeftText()
        XCTAssertTrue(left.contains("[build-rest-api]"), "Session name should come from filename")
    }

    func testWindowCountMatchesPaneCount() {
        let chrome = TmuxChromeRenderer(sessionName: "test", windowCount: 6, activeWindow: 0, lastWindow: 1)
        let left = chrome.statusBarLeftText()
        // Should have windows 0-5
        XCTAssertTrue(left.contains("5:agent"), "Should have window 5 for 6 panes")
        XCTAssertFalse(left.contains("6:agent"), "Should NOT have window 6")
    }

    func testActiveWindowFlag() {
        let chrome = TmuxChromeRenderer(sessionName: "test", windowCount: 4, activeWindow: 2, lastWindow: 0)
        let left = chrome.statusBarLeftText()
        XCTAssertTrue(left.contains("2:agent*"), "Window 2 should be active")
        XCTAssertTrue(left.contains("0:agent-"), "Window 0 should be last-active")
        XCTAssertFalse(left.contains("1:agent*") || left.contains("1:agent-"), "Window 1 should have no flag")
    }

    func testCreateStatusBarLayer() {
        let chrome = TmuxChromeRenderer(sessionName: "test", windowCount: 4, activeWindow: 0, lastWindow: 1)
        let font = CTFontCreateWithName("Menlo" as CFString, 12.0, nil)
        let layer = chrome.createStatusBarLayer(
            width: 1920,
            font: font,
            theme: ThemeColors.dark
        )
        XCTAssertNotNil(layer)
        XCTAssertGreaterThan(layer.sublayers?.count ?? 0, 0, "Status bar should have sublayers")
    }

    func testUpdateActiveWindow() {
        let chrome = TmuxChromeRenderer(sessionName: "test", windowCount: 4, activeWindow: 0, lastWindow: 1)
        chrome.updateActiveWindow(2)
        XCTAssertEqual(chrome.activeWindow, 2, "Active window should update to 2")
        XCTAssertEqual(chrome.lastWindow, 0, "Last window should be previous active (0)")
        let left = chrome.statusBarLeftText()
        XCTAssertTrue(left.contains("2:agent*"), "Window 2 should now be active")
        XCTAssertTrue(left.contains("0:agent-"), "Window 0 should now be last-active")
    }
}
