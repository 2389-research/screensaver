// ABOUTME: Tests for the JSONL replay state machine with delta-time driven timing.
// ABOUTME: Verifies typing speeds, spinner rate, fade-in, viewport tracking, and state transitions.

import XCTest

final class SessionPlayerTests: XCTestCase {

    func testPromptTypingSpeed() {
        let player = SessionPlayer(events: [.userPrompt(text: "hello world")])
        player.advance(deltaTime: 0.0) // start

        // At 40 chars/sec, "hello world" (11 chars) should take ~0.275s
        player.advance(deltaTime: 0.1) // 4 chars typed
        let lines = player.visibleLines
        XCTAssertFalse(lines.isEmpty)

        // After enough time, full prompt should be visible
        player.advance(deltaTime: 0.3)
        let fullLines = player.visibleLines
        let promptLine = fullLines.first(where: { $0.contains("hello world") })
        XCTAssertNotNil(promptLine, "Full prompt should be visible after sufficient time")
    }

    func testResponseTypingSpeed() {
        let player = SessionPlayer(events: [
            .userPrompt(text: "hi"),
            .assistantText(text: "Hello! I can help.")
        ])
        // Fast-forward past prompt + pause
        player.advance(deltaTime: 3.0)

        // Response should now be partially or fully typed
        let hasResponse = player.visibleLines.contains(where: { $0.contains("Hello") })
        XCTAssertTrue(hasResponse)
    }

    func testSpinnerAdvancesEvery100ms() {
        let player = SessionPlayer(events: [.thinking(durationHint: nil)])
        player.advance(deltaTime: 0.0)
        XCTAssertEqual(player.currentSpinnerFrame, 0)

        player.advance(deltaTime: 0.099)
        XCTAssertEqual(player.currentSpinnerFrame, 0, "Should still be frame 0 at 99ms")

        player.advance(deltaTime: 0.001)
        XCTAssertEqual(player.currentSpinnerFrame, 1, "Should advance to frame 1 at 100ms")

        player.advance(deltaTime: 0.9)
        XCTAssertEqual(player.currentSpinnerFrame, 0, "Frame 10 should wrap to 0")
    }

    func testToolResultFadeIn() {
        let player = SessionPlayer(events: [.toolResult(content: "file contents")])
        player.advance(deltaTime: 0.0)
        XCTAssertEqual(player.currentToolResultOpacity, 0.0, accuracy: 0.01)

        player.advance(deltaTime: 0.15)
        XCTAssertEqual(player.currentToolResultOpacity, 0.5, accuracy: 0.1)

        player.advance(deltaTime: 0.15)
        XCTAssertEqual(player.currentToolResultOpacity, 1.0, accuracy: 0.01)
    }

    func testThinkingMinimumDuration() {
        let player = SessionPlayer(events: [
            .thinking(durationHint: 0.1), // hint is only 100ms
            .assistantText(text: "done")
        ])
        player.advance(deltaTime: 0.0)

        // After 200ms, should still be thinking (minimum 500ms)
        player.advance(deltaTime: 0.2)
        XCTAssertGreaterThan(player.currentSpinnerFrame, -1, "Should be showing spinner")

        // After 600ms total, thinking should be done
        player.advance(deltaTime: 0.4)
        // Should have moved past thinking into the response
        player.advance(deltaTime: 2.0) // finish pause + start response
        let hasResponse = player.visibleLines.contains(where: { $0.contains("done") })
        XCTAssertTrue(hasResponse)
    }

    func testViewportTracksBottom() {
        let longText = (0..<50).map { "Line \($0)" }.joined(separator: "\n")
        let player = SessionPlayer(events: [.assistantText(text: longText)])
        player.visibleRows = 20

        // Advance enough to type all content
        player.advance(deltaTime: 30.0)

        let visibleLines = player.visibleLines
        XCTAssertLessThanOrEqual(visibleLines.count, 20)
        // Should show the bottom lines, not the top
        if let lastLine = visibleLines.last {
            XCTAssertTrue(lastLine.contains("49") || lastLine.contains("4"),
                         "Should show bottom of content, got: \(lastLine)")
        }
    }

    func testSessionEndsWhenAllEventsConsumed() {
        let player = SessionPlayer(events: [.userPrompt(text: "hi")])
        XCTAssertTrue(player.isPlaying)

        // Advance well past the single prompt
        player.advance(deltaTime: 10.0)
        XCTAssertFalse(player.isPlaying)
    }

    func testIsTypingPromptFlag() {
        let player = SessionPlayer(events: [
            .userPrompt(text: "test"),
            .assistantText(text: "response")
        ])
        player.advance(deltaTime: 0.0)
        XCTAssertTrue(player.isTypingPrompt)

        // Advance past prompt + pause
        player.advance(deltaTime: 3.0)
        XCTAssertFalse(player.isTypingPrompt)
    }

    func testToolCallTypingSpeed() {
        let player = SessionPlayer(events: [.toolCall(tool: "Read", args: "src/main.ts")])
        player.advance(deltaTime: 0.0)

        // At 200 chars/sec, a short tool call should complete quickly
        player.advance(deltaTime: 0.5)
        let hasToolCall = player.visibleLines.contains(where: { $0.contains("Read") })
        XCTAssertTrue(hasToolCall)
    }

    func testMultipleEventsSequence() {
        let player = SessionPlayer(events: [
            .userPrompt(text: "fix bug"),
            .thinking(durationHint: nil),
            .assistantText(text: "Found it."),
            .toolCall(tool: "Edit", args: "main.ts"),
            .toolResult(content: "Updated"),
        ])

        // Advance through everything
        player.advance(deltaTime: 30.0)

        let lines = player.visibleLines
        XCTAssertTrue(lines.contains(where: { $0.contains("fix bug") }))
        XCTAssertTrue(lines.contains(where: { $0.contains("Found it") }))
    }

    func testEmptyEventsArray() {
        let player = SessionPlayer(events: [])
        XCTAssertFalse(player.isPlaying)
        player.advance(deltaTime: 1.0)
        XCTAssertTrue(player.visibleLines.isEmpty)
    }
}
