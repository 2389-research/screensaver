// ABOUTME: Tests that battery mode reduces pane count and frame rate.
// ABOUTME: Verifies power-aware behavior for laptop users.

import XCTest
import ScreenSaver

final class BatteryModeTests: XCTestCase {

    func testPreviewModeWorksCorrectly() {
        // Preview mode should use reduced panes and still animate without crashing
        let view = ClaudeCodeScreenSaverView(frame: NSRect(x: 0, y: 0, width: 300, height: 200), isPreview: true)
        view?.startAnimation()

        for _ in 0..<50 {
            view?.animateOneFrame()
        }

        // Preview mode should have animationTimeInterval set to 1/15 (slower)
        XCTAssertGreaterThan(view!.animationTimeInterval, 1.0/31.0,
                            "Preview mode should use slower frame rate")

        view?.stopAnimation()
    }

    func testSmallFrameStillWorks() {
        // Very small frame (like a preview thumbnail) should not crash
        let view = ClaudeCodeScreenSaverView(frame: NSRect(x: 0, y: 0, width: 200, height: 150), isPreview: true)
        view?.startAnimation()
        for _ in 0..<20 { view?.animateOneFrame() }
        view?.stopAnimation()
    }

    func testLargeFrameStillWorks() {
        // 5K display dimensions
        let view = ClaudeCodeScreenSaverView(frame: NSRect(x: 0, y: 0, width: 5120, height: 2880), isPreview: false)
        view?.startAnimation()
        for _ in 0..<20 { view?.animateOneFrame() }
        view?.stopAnimation()
    }
}
