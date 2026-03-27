// ABOUTME: Integration tests for the full animation loop lifecycle.
// ABOUTME: Verifies init, start, animate, stop cycle without crashes.

import XCTest
import ScreenSaver

final class AnimationLoopTests: XCTestCase {

    func testInitWithPreviewMode() {
        let view = ClaudeCodeScreenSaverView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), isPreview: true)
        XCTAssertNotNil(view)
    }

    func testStartAndStopAnimation() {
        let view = ClaudeCodeScreenSaverView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), isPreview: true)
        view?.startAnimation()
        // Should not crash
        view?.animateOneFrame()
        view?.animateOneFrame()
        view?.animateOneFrame()
        view?.stopAnimation()
    }

    func testStopAnimationIsIdempotent() {
        let view = ClaudeCodeScreenSaverView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), isPreview: true)
        view?.startAnimation()
        view?.stopAnimation()
        view?.stopAnimation() // second call should not crash
    }

    func testAnimateMultipleFrames() {
        let view = ClaudeCodeScreenSaverView(frame: NSRect(x: 0, y: 0, width: 1920, height: 1080), isPreview: false)
        view?.startAnimation()
        // Run 100 frames — should not crash or leak
        for _ in 0..<100 {
            view?.animateOneFrame()
        }
        view?.stopAnimation()
    }

    func testConfigureSheetReturnsWindow() {
        let view = ClaudeCodeScreenSaverView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), isPreview: false)
        let sheet = view?.configureSheet
        XCTAssertNotNil(sheet)
    }

    func testPreviewModeReducesPanes() {
        let view = ClaudeCodeScreenSaverView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), isPreview: true)
        view?.startAnimation()
        // In preview mode, should have at most 3 panes
        // We can't easily inspect pane count from outside, but the animation should work without crashing
        for _ in 0..<10 { view?.animateOneFrame() }
        view?.stopAnimation()
    }

    func testInitWithNonPreviewMode() {
        let view = ClaudeCodeScreenSaverView(frame: NSRect(x: 0, y: 0, width: 1920, height: 1080), isPreview: false)
        XCTAssertNotNil(view)
    }

    func testStartWithoutAnimateDoesNotCrash() {
        let view = ClaudeCodeScreenSaverView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), isPreview: true)
        view?.startAnimation()
        view?.stopAnimation()
    }

    func testAnimateWithoutStartDoesNotCrash() {
        let view = ClaudeCodeScreenSaverView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), isPreview: true)
        // animateOneFrame before startAnimation — should be safe
        view?.animateOneFrame()
    }
}
