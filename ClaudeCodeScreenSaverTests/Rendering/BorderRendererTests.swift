// ABOUTME: Tests for junction-aware text-character border grid generation.
// ABOUTME: Verifies correct junction characters where pane borders meet.

import XCTest
import CoreText

final class BorderRendererTests: XCTestCase {

    // Helper to get the char advance for computing gap positions
    private var charAdvance: CGFloat {
        let font = CTFontCreateWithName("Menlo" as CFString, 12.0, nil)
        var glyphs: [CGGlyph] = [0]
        let chars: [UniChar] = [0x4D]
        CTFontGetGlyphsForCharacters(font, chars, &glyphs, 1)
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advance, 1)
        return advance.width
    }

    func testVerticalBorderBetweenTwoPanes() {
        let gap = charAdvance
        let layouts = [
            PaneLayout(id: UUID(), frame: CGRect(x: 0, y: 0, width: 200, height: 400), isActive: false),
            PaneLayout(id: UUID(), frame: CGRect(x: 200 + gap, y: 0, width: 200, height: 400), isActive: true)
        ]
        let segments = BorderRenderer.computeSegments(
            layouts: layouts,
            totalBounds: CGRect(x: 0, y: 0, width: 400 + gap, height: 400),
            charAdvance: gap,
            lineHeight: 16.0
        )
        XCTAssertFalse(segments.isEmpty, "Should produce border segments")
        let hasVertical = segments.contains(where: { $0.character == "│" })
        XCTAssertTrue(hasVertical, "Should have vertical border characters")
    }

    func testHorizontalBorderBetweenTwoPanes() {
        let gap: CGFloat = 16.0 // line height
        // Two panes stacked vertically with a lineHeight gap between them
        let layouts = [
            PaneLayout(id: UUID(), frame: CGRect(x: 0, y: 0, width: 400, height: 200), isActive: true),
            PaneLayout(id: UUID(), frame: CGRect(x: 0, y: 200 + gap, width: 400, height: 200), isActive: false)
        ]
        let segments = BorderRenderer.computeSegments(
            layouts: layouts,
            totalBounds: CGRect(x: 0, y: 0, width: 400, height: 400 + gap),
            charAdvance: 8.0,
            lineHeight: gap
        )
        let hasHorizontal = segments.contains(where: { $0.character == "─" })
        XCTAssertTrue(hasHorizontal, "Should have horizontal border characters")
    }

    func testCrossJunctionWhereFourPanesMeet() {
        let gapW: CGFloat = 8.0
        let gapH: CGFloat = 16.0
        let pw: CGFloat = 200.0
        let ph: CGFloat = 200.0
        let layouts = [
            PaneLayout(id: UUID(), frame: CGRect(x: 0, y: gapH + ph, width: pw, height: ph), isActive: false),
            PaneLayout(id: UUID(), frame: CGRect(x: pw + gapW, y: gapH + ph, width: pw, height: ph), isActive: false),
            PaneLayout(id: UUID(), frame: CGRect(x: 0, y: 0, width: pw, height: ph), isActive: true),
            PaneLayout(id: UUID(), frame: CGRect(x: pw + gapW, y: 0, width: pw, height: ph), isActive: false)
        ]
        let totalW = pw * 2 + gapW
        let totalH = ph * 2 + gapH
        let segments = BorderRenderer.computeSegments(
            layouts: layouts,
            totalBounds: CGRect(x: 0, y: 0, width: totalW, height: totalH),
            charAdvance: gapW,
            lineHeight: gapH
        )
        let hasCross = segments.contains(where: { $0.character == "┼" })
        XCTAssertTrue(hasCross, "Should have cross junction where four panes meet")
    }

    func testBorderSegmentsHavePositions() {
        let gap = charAdvance
        let layouts = [
            PaneLayout(id: UUID(), frame: CGRect(x: 0, y: 0, width: 200, height: 400), isActive: false),
            PaneLayout(id: UUID(), frame: CGRect(x: 200 + gap, y: 0, width: 200, height: 400), isActive: true)
        ]
        let segments = BorderRenderer.computeSegments(
            layouts: layouts,
            totalBounds: CGRect(x: 0, y: 0, width: 400 + gap, height: 400),
            charAdvance: gap,
            lineHeight: 16.0
        )
        for segment in segments {
            XCTAssertFalse(segment.position.x.isNaN)
            XCTAssertFalse(segment.position.y.isNaN)
        }
    }

    func testActivePaneBorderUsesActiveColor() {
        let gap = charAdvance
        let activeID = UUID()
        let layouts = [
            PaneLayout(id: UUID(), frame: CGRect(x: 0, y: 0, width: 200, height: 400), isActive: false),
            PaneLayout(id: activeID, frame: CGRect(x: 200 + gap, y: 0, width: 200, height: 400), isActive: true)
        ]
        let segments = BorderRenderer.computeSegments(
            layouts: layouts,
            totalBounds: CGRect(x: 0, y: 0, width: 400 + gap, height: 400),
            charAdvance: gap,
            lineHeight: 16.0
        )
        // Segments adjacent to the active pane should be marked as active
        let hasActive = segments.contains(where: { $0.isAdjacentToActive })
        XCTAssertTrue(hasActive)
    }
}
