// ABOUTME: Tests for the binary-tree pane layout engine.
// ABOUTME: Verifies split/close/resize operations and constraint enforcement.

import XCTest
import CoreText

final class TmuxLayoutEngineTests: XCTestCase {

    func testInitialLayoutProducesPanesInRange() {
        let engine = TmuxLayoutEngine(bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                       minPanes: 3, maxPanes: 8, seed: 42)
        let layouts = engine.currentLayouts()
        XCTAssertGreaterThanOrEqual(layouts.count, 3)
        XCTAssertLessThanOrEqual(layouts.count, 8)
    }

    func testAllPanesFitWithinBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let engine = TmuxLayoutEngine(bounds: bounds, minPanes: 5, maxPanes: 8, seed: 42)
        for layout in engine.currentLayouts() {
            XCTAssertGreaterThanOrEqual(layout.frame.minX, bounds.minX - 0.5)
            XCTAssertGreaterThanOrEqual(layout.frame.minY, bounds.minY - 0.5)
            XCTAssertLessThanOrEqual(layout.frame.maxX, bounds.maxX + 0.5)
            XCTAssertLessThanOrEqual(layout.frame.maxY, bounds.maxY + 0.5)
        }
    }

    func testMinimumPaneSizeRespected() {
        let engine = TmuxLayoutEngine(bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                       minPanes: 8, maxPanes: 12, seed: 42)
        let floorFont = CTFontCreateWithName("Menlo" as CFString, 9.0, nil)
        var glyphs: [CGGlyph] = [0]
        let chars: [UniChar] = [0x4D]
        CTFontGetGlyphsForCharacters(floorFont, chars, &glyphs, 1)
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(floorFont, .horizontal, glyphs, &advance, 1)
        let minWidth = CGFloat(40) * advance.width
        let lineHeight = CTFontGetAscent(floorFont) + CTFontGetDescent(floorFont) + CTFontGetLeading(floorFont)
        let minHeight = CGFloat(10) * lineHeight

        for layout in engine.currentLayouts() {
            XCTAssertGreaterThanOrEqual(layout.frame.width, minWidth - 1,
                                       "Pane \(layout.id) too narrow: \(layout.frame.width)")
            XCTAssertGreaterThanOrEqual(layout.frame.height, minHeight - 1,
                                       "Pane \(layout.id) too short: \(layout.frame.height)")
        }
    }

    func testExactlyOneActivePane() {
        let engine = TmuxLayoutEngine(bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                       minPanes: 5, maxPanes: 8, seed: 42)
        let activeCount = engine.currentLayouts().filter(\.isActive).count
        XCTAssertEqual(activeCount, 1)
    }

    func testSplitIncreasesPaneCount() {
        let engine = TmuxLayoutEngine(bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                       minPanes: 3, maxPanes: 12, seed: 42)
        let before = engine.currentLayouts().count
        let didSplit = engine.trySplit()
        if didSplit {
            XCTAssertEqual(engine.currentLayouts().count, before + 1)
        }
    }

    func testCloseDecreasesPaneCount() {
        let engine = TmuxLayoutEngine(bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                       minPanes: 3, maxPanes: 12, seed: 42)
        let before = engine.currentLayouts().count
        guard before > 3 else { return }
        let didClose = engine.tryClose()
        if didClose {
            XCTAssertEqual(engine.currentLayouts().count, before - 1)
        }
    }

    func testPaneCountNeverExceedsMax() {
        let engine = TmuxLayoutEngine(bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                       minPanes: 3, maxPanes: 8, seed: 42)
        for _ in 0..<100 { _ = engine.trySplit() }
        XCTAssertLessThanOrEqual(engine.currentLayouts().count, 8)
    }

    func testPaneCountNeverDropsBelowMin() {
        let engine = TmuxLayoutEngine(bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                       minPanes: 3, maxPanes: 8, seed: 42)
        for _ in 0..<100 { _ = engine.tryClose() }
        XCTAssertGreaterThanOrEqual(engine.currentLayouts().count, 3)
    }

    func testSplitRatiosReasonable() {
        let engine = TmuxLayoutEngine(bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                       minPanes: 3, maxPanes: 12, seed: 42)
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
        let engine1 = TmuxLayoutEngine(bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                        minPanes: 5, maxPanes: 8, seed: 42)
        let engine2 = TmuxLayoutEngine(bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                        minPanes: 5, maxPanes: 8, seed: 42)
        XCTAssertEqual(engine1.currentLayouts().count, engine2.currentLayouts().count)
        for (l1, l2) in zip(engine1.currentLayouts(), engine2.currentLayouts()) {
            XCTAssertEqual(l1.frame, l2.frame)
        }
    }

    func testManyMutationsNeverCrash() {
        let engine = TmuxLayoutEngine(bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                       minPanes: 3, maxPanes: 12, seed: 42)
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
}
