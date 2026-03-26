// ABOUTME: State machine that replays parsed SessionEvent arrays into typed TerminalLine output.
// ABOUTME: Uses delta-time accumulators for realistic typing, spinner, and fade-in timing.

import Foundation

final class SessionPlayer {

    // MARK: - State enum

    enum State {
        case idle
        case typingPrompt(charIndex: Int, elapsed: TimeInterval)
        case thinking(elapsed: TimeInterval, spinnerElapsed: TimeInterval)
        case typingResponse(charIndex: Int, elapsed: TimeInterval)
        case typingToolCall(charIndex: Int, elapsed: TimeInterval)
        case toolResult(fadeElapsed: TimeInterval)
        case pausing(elapsed: TimeInterval)
        case finished
    }

    // MARK: - Typing mode (determines what kind of TerminalLine to emit)

    private enum TypingMode {
        case prompt
        case response
        case toolCall(tool: String, args: String)
    }

    // MARK: - Timing constants

    private static let promptCharsPerSec: Double = 40.0
    private static let responseCharsPerSec: Double = 60.0
    private static let toolCallCharsPerSec: Double = 200.0
    private static let toolResultFadeDuration: TimeInterval = 0.3
    private static let spinnerFrameInterval: TimeInterval = 0.1
    private static let spinnerFrameCount: Int = 10
    private static let thinkingMinDuration: TimeInterval = 0.5

    // MARK: - Public properties

    var visibleRows: Int = 50
    var currentSessionFileName: String?

    private(set) var currentSpinnerFrame: Int = 0
    private(set) var currentToolResultOpacity: Double = 0.0

    var cursorPosition: (row: Int, col: Int) {
        let row = allLines.count - 1
        let col: Int
        switch allLines.last {
        case .prompt(let text): col = text.count + 2
        case .response(let text): col = text.count
        case .toolCallHeader(let tool, let args): col = tool.count + args.count + 4
        case .toolResultContent(let text): col = text.count + 2
        case .toolBlockBottom(let width): col = width
        case .thinking: col = 13
        case .empty, .none: col = 0
        }
        return (row: max(row, 0), col: col)
    }

    var visibleLines: [TerminalLine] {
        let lines = allLines
        if lines.count <= visibleRows {
            return lines
        }
        return Array(lines.suffix(visibleRows))
    }

    var isPlaying: Bool {
        if events.isEmpty { return false }
        switch state {
        case .finished:
            return false
        default:
            return true
        }
    }

    var isTypingPrompt: Bool {
        switch state {
        case .typingPrompt:
            return true
        default:
            return false
        }
    }

    // MARK: - Private state

    private let events: [SessionEvent]
    private var eventIndex: Int = 0
    private var state: State = .idle
    private var allLines: [TerminalLine] = []
    private var thinkingTargetDuration: TimeInterval = 0
    private var pauseTargetDuration: TimeInterval = 0
    private var currentEventText: String = ""
    private var currentTypingMode: TypingMode = .response

    // MARK: - Init

    init(events: [SessionEvent]) {
        self.events = events
        if events.isEmpty {
            state = .finished
        }
    }

    // MARK: - Advance

    func advance(deltaTime: TimeInterval) {
        guard isPlaying else { return }
        var remaining = deltaTime
        // Always do at least one tick so advance(deltaTime: 0.0) can transition from idle
        var firstPass = true
        while (remaining > 0 || firstPass) && isPlaying {
            firstPass = false
            let leftover = tick(remaining)
            if leftover == remaining && remaining == 0 {
                // No progress was made with zero time; avoid infinite loop
                break
            }
            remaining = leftover
        }
    }

    // MARK: - Core tick logic

    /// Processes one step with the given delta time.
    /// Returns remaining time (>0 means state transitioned and caller should continue).
    private func tick(_ dt: TimeInterval) -> TimeInterval {
        switch state {
        case .idle:
            return startNextEvent(dt)

        case .typingPrompt(let charIndex, let elapsed):
            return tickTyping(
                dt: dt, charIndex: charIndex, elapsed: elapsed,
                charsPerSec: Self.promptCharsPerSec,
                nextStateBuilder: { .typingPrompt(charIndex: $0, elapsed: $1) }
            )

        case .thinking(let elapsed, let spinnerElapsed):
            return tickThinking(dt: dt, elapsed: elapsed, spinnerElapsed: spinnerElapsed)

        case .typingResponse(let charIndex, let elapsed):
            return tickTyping(
                dt: dt, charIndex: charIndex, elapsed: elapsed,
                charsPerSec: Self.responseCharsPerSec,
                nextStateBuilder: { .typingResponse(charIndex: $0, elapsed: $1) }
            )

        case .typingToolCall(let charIndex, let elapsed):
            return tickTyping(
                dt: dt, charIndex: charIndex, elapsed: elapsed,
                charsPerSec: Self.toolCallCharsPerSec,
                nextStateBuilder: { .typingToolCall(charIndex: $0, elapsed: $1) }
            )

        case .toolResult(let fadeElapsed):
            return tickToolResult(dt: dt, fadeElapsed: fadeElapsed)

        case .pausing(let elapsed):
            return tickPause(dt: dt, elapsed: elapsed)

        case .finished:
            return 0
        }
    }

    // MARK: - State handlers

    private func startNextEvent(_ dt: TimeInterval) -> TimeInterval {
        guard eventIndex < events.count else {
            state = .finished
            return 0
        }

        let event = events[eventIndex]
        switch event {
        case .userPrompt(let text):
            currentEventText = text
            currentTypingMode = .prompt
            state = .typingPrompt(charIndex: 0, elapsed: 0)

        case .assistantText(let text):
            currentEventText = text
            currentTypingMode = .response
            state = .typingResponse(charIndex: 0, elapsed: 0)

        case .toolCall(let tool, let args):
            currentEventText = "\(tool) \(args)"
            currentTypingMode = .toolCall(tool: tool, args: args)
            state = .typingToolCall(charIndex: 0, elapsed: 0)

        case .toolResult(let content):
            currentEventText = content
            currentToolResultOpacity = 0.0
            state = .toolResult(fadeElapsed: 0)

        case .thinking(let durationHint):
            let maxDuration = TimeInterval.random(in: 2.0...4.0)
            let hintDuration = durationHint ?? maxDuration
            let clamped = min(hintDuration, maxDuration)
            thinkingTargetDuration = max(clamped, Self.thinkingMinDuration)
            currentSpinnerFrame = 0
            updateThinkingLine()
            state = .thinking(elapsed: 0, spinnerElapsed: 0)
        }

        return dt // pass full dt to new state
    }

    private func tickTyping(
        dt: TimeInterval,
        charIndex: Int,
        elapsed: TimeInterval,
        charsPerSec: Double,
        nextStateBuilder: (Int, TimeInterval) -> State
    ) -> TimeInterval {
        let newElapsed = elapsed + dt
        let targetChars = Int(newElapsed * charsPerSec)
        let totalChars = currentEventText.count

        let newCharIndex = min(targetChars, totalChars)

        // Update visible lines with currently typed text
        let typedText = String(currentEventText.prefix(newCharIndex))
        updateLinesForTyping(text: typedText)

        if newCharIndex >= totalChars {
            // Typing complete, finalize with full text
            updateLinesForTyping(text: currentEventText)
            let timeUsed = Double(totalChars) / charsPerSec
            let surplus = newElapsed - timeUsed
            eventIndex += 1
            transitionToPause()
            return max(surplus, 0)
        }

        state = nextStateBuilder(newCharIndex, newElapsed)
        return 0
    }

    private func tickThinking(dt: TimeInterval, elapsed: TimeInterval, spinnerElapsed: TimeInterval) -> TimeInterval {
        let newElapsed = elapsed + dt
        let newSpinnerElapsed = spinnerElapsed + dt

        // Update spinner frame
        let frameIndex = Int(newSpinnerElapsed / Self.spinnerFrameInterval) % Self.spinnerFrameCount
        currentSpinnerFrame = frameIndex
        updateThinkingLine()

        if newElapsed >= thinkingTargetDuration {
            let surplus = newElapsed - thinkingTargetDuration
            eventIndex += 1
            transitionToPause()
            return max(surplus, 0)
        }

        state = .thinking(elapsed: newElapsed, spinnerElapsed: newSpinnerElapsed)
        return 0
    }

    private func tickToolResult(dt: TimeInterval, fadeElapsed: TimeInterval) -> TimeInterval {
        let newFadeElapsed = fadeElapsed + dt

        currentToolResultOpacity = min(newFadeElapsed / Self.toolResultFadeDuration, 1.0)

        // Add tool result lines to output
        updateLinesForToolResult(text: currentEventText)

        if newFadeElapsed >= Self.toolResultFadeDuration {
            currentToolResultOpacity = 1.0
            let surplus = newFadeElapsed - Self.toolResultFadeDuration
            eventIndex += 1
            transitionToPause()
            return max(surplus, 0)
        }

        state = .toolResult(fadeElapsed: newFadeElapsed)
        return 0
    }

    private func tickPause(dt: TimeInterval, elapsed: TimeInterval) -> TimeInterval {
        let newElapsed = elapsed + dt

        if newElapsed >= pauseTargetDuration {
            let surplus = newElapsed - pauseTargetDuration
            state = .idle
            return max(surplus, 0)
        }

        state = .pausing(elapsed: newElapsed)
        return 0
    }

    // MARK: - Line management

    /// Tracks the line index where the current event's output starts in allLines.
    private var currentEventLineStart: Int = 0

    private func transitionToPause() {
        if eventIndex >= events.count {
            state = .finished
        } else {
            pauseTargetDuration = TimeInterval.random(in: 0.5...2.0)
            state = .pausing(elapsed: 0)
        }
        // Mark where the next event will start writing
        currentEventLineStart = allLines.count
    }

    private func updateLinesForTyping(text: String) {
        let rawLines = text.components(separatedBy: "\n")
        let typedLines: [TerminalLine] = rawLines.enumerated().map { index, line in
            switch currentTypingMode {
            case .prompt:
                return index == 0 ? .prompt(text: line) : .response(text: line)
            case .response:
                return .response(text: line)
            case .toolCall(let tool, let args):
                return index == 0 ? .toolCallHeader(tool: tool, args: args) : .response(text: line)
            }
        }

        // Replace lines from currentEventLineStart onwards
        let endIndex = currentEventLineStart + typedLines.count
        if allLines.count < endIndex {
            // Expand allLines
            while allLines.count < currentEventLineStart {
                allLines.append(.empty)
            }
            // Replace existing + append new
            for (i, line) in typedLines.enumerated() {
                let targetIndex = currentEventLineStart + i
                if targetIndex < allLines.count {
                    allLines[targetIndex] = line
                } else {
                    allLines.append(line)
                }
            }
        } else {
            for (i, line) in typedLines.enumerated() {
                allLines[currentEventLineStart + i] = line
            }
        }
    }

    private func updateLinesForToolResult(text: String) {
        let lines = text.components(separatedBy: "\n")

        while allLines.count < currentEventLineStart {
            allLines.append(.empty)
        }
        for (i, line) in lines.enumerated() {
            let targetIndex = currentEventLineStart + i
            let typedLine = TerminalLine.toolResultContent(text: line)
            if targetIndex < allLines.count {
                allLines[targetIndex] = typedLine
            } else {
                allLines.append(typedLine)
            }
        }
    }

    private func updateThinkingLine() {
        let line = TerminalLine.thinking(frameIndex: currentSpinnerFrame)
        while allLines.count < currentEventLineStart {
            allLines.append(.empty)
        }
        if currentEventLineStart < allLines.count {
            allLines[currentEventLineStart] = line
        } else {
            allLines.append(line)
        }
    }
}
