// ABOUTME: Tests for per-line CATextLayer terminal renderer.
// ABOUTME: Verifies line layer count, dirty tracking, cursor positioning, and blink behavior.

import XCTest
import AppKit

final class TerminalRendererTests: XCTestCase {

    func testCreatesCorrectNumberOfLineLayers() {
        let renderer = TerminalRenderer(frame: CGRect(x: 0, y: 0, width: 500, height: 300), theme: .dark)
        XCTAssertEqual(renderer.lineLayers.count, renderer.fontMetrics.rows)
        XCTAssertGreaterThan(renderer.lineLayers.count, 0)
    }

    func testLineLayersHaveCorrectHeight() {
        let renderer = TerminalRenderer(frame: CGRect(x: 0, y: 0, width: 500, height: 300), theme: .dark)
        for layer in renderer.lineLayers {
            XCTAssertEqual(layer.frame.height, renderer.fontMetrics.lineHeight, accuracy: 0.1)
        }
    }

    func testLineLayersHaveRetinalScale() {
        let renderer = TerminalRenderer(frame: CGRect(x: 0, y: 0, width: 500, height: 300), theme: .dark)
        for layer in renderer.lineLayers {
            XCTAssertGreaterThanOrEqual(layer.contentsScale, 1.0)
        }
    }

    func testCursorLayerExists() {
        let renderer = TerminalRenderer(frame: CGRect(x: 0, y: 0, width: 500, height: 300), theme: .dark)
        XCTAssertNotNil(renderer.cursorLayer.superlayer)
        XCTAssertEqual(renderer.cursorLayer.frame.width, renderer.fontMetrics.charAdvance, accuracy: 0.1)
    }

    func testCursorPositioning() {
        let renderer = TerminalRenderer(frame: CGRect(x: 0, y: 0, width: 500, height: 300), theme: .dark)
        let builder = AttributedStringBuilder(theme: .dark, font: renderer.fontMetrics.font)
        let lines = [builder.responseLine(text: "line 0"), builder.responseLine(text: "line 1"), builder.responseLine(text: "line 2")]
        renderer.update(lines: lines, cursorPosition: (row: 2, col: 5), deltaTime: 0.0)

        let expectedY = renderer.fontMetrics.lineHeight * 2
        XCTAssertEqual(renderer.cursorLayer.frame.origin.y, expectedY, accuracy: 1.0)
        let expectedX = renderer.fontMetrics.charAdvance * 5
        XCTAssertEqual(renderer.cursorLayer.frame.origin.x, expectedX, accuracy: 1.0)
    }

    func testCursorBlinkToggles() {
        let renderer = TerminalRenderer(frame: CGRect(x: 0, y: 0, width: 500, height: 300), theme: .dark)
        let lines = [AttributedStringBuilder(theme: .dark, font: renderer.fontMetrics.font).responseLine(text: "test")]

        // Initially visible
        renderer.update(lines: lines, cursorPosition: (row: 0, col: 0), deltaTime: 0.0)
        XCTAssertFalse(renderer.cursorLayer.isHidden)

        // After 530ms, should toggle
        renderer.update(lines: lines, cursorPosition: (row: 0, col: 0), deltaTime: 0.530)
        XCTAssertTrue(renderer.cursorLayer.isHidden)

        // After another 530ms, should toggle back
        renderer.update(lines: lines, cursorPosition: (row: 0, col: 0), deltaTime: 0.530)
        XCTAssertFalse(renderer.cursorLayer.isHidden)
    }

    func testDirtyTrackingSkipsUnchangedLines() {
        let renderer = TerminalRenderer(frame: CGRect(x: 0, y: 0, width: 500, height: 300), theme: .dark)
        let builder = AttributedStringBuilder(theme: .dark, font: renderer.fontMetrics.font)
        let lines = [builder.responseLine(text: "unchanged")]

        // First update sets the line
        renderer.update(lines: lines, cursorPosition: (row: 0, col: 0), deltaTime: 0.0)
        let firstString = renderer.lineLayers[0].string as? NSAttributedString

        // Second update with same content — layer string should be the same object reference or equal
        renderer.update(lines: lines, cursorPosition: (row: 0, col: 0), deltaTime: 0.01)
        let secondString = renderer.lineLayers[0].string as? NSAttributedString
        XCTAssertEqual(firstString?.string, secondString?.string)
    }

    func testContainerLayerHasCorrectBackground() {
        let renderer = TerminalRenderer(frame: CGRect(x: 0, y: 0, width: 500, height: 300), theme: .dark)
        XCTAssertNotNil(renderer.containerLayer.backgroundColor)
    }

    func testImplicitAnimationsSuppressed() {
        let renderer = TerminalRenderer(frame: CGRect(x: 0, y: 0, width: 500, height: 300), theme: .dark)
        for layer in renderer.lineLayers {
            let actions = layer.actions
            XCTAssertNotNil(actions?["contents"])
            XCTAssertNotNil(actions?["string"])
        }
    }

    func testLineLayersPositionedCorrectly() {
        let renderer = TerminalRenderer(frame: CGRect(x: 0, y: 0, width: 500, height: 300), theme: .dark)
        for (index, layer) in renderer.lineLayers.enumerated() {
            let expectedY = CGFloat(index) * renderer.fontMetrics.lineHeight
            XCTAssertEqual(layer.frame.origin.y, expectedY, accuracy: 0.1,
                           "Line layer \(index) should be at y=\(expectedY)")
            XCTAssertEqual(layer.frame.origin.x, 0, accuracy: 0.1)
        }
    }

    func testViewportShowsBottomLines() {
        let renderer = TerminalRenderer(frame: CGRect(x: 0, y: 0, width: 500, height: 300), theme: .dark)
        let builder = AttributedStringBuilder(theme: .dark, font: renderer.fontMetrics.font)
        let rowCount = renderer.fontMetrics.rows

        // Create more lines than can fit in the viewport
        var lines: [NSAttributedString] = []
        for i in 0..<(rowCount + 5) {
            lines.append(builder.responseLine(text: "line \(i)"))
        }

        renderer.update(lines: lines, cursorPosition: (row: 0, col: 0), deltaTime: 0.0)

        // The first visible line should be line 5 (bottom N lines of rowCount+5 total)
        let firstVisibleString = (renderer.lineLayers[0].string as? NSAttributedString)?.string
        XCTAssertEqual(firstVisibleString, "line 5")

        // The last visible line should be the last line
        let lastVisibleString = (renderer.lineLayers[rowCount - 1].string as? NSAttributedString)?.string
        XCTAssertEqual(lastVisibleString, "line \(rowCount + 4)")
    }

    func testCursorLayerSuppressesAnimations() {
        let renderer = TerminalRenderer(frame: CGRect(x: 0, y: 0, width: 500, height: 300), theme: .dark)
        let actions = renderer.cursorLayer.actions
        XCTAssertNotNil(actions?["position"])
        XCTAssertNotNil(actions?["bounds"])
        XCTAssertNotNil(actions?["hidden"])
    }

    func testEmptyLinesUpdate() {
        let renderer = TerminalRenderer(frame: CGRect(x: 0, y: 0, width: 500, height: 300), theme: .dark)
        // Update with no lines — all layers should be nil/empty
        renderer.update(lines: [], cursorPosition: (row: 0, col: 0), deltaTime: 0.0)
        for layer in renderer.lineLayers {
            let str = layer.string as? NSAttributedString
            XCTAssertNil(str)
        }
    }

    func testCursorRowClampedToMaxRows() {
        let renderer = TerminalRenderer(frame: CGRect(x: 0, y: 0, width: 500, height: 300), theme: .dark)
        let builder = AttributedStringBuilder(theme: .dark, font: renderer.fontMetrics.font)
        let lines = [builder.responseLine(text: "test")]

        // Pass a cursor row way beyond visible area
        renderer.update(lines: lines, cursorPosition: (row: 9999, col: 0), deltaTime: 0.0)

        let maxRow = renderer.fontMetrics.rows - 1
        let expectedY = CGFloat(maxRow) * renderer.fontMetrics.lineHeight
        XCTAssertEqual(renderer.cursorLayer.frame.origin.y, expectedY, accuracy: 1.0)
    }
}
