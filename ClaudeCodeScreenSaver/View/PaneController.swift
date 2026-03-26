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

    init(layout: PaneLayout, theme: ThemeColors, events: [SessionEvent], sessionFileName: String, scale: CGFloat = 2.0) {
        self.layout = layout
        self.sessionFileName = sessionFileName
        self.renderer = TerminalRenderer(frame: layout.frame, theme: theme, scale: scale)
        self.player = SessionPlayer(events: events)
        self.player.visibleRows = renderer.fontMetrics.rows
        self.player.currentSessionFileName = sessionFileName

        let font = renderer.fontMetrics.font
        self.stringBuilder = AttributedStringBuilder(theme: theme, font: font)
    }

    func advance(deltaTime: TimeInterval) {
        player.advance(deltaTime: deltaTime)

        let lines = player.visibleLines.map { convertLine($0) }
        let cursor = player.cursorPosition
        renderer.update(lines: lines, cursorPosition: cursor, deltaTime: deltaTime)
    }

    func assignSession(events: [SessionEvent], fileName: String) {
        player = SessionPlayer(events: events)
        player.visibleRows = renderer.fontMetrics.rows
        player.currentSessionFileName = fileName
    }

    // MARK: - Private

    private func convertLine(_ text: String) -> NSAttributedString {
        // Detect line type from content and use the appropriate builder method
        if text.hasPrefix("> ") {
            return stringBuilder.promptLine(text: String(text.dropFirst(2)))
        } else if text.hasPrefix("\u{256D}\u{2500}") {
            // Tool call header line (box-drawing top)
            return NSAttributedString(
                string: text,
                attributes: [.font: stringBuilder.nsFont,
                             .foregroundColor: stringBuilder.colorToolName]
            )
        } else if text.hasPrefix("\u{2502} ") {
            return stringBuilder.toolResultLine(text: String(text.dropFirst(2)))
        } else if text.hasPrefix("\u{2570}") {
            // Tool block bottom
            return NSAttributedString(
                string: text,
                attributes: [.font: stringBuilder.nsFont,
                             .foregroundColor: stringBuilder.colorToolBorder]
            )
        } else {
            return stringBuilder.responseLine(text: text)
        }
    }
}
