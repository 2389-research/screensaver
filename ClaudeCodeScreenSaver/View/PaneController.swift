// ABOUTME: Owns the TerminalRenderer, SessionPlayer, and AttributedStringBuilder for one pane.
// ABOUTME: Bridges the session state machine to the visual rendering layer per pane.

import AppKit
import CoreText

class PaneController {

    let layout: PaneLayout
    let renderer: TerminalRenderer
    let sessionFileName: String

    var isTypingPrompt: Bool { player.isTypingPrompt }
    var isPlaying: Bool { player.isPlaying }

    private var player: SessionPlayer
    private let stringBuilder: AttributedStringBuilder
    private var previousLines: [TerminalLine] = []
    private var previousAttributed: [NSAttributedString] = []

    init(layout: PaneLayout, theme: ThemeColors, events: [SessionEvent], sessionFileName: String, scale: CGFloat = 2.0) {
        self.layout = layout
        self.sessionFileName = sessionFileName
        self.renderer = TerminalRenderer(frame: layout.frame, theme: theme, scale: scale)
        self.player = SessionPlayer(events: events)
        self.player.visibleRows = renderer.fontMetrics.rows
        self.player.visibleCols = renderer.fontMetrics.cols
        self.player.currentSessionFileName = sessionFileName

        let font = renderer.fontMetrics.font
        self.stringBuilder = AttributedStringBuilder(theme: theme, font: font)
    }

    func advance(deltaTime: TimeInterval) {
        player.advance(deltaTime: deltaTime)

        let newLines = player.visibleLines
        var attributedLines: [NSAttributedString] = []
        for (i, line) in newLines.enumerated() {
            if i < previousLines.count && previousLines[i] == line {
                attributedLines.append(previousAttributed[i])
            } else {
                attributedLines.append(convertLine(line))
            }
        }
        previousLines = newLines
        previousAttributed = attributedLines

        let cursor = player.cursorPosition
        renderer.update(lines: attributedLines, cursorPosition: cursor, deltaTime: deltaTime)
    }

    func assignSession(events: [SessionEvent], fileName: String) {
        player = SessionPlayer(events: events)
        player.visibleRows = renderer.fontMetrics.rows
        player.visibleCols = renderer.fontMetrics.cols
        player.currentSessionFileName = fileName
        previousLines = []
        previousAttributed = []
    }

    // MARK: - Private

    private func convertLine(_ line: TerminalLine) -> NSAttributedString {
        switch line {
        case .prompt(let text):
            return stringBuilder.promptLine(text: text)
        case .response(let text):
            return stringBuilder.responseLine(text: text)
        case .toolCallHeader(let tool, let args):
            return stringBuilder.toolCallHeader(tool: tool, args: args)
        case .toolResultContent(let text):
            return stringBuilder.toolResultLine(text: text)
        case .toolBlockBottom(let width):
            return stringBuilder.toolBlockBottom(width: width)
        case .thinking(let frameIndex):
            return stringBuilder.thinkingLine(frameIndex: frameIndex)
        case .banner(let text):
            return stringBuilder.bannerLine(text: text)
        case .warning(let text):
            return stringBuilder.warningLine(text: text)
        case .statusInfo(let text):
            return stringBuilder.statusInfoLine(text: text)
        case .empty:
            return stringBuilder.responseLine(text: "")
        }
    }
}
