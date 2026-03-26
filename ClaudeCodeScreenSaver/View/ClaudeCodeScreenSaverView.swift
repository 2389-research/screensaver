// ABOUTME: Visual prototype of the Claude Code screensaver, proving the CATextLayer approach.
// ABOUTME: Renders static tmux-style panes with Catppuccin Mocha colors and box-drawing borders.

import AppKit
import ScreenSaver

// MARK: - PaneContent

/// Describes the visual layout and content of a single tmux pane.
private struct PaneContent {
    let frame: CGRect
    let isActive: Bool
    let lines: [AttributedLine]
}

/// A single line of attributed text for rendering in a CATextLayer.
private struct AttributedLine {
    let text: NSAttributedString
}

// MARK: - ClaudeCodeScreenSaverView

/// Screen saver view demonstrating the per-line CATextLayer rendering approach.
/// Static prototype — no animation, just pixels proving the visual concept.
public class ClaudeCodeScreenSaverView: ScreenSaverView {

    // MARK: - Color Palette (Catppuccin Mocha)

    private enum Palette {
        static let base       = NSColor(hex: "#1e1e2e")  // Background
        static let mantle     = NSColor(hex: "#1e2030")  // Status bar
        static let border     = NSColor(hex: "#444444")  // Inactive pane borders
        static let activeBorder = NSColor(hex: "#00d7ff") // Active pane border (tmux colour51)
        static let prompt     = NSColor(hex: "#d4a574")  // User prompt (warm orange)
        static let response   = NSColor(hex: "#e0e0e0")  // Response text
        static let toolHeader = NSColor(hex: "#7aa2f7")  // Tool block headers (blue)
        static let dimText    = NSColor(hex: "#888888")  // Dimmed / secondary text
        static let statusText = NSColor(hex: "#c0c0c0")  // Status bar text
    }

    // MARK: - Constants

    private let menloFont: String = "Menlo"
    private let fontSize: CGFloat = 12.0
    private let statusBarHeight: CGFloat = 18.0

    // MARK: - Layer Tracking

    private var lineLayers: [CATextLayer] = []
    private var borderLayers: [CALayer] = []
    private var statusBarLayer: CALayer?

    // MARK: - Initialization

    public override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - Setup

    private func setup() {
        wantsLayer = true
        guard let root = self.layer else { return }

        root.backgroundColor = Palette.base.cgColor

        let contentHeight = bounds.height - statusBarHeight
        let panes = buildPaneLayout(in: CGRect(x: 0, y: statusBarHeight,
                                               width: bounds.width, height: contentHeight))

        for pane in panes {
            renderPane(pane, into: root)
        }

        addBorderLines(panes: panes, into: root)
        addStatusBar(into: root)
    }

    // MARK: - Pane Layout

    /// Builds a tmux-style dynamic layout — asymmetric split sizes, like a real session.
    private func buildPaneLayout(in area: CGRect) -> [PaneContent] {
        let w = area.width
        let h = area.height
        let x = area.minX
        let y = area.minY

        // Layout: left column (55%) | right column (45%), right col split top(60%)/bottom(40%)
        // Left column further split: top (65%) / bottom (35%)
        let leftW = floor(w * 0.55)
        let rightW = w - leftW

        let leftTopH = floor(h * 0.65)
        let leftBotH = h - leftTopH

        let rightTopH = floor(h * 0.60)
        let rightBotH = h - rightTopH

        let pane0 = CGRect(x: x, y: y + leftBotH, width: leftW, height: leftTopH)
        let pane1 = CGRect(x: x, y: y, width: leftW, height: leftBotH)
        let pane2 = CGRect(x: x + leftW, y: y + rightBotH, width: rightW, height: rightTopH)
        let pane3 = CGRect(x: x + leftW, y: y, width: rightW, height: rightBotH)

        return [
            PaneContent(frame: pane0, isActive: false, lines: pane0Lines()),
            PaneContent(frame: pane1, isActive: false, lines: pane1Lines()),
            PaneContent(frame: pane2, isActive: true,  lines: pane2Lines()),
            PaneContent(frame: pane3, isActive: false, lines: pane3Lines()),
        ]
    }

    // MARK: - Sample Content

    private func pane0Lines() -> [AttributedLine] {
        let font = font(size: fontSize)
        return [
            line("❯ build a REST API with Express", color: Palette.prompt, font: font, bold: true),
            line("", color: Palette.response, font: font),
            line("I'll help you build a REST API with Express. Let me", color: Palette.response, font: font),
            line("start by examining your project structure.", color: Palette.response, font: font),
            line("", color: Palette.response, font: font),
            line("╭─ Read ──────────────────────────────────────────╮", color: Palette.toolHeader, font: font),
            line("│ package.json                                     │", color: Palette.toolHeader, font: font),
            line("╰──────────────────────────────────────────────────╯", color: Palette.toolHeader, font: font),
            line("", color: Palette.response, font: font),
            line("{", color: Palette.dimText, font: font),
            line("  \"name\": \"my-api\",", color: Palette.dimText, font: font),
            line("  \"version\": \"1.0.0\",", color: Palette.dimText, font: font),
            line("  \"dependencies\": {}", color: Palette.dimText, font: font),
            line("}", color: Palette.dimText, font: font),
            line("", color: Palette.response, font: font),
            line("Now I'll install the required packages and create", color: Palette.response, font: font),
            line("the server scaffold.", color: Palette.response, font: font),
        ]
    }

    private func pane1Lines() -> [AttributedLine] {
        let font = font(size: fontSize)
        return [
            line("❯ fix the authentication bug in login.ts", color: Palette.prompt, font: font, bold: true),
            line("", color: Palette.response, font: font),
            line("╭─ Read ──────────────────────────────────────────╮", color: Palette.toolHeader, font: font),
            line("│ src/auth/login.ts                                │", color: Palette.toolHeader, font: font),
            line("╰──────────────────────────────────────────────────╯", color: Palette.toolHeader, font: font),
            line("", color: Palette.response, font: font),
            line("Found the bug: JWT secret is being compared with", color: Palette.response, font: font),
            line("=== instead of a constant-time comparison.", color: Palette.response, font: font),
        ]
    }

    private func pane2Lines() -> [AttributedLine] {
        let font = font(size: fontSize)
        return [
            line("❯ write unit tests for the payment module", color: Palette.prompt, font: font, bold: true),
            line("", color: Palette.response, font: font),
            line("I'll write comprehensive unit tests for the payment", color: Palette.response, font: font),
            line("module covering all edge cases.", color: Palette.response, font: font),
            line("", color: Palette.response, font: font),
            line("╭─ Write ─────────────────────────────────────────╮", color: Palette.toolHeader, font: font),
            line("│ tests/payment.test.ts                            │", color: Palette.toolHeader, font: font),
            line("╰──────────────────────────────────────────────────╯", color: Palette.toolHeader, font: font),
            line("", color: Palette.response, font: font),
            line("import { processPayment } from '../src/payment';", color: Palette.dimText, font: font),
            line("", color: Palette.response, font: font),
            line("describe('processPayment', () => {", color: Palette.dimText, font: font),
            line("  it('rejects invalid card numbers', async () => {", color: Palette.dimText, font: font),
            line("    await expect(processPayment({", color: Palette.dimText, font: font),
            line("      card: '0000-0000-0000-0000',", color: Palette.dimText, font: font),
            line("      amount: 100,", color: Palette.dimText, font: font),
            line("    })).rejects.toThrow('Invalid card');", color: Palette.dimText, font: font),
            line("  });", color: Palette.dimText, font: font),
        ]
    }

    private func pane3Lines() -> [AttributedLine] {
        let font = font(size: fontSize)
        return [
            line("❯ refactor the database schema", color: Palette.prompt, font: font, bold: true),
            line("", color: Palette.response, font: font),
            line("╭─ Bash ──────────────────────────────────────────╮", color: Palette.toolHeader, font: font),
            line("│ psql -c \"\\d users\"                              │", color: Palette.toolHeader, font: font),
            line("╰──────────────────────────────────────────────────╯", color: Palette.toolHeader, font: font),
            line("", color: Palette.response, font: font),
            line("  id         | bigserial | not null", color: Palette.dimText, font: font),
            line("  email      | varchar   | not null", color: Palette.dimText, font: font),
            line("  created_at | timestamp | not null", color: Palette.dimText, font: font),
        ]
    }

    // MARK: - Rendering

    private func renderPane(_ pane: PaneContent, into root: CALayer) {
        let paneLayer = CALayer()
        paneLayer.frame = pane.frame
        paneLayer.backgroundColor = Palette.base.cgColor
        paneLayer.borderWidth = 1.0
        paneLayer.borderColor = pane.isActive ? Palette.activeBorder.cgColor : Palette.border.cgColor
        root.addSublayer(paneLayer)

        let lineHeight = lineHeight(for: font(size: fontSize))
        let padding: CGFloat = 4.0
        var yOffset = pane.frame.height - lineHeight - padding

        for attributedLine in pane.lines {
            guard yOffset > 0 else { break }
            let textLayer = CATextLayer()
            textLayer.frame = CGRect(x: padding, y: yOffset,
                                     width: pane.frame.width - padding * 2, height: lineHeight)
            textLayer.string = attributedLine.text
            textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
            // Disable implicit animations so text updates don't cross-fade
            textLayer.actions = ["contents": NSNull(), "string": NSNull()]
            paneLayer.addSublayer(textLayer)
            lineLayers.append(textLayer)
            yOffset -= lineHeight
        }
    }

    private func addBorderLines(panes: [PaneContent], into root: CALayer) {
        // The CALayer.borderWidth on each pane already provides borders.
        // This is intentionally minimal — Task 1 validates the approach visually.
    }

    private func addStatusBar(into root: CALayer) {
        let barLayer = CALayer()
        barLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: statusBarHeight)
        barLayer.backgroundColor = Palette.mantle.cgColor
        root.addSublayer(barLayer)
        statusBarLayer = barLayer

        let font = font(size: fontSize - 1)
        let lh = lineHeight(for: font)
        let yOff = (statusBarHeight - lh) / 2.0

        // Left side: window list
        let leftText = makeStatusLeft()
        let leftLayer = CATextLayer()
        leftLayer.frame = CGRect(x: 4, y: yOff, width: bounds.width * 0.7, height: lh)
        leftLayer.string = leftText
        leftLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        leftLayer.actions = ["contents": NSNull(), "string": NSNull()]
        barLayer.addSublayer(leftLayer)

        // Right side: time
        let rightText = makeStatusRight()
        let rightLayer = CATextLayer()
        let rightWidth = bounds.width * 0.3
        rightLayer.frame = CGRect(x: bounds.width - rightWidth - 4, y: yOff,
                                  width: rightWidth, height: lh)
        rightLayer.string = rightText
        rightLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        rightLayer.actions = ["contents": NSNull(), "string": NSNull()]
        barLayer.addSublayer(rightLayer)
    }

    private func makeStatusLeft() -> NSAttributedString {
        let font = font(size: fontSize - 1)
        let text = "[rest-api] 0:claude*  1:claude-  2:claude  3:claude"
        return NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: Palette.statusText.cgColor,
        ])
    }

    private func makeStatusRight() -> NSAttributedString {
        let font = font(size: fontSize - 1)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm dd-MMM-yyyy"
        let timeString = formatter.string(from: Date())
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: Palette.statusText.cgColor,
            .paragraphStyle: {
                let ps = NSMutableParagraphStyle()
                ps.alignment = .right
                return ps
            }(),
        ]
        return NSAttributedString(string: timeString, attributes: attrs)
    }

    // MARK: - Font Helpers

    private func font(size: CGFloat, bold: Bool = false) -> NSFont {
        if bold, let f = NSFont(name: "\(menloFont)-Bold", size: size) { return f }
        if let f = NSFont(name: menloFont, size: size) { return f }
        return NSFont.monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    private func lineHeight(for font: NSFont) -> CGFloat {
        return ceil(font.ascender - font.descender + font.leading) + 2
    }

    // MARK: - Attributed String Builder

    private func line(_ text: String, color: NSColor, font: NSFont, bold: Bool = false) -> AttributedLine {
        let actualFont = bold ? self.font(size: font.pointSize, bold: true) : font
        let attrs: [NSAttributedString.Key: Any] = [
            .font: actualFont,
            .foregroundColor: color.cgColor,
        ]
        return AttributedLine(text: NSAttributedString(string: text, attributes: attrs))
    }

    // MARK: - ScreenSaverView

    public override var hasConfigureSheet: Bool { false }
    public override var configureSheet: NSWindow? { nil }

    public override func animateOneFrame() {
        // Static prototype — no animation needed for visual validation
    }
}
