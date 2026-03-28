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
    var visibleCols: Int = 80
    var currentSessionFileName: String?

    private(set) var currentSpinnerFrame: Int = 0
    private(set) var currentToolResultOpacity: Double = 0.0

    var cursorPosition: (row: Int, col: Int) {
        let row = allLines.count - 1
        let col: Int
        switch allLines.last {
        case .prompt(let text): col = text.count + 2
        case .promptContinuation(let text): col = text.count
        case .response(let text): col = text.count
        case .toolCallHeader(let tool, let args): col = tool.count + args.count + 4
        case .toolResultContent(let text): col = text.count + 2
        case .toolBlockBottom(let width): col = width
        case .thinking: col = 13
        case .banner(let text): col = text.count
        case .warning(let text): col = text.count
        case .statusInfo(let text): col = text.count
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

    // Insane model names for the status line
    private static let modelNames = [
        "claude-opus-9-20261225", "claude-sonnet-7.3-turbo", "claude-haiku-5-ultra",
        "gpt-5.4-preview-2026", "gemini-2.5-flash-thinking", "claude-opus-4.6-1m",
        "deepseek-r3-0401", "claude-mega-10-exp", "gpt-6-mini-preview",
        "llama-5-405b-instruct", "claude-sonnet-4.6-fast", "mistral-large-3-2026",
        "claude-opus-4.6[1m]", "gpt-5.4-0125", "claude-3.7-sonnet-thinking",
    ]

    // Block-font ASCII banner shown before session content starts
    private static let asciiBanner: [TerminalLine] = [
        .empty,
        .banner(text: "\u{2591}\u{2592}\u{2593}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2593}\u{2592}\u{2591}\u{2591}\u{2592}\u{2593}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2593}\u{2592}\u{2591} \u{2591}\u{2592}\u{2593}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2593}\u{2592}\u{2591} \u{2591}\u{2592}\u{2593}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2593}\u{2592}\u{2591}"),
        .banner(text: "       \u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}      \u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}\u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}\u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}\u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}\u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}"),
        .banner(text: "       \u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}      \u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}\u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}\u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}\u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}\u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}"),
        .banner(text: " \u{2591}\u{2592}\u{2593}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2593}\u{2592}\u{2591}\u{2591}\u{2592}\u{2593}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2593}\u{2592}\u{2591} \u{2591}\u{2592}\u{2593}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2593}\u{2592}\u{2591} \u{2591}\u{2592}\u{2593}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2593}\u{2592}\u{2591}"),
        .banner(text: "\u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}             \u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}\u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}\u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}      \u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}"),
        .banner(text: "\u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}             \u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}\u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}\u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}      \u{2591}\u{2592}\u{2593}\u{2588}\u{2593}\u{2592}\u{2591}"),
        .banner(text: "\u{2591}\u{2592}\u{2593}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2593}\u{2592}\u{2591}\u{2591}\u{2592}\u{2593}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2593}\u{2592}\u{2591} \u{2591}\u{2592}\u{2593}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2593}\u{2592}\u{2591} \u{2591}\u{2592}\u{2593}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2593}\u{2592}\u{2591}"),
        .empty,
        .banner(text: "                      2389.ai"),
        .empty,
    ]

    // Fake project names for the status bar
    private static let projectNames = [
        "my-saas-app", "api-gateway", "neural-search", "billing-service",
        "data-pipeline", "auth-service", "ml-inference", "web-dashboard",
        "event-broker", "config-manager", "log-aggregator", "feature-flags",
    ]

    private static let branchNames = [
        "main", "feat/add-auth", "fix/memory-leak", "refactor/db-schema",
        "feat/websocket", "fix/timeout", "chore/deps", "feat/search",
    ]

    // Generate a status line matching real Code Agent format
    private static func generateStatusLine() -> [TerminalLine] {
        let model = modelNames.randomElement() ?? "claude-opus-4.6"
        let project = projectNames.randomElement() ?? "project"
        let branch = branchNames.randomElement() ?? "main"
        let contextPct = Int.random(in: 15...92)
        let sessionMin = Int.random(in: 2...180)
        let sessionSec = Int.random(in: 0...59)
        let costCents = Int.random(in: 5...999)
        let costStr = String(format: "$%d.%02d", costCents / 100, costCents % 100)

        // Format like: [Opus 4.6 (1M context)] project | branch | ██░░ 44% | ⏱ 50m 26s | $0.47
        let contextBar = String(repeating: "\u{2588}", count: contextPct / 10) + String(repeating: "\u{2591}", count: 10 - contextPct / 10)
        let statusText = "[\(model)]  \(project) | \(branch) | \(contextBar) \(contextPct)% | \(sessionMin)m \(sessionSec)s | \(costStr)"

        return [
            .statusInfo(text: statusText),
            .warning(text: "\u{25B6}\u{25B6} bypass permissions on (shift+tab to cycle)"),
            .empty,
        ]
    }

    init(events: [SessionEvent]) {
        self.events = events
        // Start with ASCII banner + status line
        let bannerAndStatus = Self.asciiBanner + Self.generateStatusLine()
        self.allLines = bannerAndStatus
        // New content starts after the banner, not at line 0
        self.currentEventLineStart = bannerAndStatus.count
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

    private func wrapLine(_ line: String, firstLineWidth: Int? = nil, continuationWidth: Int? = nil) -> [String] {
        guard visibleCols > 0 else { return [line] }

        let initialWidth = max(firstLineWidth ?? visibleCols, 1)
        let wrappedLineWidth = max(continuationWidth ?? visibleCols, 1)
        guard line.count > initialWidth else { return [line] }

        var result: [String] = []
        var remaining = line

        let firstBreakIndex = remaining.index(remaining.startIndex, offsetBy: initialWidth)
        result.append(String(remaining[remaining.startIndex..<firstBreakIndex]))
        remaining = String(remaining[firstBreakIndex...])

        while remaining.count > wrappedLineWidth {
            let breakIndex = remaining.index(remaining.startIndex, offsetBy: wrappedLineWidth)
            result.append(String(remaining[remaining.startIndex..<breakIndex]))
            remaining = String(remaining[breakIndex...])
        }
        if !remaining.isEmpty { result.append(remaining) }
        return result
    }

    private func updateLinesForTyping(text: String) {
        let rawLines = text.components(separatedBy: "\n")
        // Wrap long lines at approximate column width
        var typedLines: [TerminalLine] = []
        for (index, rawLine) in rawLines.enumerated() {
            let wrapped: [String]
            switch currentTypingMode {
            case .prompt:
                let firstWidth = index == 0 ? visibleCols - 2 : visibleCols
                wrapped = wrapLine(rawLine, firstLineWidth: firstWidth)
            default:
                wrapped = wrapLine(rawLine)
            }
            for (wrapIdx, segment) in wrapped.enumerated() {
                let line: TerminalLine
                switch currentTypingMode {
                case .prompt:
                    line = (index == 0 && wrapIdx == 0) ? .prompt(text: segment) : .promptContinuation(text: segment)
                case .response:
                    line = .response(text: segment)
                case .toolCall(let tool, let args):
                    line = (index == 0 && wrapIdx == 0) ? .toolCallHeader(tool: tool, args: args) : .response(text: segment)
                }
                typedLines.append(line)
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
