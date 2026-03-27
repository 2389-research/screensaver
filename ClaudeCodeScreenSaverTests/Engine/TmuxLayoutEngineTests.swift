// ABOUTME: Tests for the binary-tree pane layout engine.
// ABOUTME: Verifies split/close/resize operations and constraint enforcement.

import XCTest
import CoreText

final class TmuxLayoutEngineTests: XCTestCase {

    // Shared font metrics for border gaps, computed once from 9pt Menlo
    private static let testCharAdvance: CGFloat = {
        let font = CTFontCreateWithName("Menlo" as CFString, 9.0, nil)
        var glyphs: [CGGlyph] = [0]
        let chars: [UniChar] = [0x4D]
        CTFontGetGlyphsForCharacters(font, chars, &glyphs, 1)
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advance, 1)
        return advance.width
    }()

    private static let testLineHeight: CGFloat = {
        let font = CTFontCreateWithName("Menlo" as CFString, 9.0, nil)
        return CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
    }()

    private func makeEngine(bounds: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080),
                            minPanes: Int = 3, maxPanes: Int = 8, seed: UInt64 = 42) -> TmuxLayoutEngine {
        TmuxLayoutEngine(bounds: bounds, minPanes: minPanes, maxPanes: maxPanes, seed: seed,
                         charAdvance: Self.testCharAdvance, lineHeight: Self.testLineHeight)
    }

    func testInitialLayoutProducesPanesInRange() {
        let engine = makeEngine(minPanes: 3, maxPanes: 8)
        let layouts = engine.currentLayouts()
        XCTAssertGreaterThanOrEqual(layouts.count, 3)
        XCTAssertLessThanOrEqual(layouts.count, 8)
    }

    func testAllPanesFitWithinBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let engine = makeEngine(bounds: bounds, minPanes: 5, maxPanes: 8)
        for layout in engine.currentLayouts() {
            XCTAssertGreaterThanOrEqual(layout.frame.minX, bounds.minX - 0.5)
            XCTAssertGreaterThanOrEqual(layout.frame.minY, bounds.minY - 0.5)
            XCTAssertLessThanOrEqual(layout.frame.maxX, bounds.maxX + 0.5)
            XCTAssertLessThanOrEqual(layout.frame.maxY, bounds.maxY + 0.5)
        }
    }

    func testMinimumPaneSizeRespected() {
        let engine = makeEngine(minPanes: 8, maxPanes: 12)
        let floorFont = CTFontCreateWithName("Menlo" as CFString, 9.0, nil)
        var glyphs: [CGGlyph] = [0]
        let chars: [UniChar] = [0x4D]
        CTFontGetGlyphsForCharacters(floorFont, chars, &glyphs, 1)
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(floorFont, .horizontal, glyphs, &advance, 1)
        let minWidth = CGFloat(40) * advance.width
        let lineHeight = CTFontGetAscent(floorFont) + CTFontGetDescent(floorFont) + CTFontGetLeading(floorFont)
        let minHeight = CGFloat(10) * lineHeight

        // Allow tolerance for rounding from floor() in gap-aware splits
        let gapTolerance: CGFloat = lineHeight
        for layout in engine.currentLayouts() {
            XCTAssertGreaterThanOrEqual(layout.frame.width, minWidth - advance.width - 1,
                                       "Pane \(layout.id) too narrow: \(layout.frame.width)")
            XCTAssertGreaterThanOrEqual(layout.frame.height, minHeight - gapTolerance - 1,
                                       "Pane \(layout.id) too short: \(layout.frame.height)")
        }
    }

    func testExactlyOneActivePane() {
        let engine = makeEngine(minPanes: 5, maxPanes: 8)
        let activeCount = engine.currentLayouts().filter(\.isActive).count
        XCTAssertEqual(activeCount, 1)
    }

    func testSplitIncreasesPaneCount() {
        let engine = makeEngine(minPanes: 3, maxPanes: 12)
        let before = engine.currentLayouts().count
        let didSplit = engine.trySplit()
        if didSplit {
            XCTAssertEqual(engine.currentLayouts().count, before + 1)
        }
    }

    func testCloseDecreasesPaneCount() {
        let engine = makeEngine(minPanes: 3, maxPanes: 12)
        let before = engine.currentLayouts().count
        guard before > 3 else { return }
        let didClose = engine.tryClose()
        if didClose {
            XCTAssertEqual(engine.currentLayouts().count, before - 1)
        }
    }

    func testPaneCountNeverExceedsMax() {
        let engine = makeEngine(minPanes: 3, maxPanes: 8)
        for _ in 0..<100 { _ = engine.trySplit() }
        XCTAssertLessThanOrEqual(engine.currentLayouts().count, 8)
    }

    func testPaneCountNeverDropsBelowMin() {
        let engine = makeEngine(minPanes: 3, maxPanes: 8)
        for _ in 0..<100 { _ = engine.tryClose() }
        XCTAssertGreaterThanOrEqual(engine.currentLayouts().count, 3)
    }

    func testSplitRatiosReasonable() {
        let engine = makeEngine(minPanes: 3, maxPanes: 12)
        for _ in 0..<10 { _ = engine.trySplit() }
        let layouts = engine.currentLayouts()
        for layout in layouts {
            let widthRatio = layout.frame.width / 1920
            let heightRatio = layout.frame.height / 1080
            XCTAssertLessThanOrEqual(widthRatio, 0.75, "Pane too wide: \(widthRatio)")
            XCTAssertLessThanOrEqual(heightRatio, 0.75, "Pane too tall: \(heightRatio)")
        }
    }

    func testDeterministicWithSameSeed() {
        let engine1 = makeEngine(minPanes: 5, maxPanes: 8, seed: 42)
        let engine2 = makeEngine(minPanes: 5, maxPanes: 8, seed: 42)
        XCTAssertEqual(engine1.currentLayouts().count, engine2.currentLayouts().count)
        for (l1, l2) in zip(engine1.currentLayouts(), engine2.currentLayouts()) {
            XCTAssertEqual(l1.frame, l2.frame)
        }
    }

    func testManyMutationsNeverCrash() {
        let engine = makeEngine(minPanes: 3, maxPanes: 12)
        for i in 0..<1000 {
            switch i % 3 {
            case 0: _ = engine.trySplit()
            case 1: _ = engine.tryClose()
            default: engine.tryResize()
            }
            let layouts = engine.currentLayouts()
            XCTAssertGreaterThanOrEqual(layouts.count, 3)
            XCTAssertLessThanOrEqual(layouts.count, 12)
            XCTAssertEqual(layouts.filter(\.isActive).count, 1)
        }
    }

    func testGapsBetweenAdjacentPanes() {
        // Verify that horizontally adjacent panes have a charAdvance-sized gap
        let engine = makeEngine(minPanes: 2, maxPanes: 4, seed: 42)
        let layouts = engine.currentLayouts()
        guard layouts.count >= 2 else { return }

        let tolerance = min(Self.testCharAdvance, Self.testLineHeight) * 0.5

        // Check all pairs for proper gap spacing
        for i in 0..<layouts.count {
            for j in (i + 1)..<layouts.count {
                let a = layouts[i].frame
                let b = layouts[j].frame

                // Check horizontal adjacency (a left of b)
                let hGapAB = b.minX - a.maxX
                if hGapAB > 0 && hGapAB < Self.testCharAdvance * 2 {
                    XCTAssertEqual(hGapAB, Self.testCharAdvance, accuracy: tolerance,
                                   "Horizontal gap should be one charAdvance")
                }

                // Check horizontal adjacency (b left of a)
                let hGapBA = a.minX - b.maxX
                if hGapBA > 0 && hGapBA < Self.testCharAdvance * 2 {
                    XCTAssertEqual(hGapBA, Self.testCharAdvance, accuracy: tolerance,
                                   "Horizontal gap should be one charAdvance")
                }

                // Check vertical adjacency (a below b)
                let vGapAB = b.minY - a.maxY
                if vGapAB > 0 && vGapAB < Self.testLineHeight * 2 {
                    XCTAssertEqual(vGapAB, Self.testLineHeight, accuracy: tolerance,
                                   "Vertical gap should be one lineHeight")
                }

                // Check vertical adjacency (b below a)
                let vGapBA = a.minY - b.maxY
                if vGapBA > 0 && vGapBA < Self.testLineHeight * 2 {
                    XCTAssertEqual(vGapBA, Self.testLineHeight, accuracy: tolerance,
                                   "Vertical gap should be one lineHeight")
                }
            }
        }
    }
}
