// ABOUTME: Renders terminal content as a grid of per-line CATextLayer instances.
// ABOUTME: Manages cursor overlay, dirty-line tracking, viewport bottom-tracking, and a fixed footer.

import AppKit
import QuartzCore
import CoreText

class TerminalRenderer {
    let containerLayer: CALayer
    private(set) var lineLayers: [CATextLayer] = []
    let cursorLayer: CALayer
    let fontMetrics: FontMetrics
    private let theme: ThemeColors

    // Fixed footer layers (status line + warning) — always at the bottom, never scroll
    private let footerStatusLayer: CATextLayer
    private let footerWarningLayer: CATextLayer
    private static let footerLineCount = 2

    // Number of rows available for scrolling content (total rows minus footer)
    var contentRows: Int { fontMetrics.rows - Self.footerLineCount }

    private var previousLines: [String] = []
    private var previousLineMapping: [String] = []
    private var cursorBlinkAccumulator: TimeInterval = 0
    private var cursorVisible = true
    private let cursorBlinkHalfPeriod: TimeInterval = 0.530

    init(frame: CGRect, theme: ThemeColors, scale: CGFloat = 2.0) {
        self.theme = theme
        self.fontMetrics = FontMetrics.compute(for: frame)
        self.containerLayer = CALayer()
        containerLayer.frame = frame
        containerLayer.backgroundColor = NSColor(hex: theme.background).cgColor

        let contentRowCount = fontMetrics.rows - Self.footerLineCount

        // Create per-line text layers for scrolling content (row 0 at top)
        for row in 0..<contentRowCount {
            let lineLayer = CATextLayer()
            let yFromTop = CGFloat(row) * fontMetrics.lineHeight
            let yFlipped = frame.height - yFromTop - fontMetrics.lineHeight
            lineLayer.frame = CGRect(
                x: 0,
                y: yFlipped,
                width: frame.width,
                height: fontMetrics.lineHeight
            )
            lineLayer.contentsScale = scale
            lineLayer.font = fontMetrics.font
            lineLayer.fontSize = fontMetrics.fontSize
            lineLayer.isWrapped = false
            lineLayer.truncationMode = .end
            lineLayer.actions = ["contents": NSNull(), "string": NSNull()]
            containerLayer.addSublayer(lineLayer)
            lineLayers.append(lineLayer)
        }

        // Create fixed footer layers at the very bottom of the pane
        // Footer line 1: status info (dim text)
        footerStatusLayer = CATextLayer()
        let statusY = frame.height - CGFloat(contentRowCount) * fontMetrics.lineHeight - fontMetrics.lineHeight
        footerStatusLayer.frame = CGRect(x: 0, y: statusY, width: frame.width, height: fontMetrics.lineHeight)
        footerStatusLayer.contentsScale = scale
        footerStatusLayer.font = fontMetrics.font
        footerStatusLayer.fontSize = fontMetrics.fontSize
        footerStatusLayer.isWrapped = false
        footerStatusLayer.truncationMode = .end
        footerStatusLayer.actions = ["contents": NSNull(), "string": NSNull()]
        // Subtle separator — slightly different background
        footerStatusLayer.backgroundColor = NSColor(hex: theme.statusBarBackground).withAlphaComponent(0.3).cgColor
        containerLayer.addSublayer(footerStatusLayer)

        // Footer line 2: warning (red text)
        footerWarningLayer = CATextLayer()
        let warningY = statusY - fontMetrics.lineHeight
        footerWarningLayer.frame = CGRect(x: 0, y: warningY, width: frame.width, height: fontMetrics.lineHeight)
        footerWarningLayer.contentsScale = scale
        footerWarningLayer.font = fontMetrics.font
        footerWarningLayer.fontSize = fontMetrics.fontSize
        footerWarningLayer.isWrapped = false
        footerWarningLayer.truncationMode = .end
        footerWarningLayer.actions = ["contents": NSNull(), "string": NSNull()]
        footerWarningLayer.backgroundColor = NSColor(hex: theme.statusBarBackground).withAlphaComponent(0.3).cgColor
        containerLayer.addSublayer(footerWarningLayer)

        // Create cursor overlay
        cursorLayer = CALayer()
        cursorLayer.frame = CGRect(x: 0, y: 0, width: fontMetrics.charAdvance, height: fontMetrics.lineHeight)
        cursorLayer.backgroundColor = NSColor(hex: theme.responseText).cgColor
        cursorLayer.actions = ["position": NSNull(), "bounds": NSNull(), "hidden": NSNull()]
        containerLayer.addSublayer(cursorLayer)
    }

    /// Set the fixed footer content (called once per pane, not every frame)
    func setFooter(statusText: NSAttributedString, warningText: NSAttributedString) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        footerStatusLayer.string = statusText
        footerWarningLayer.string = warningText
        CATransaction.commit()
    }

    func update(lines: [NSAttributedString], cursorPosition: (row: Int, col: Int), deltaTime: TimeInterval) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let rowCount = contentRows
        // Bottom-align content within the content area (above footer)
        let visibleLines = Array(lines.suffix(rowCount))
        let offset = rowCount - visibleLines.count

        for (index, lineLayer) in lineLayers.enumerated() {
            let contentIndex = index - offset
            if contentIndex >= 0 && contentIndex < visibleLines.count {
                let newLine = visibleLines[contentIndex].string
                if contentIndex >= previousLines.count || (index < previousLineMapping.count && previousLineMapping[index] != newLine) {
                    lineLayer.string = visibleLines[contentIndex]
                }
            } else {
                if index < previousLineMapping.count && !previousLineMapping[index].isEmpty {
                    lineLayer.string = nil
                }
            }
        }

        previousLineMapping = (0..<rowCount).map { index in
            let contentIndex = index - offset
            if contentIndex >= 0 && contentIndex < visibleLines.count {
                return visibleLines[contentIndex].string
            }
            return ""
        }
        previousLines = visibleLines.map { $0.string }

        // Update cursor position (bottom-aligned within content area, flipped coords)
        let visibleCount = visibleLines.count
        if visibleCount == 0 {
            // No content — hide cursor so it doesn't overlap the footer
            cursorLayer.isHidden = true
        } else {
            let cursorRowInContent = min(cursorPosition.row, visibleCount - 1)
            let cursorLayerRow = cursorRowInContent + offset
            // Clamp cursor column to prevent it from extending past the pane edge
            let clampedCol = min(cursorPosition.col, fontMetrics.cols - 1)
            let cursorX = CGFloat(clampedCol) * fontMetrics.charAdvance
            let cursorYFromTop = CGFloat(cursorLayerRow) * fontMetrics.lineHeight
            let cursorY = containerLayer.frame.height - cursorYFromTop - fontMetrics.lineHeight
            cursorLayer.frame = CGRect(x: cursorX, y: cursorY, width: fontMetrics.charAdvance, height: fontMetrics.lineHeight)

            // Cursor blink
            cursorBlinkAccumulator += deltaTime
            if cursorBlinkAccumulator >= cursorBlinkHalfPeriod {
                cursorBlinkAccumulator -= cursorBlinkHalfPeriod
                cursorVisible.toggle()
                cursorLayer.isHidden = !cursorVisible
            }
        }

        CATransaction.commit()
    }
}
