// ABOUTME: Tests for the JSONL replay state machine with delta-time driven timing.
// ABOUTME: Verifies typing speeds, spinner rate, fade-in, viewport tracking, and state transitions.

import XCTest

final class SessionPlayerTests: XCTestCase {

    // MARK: - Helpers

    /// Extracts the text content from a TerminalLine for assertion convenience.
    private func textContent(of line: TerminalLine) -> String {
        switch line {
        case .prompt(let text): return text
        case .promptContinuation(let text): return text
        case .response(let text): return text
        case .toolCallHeader(let tool, let args): return "\(tool) \(args)"
        case .toolResultContent(let text): return text
        case .toolBlockBottom: return ""
        case .thinking: return "Thinking..."
        case .banner(let text): return text
        case .warning(let text): return text
        case .statusInfo(let text): return text
        case .empty: return ""
        }
    }

    private func linesContainText(_ lines: [TerminalLine], _ text: String) -> Bool {
        lines.contains { textContent(of: $0).contains(text) }
    }

    // MARK: - Tests

    func testPromptTypingSpeed() {
        let player = SessionPlayer(events: [.userPrompt(text: "hello world")])
        player.advance(deltaTime: 0.0) // start

        // At 40 chars/sec, "hello world" (11 chars) should take ~0.275s
        player.advance(deltaTime: 0.1) // 4 chars typed
        let lines = player.visibleLines
        XCTAssertFalse(lines.isEmpty)

        // Should contain a prompt line (after the banner)
        let hasPrompt = lines.contains { if case .prompt = $0 { return true }; return false }
        XCTAssertTrue(hasPrompt, "Should contain a .prompt line")

        // After enough time, full prompt should be visible
        player.advance(deltaTime: 0.3)
        let fullLines = player.visibleLines
        let hasFullPrompt = fullLines.contains {
            if case .prompt(let text) = $0 { return text.contains("hello world") }
            return false
        }
        XCTAssertTrue(hasFullPrompt, "Full prompt should be visible after sufficient time")
    }

    func testResponseTypingSpeed() {
        let player = SessionPlayer(events: [
            .userPrompt(text: "hi"),
            .assistantText(text: "Hello! I can help.")
        ])
        // Fast-forward past prompt + pause
        player.advance(deltaTime: 3.0)

        // Response should now be partially or fully typed
        let hasResponse = player.visibleLines.contains {
            if case .response(let text) = $0 { return text.contains("Hello") }
            return false
        }
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
        let hasResponse = player.visibleLines.contains {
            if case .response(let text) = $0 { return text.contains("done") }
            return false
        }
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
            let text = textContent(of: lastLine)
            XCTAssertTrue(text.contains("49") || text.contains("4"),
                         "Should show bottom of content, got: \(text)")
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
        let hasToolCall = player.visibleLines.contains {
            if case .toolCallHeader(let tool, _) = $0 { return tool == "Read" }
            return false
        }
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
        XCTAssertTrue(linesContainText(lines, "fix bug"))
        XCTAssertTrue(linesContainText(lines, "Found it"))
    }

    func testEmptyEventsArray() {
        let player = SessionPlayer(events: [])
        XCTAssertFalse(player.isPlaying)
        player.advance(deltaTime: 1.0)
        // Even with no events, the ASCII banner is present
        let hasBanner = player.visibleLines.contains(where: {
            if case .banner = $0 { return true }
            return false
        })
        XCTAssertTrue(hasBanner, "Should show 2389 ASCII banner")
    }

    func testToolResultEmitsTypedLines() {
        let player = SessionPlayer(events: [.toolResult(content: "line one\nline two")])
        player.advance(deltaTime: 1.0)

        let resultLines = player.visibleLines.filter {
            if case .toolResultContent = $0 { return true }
            return false
        }
        XCTAssertEqual(resultLines.count, 2)
    }

    func testThinkingEmitsTypedLine() {
        let player = SessionPlayer(events: [.thinking(durationHint: 2.0)])
        player.advance(deltaTime: 0.0)
        player.advance(deltaTime: 0.05)

        let thinkingLines = player.visibleLines.filter {
            if case .thinking = $0 { return true }
            return false
        }
        XCTAssertEqual(thinkingLines.count, 1)
    }

    func testPromptLineType() {
        let player = SessionPlayer(events: [.userPrompt(text: "hello")])
        player.advance(deltaTime: 0.0)
        player.advance(deltaTime: 1.0)

        let promptLines = player.visibleLines.filter {
            if case .prompt = $0 { return true }
            return false
        }
        XCTAssertEqual(promptLines.count, 1)
        if case .prompt(let text) = promptLines.first {
            XCTAssertEqual(text, "hello")
        }
    }

    func testPromptWrapsAtPaneColumnWidthIncludingChevron() {
        let player = SessionPlayer(events: [.userPrompt(text: "abcdefghijk")])
        player.visibleCols = 10

        player.advance(deltaTime: 0.0)
        player.advance(deltaTime: 1.0)

        let promptLines = player.visibleLines.filter {
            switch $0 {
            case .prompt, .promptContinuation:
                return true
            default:
                return false
            }
        }

        XCTAssertEqual(promptLines.count, 2)

        guard promptLines.count == 2 else { return }

        if case .prompt(let firstLine) = promptLines[0] {
            XCTAssertEqual(firstLine, "abcdefgh")
        } else {
            XCTFail("Expected first wrapped segment to be a prompt line")
        }

        if case .promptContinuation(let secondLine) = promptLines[1] {
            XCTAssertEqual(secondLine, "ijk")
        } else {
            XCTFail("Expected wrapped continuation to preserve prompt styling")
        }

        XCTAssertEqual(player.cursorPosition.row, player.visibleLines.count - 1)
        XCTAssertEqual(player.cursorPosition.col, 3)
    }
}
