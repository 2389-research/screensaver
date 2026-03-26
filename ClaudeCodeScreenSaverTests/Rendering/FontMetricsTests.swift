// ABOUTME: Tests for font metric computation including size bounds and glyph measurement.
// ABOUTME: Verifies 9pt floor, 14pt ceiling, and correct column/row calculation.

import XCTest
import CoreText

final class FontMetricsTests: XCTestCase {

    func testFontSizeFloorAt9pt() {
        // Very small rect should hit the 9pt floor
        let metrics = FontMetrics.compute(for: CGRect(x: 0, y: 0, width: 100, height: 50))
        XCTAssertEqual(metrics.fontSize, 9.0)
    }

    func testFontSizeCeilingAt14pt() {
        // Very large rect should hit the 14pt ceiling
        let metrics = FontMetrics.compute(for: CGRect(x: 0, y: 0, width: 5000, height: 3000))
        XCTAssertEqual(metrics.fontSize, 14.0)
    }

    func testColsAndRowsPositive() {
        let metrics = FontMetrics.compute(for: CGRect(x: 0, y: 0, width: 800, height: 600))
        XCTAssertGreaterThan(metrics.cols, 0)
        XCTAssertGreaterThan(metrics.rows, 0)
    }

    func testCharAdvancePositive() {
        let metrics = FontMetrics.compute(for: CGRect(x: 0, y: 0, width: 800, height: 600))
        XCTAssertGreaterThan(metrics.charAdvance, 0)
    }

    func testLineHeightPositive() {
        let metrics = FontMetrics.compute(for: CGRect(x: 0, y: 0, width: 800, height: 600))
        XCTAssertGreaterThan(metrics.lineHeight, 0)
    }

    func testColsTimesAdvanceDoesNotExceedWidth() {
        let rect = CGRect(x: 0, y: 0, width: 800, height: 600)
        let metrics = FontMetrics.compute(for: rect)
        XCTAssertLessThanOrEqual(CGFloat(metrics.cols) * metrics.charAdvance, rect.width)
    }

    func testRowsTimesHeightDoesNotExceedHeight() {
        let rect = CGRect(x: 0, y: 0, width: 800, height: 600)
        let metrics = FontMetrics.compute(for: rect)
        XCTAssertLessThanOrEqual(CGFloat(metrics.rows) * metrics.lineHeight, rect.height)
    }

    func testMenloFontUsed() {
        let metrics = FontMetrics.compute(for: CGRect(x: 0, y: 0, width: 800, height: 600))
        let fontName = CTFontCopyPostScriptName(metrics.font) as String
        XCTAssertTrue(fontName.contains("Menlo"), "Expected Menlo font, got \(fontName)")
    }
}
