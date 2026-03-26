// ABOUTME: Renders terminal content as a grid of per-line CATextLayer instances.
// ABOUTME: Manages cursor overlay, dirty-line tracking, and viewport bottom-tracking.

import AppKit
import QuartzCore
import CoreText

class TerminalRenderer {
    let containerLayer: CALayer
    private(set) var lineLayers: [CATextLayer] = []
    let cursorLayer: CALayer
    let fontMetrics: FontMetrics
    private let theme: ThemeColors

    private var previousLines: [String] = []
    private var cursorBlinkAccumulator: TimeInterval = 0
    private var cursorVisible = true
    private let cursorBlinkHalfPeriod: TimeInterval = 0.530

    init(frame: CGRect, theme: ThemeColors, scale: CGFloat = 2.0) {
        self.theme = theme
        self.fontMetrics = FontMetrics.compute(for: frame)
        self.containerLayer = CALayer()
        containerLayer.frame = frame
        containerLayer.backgroundColor = NSColor(hex: theme.background).cgColor

        // Create per-line text layers
        for row in 0..<fontMetrics.rows {
            let lineLayer = CATextLayer()
            lineLayer.frame = CGRect(
                x: 0,
                y: CGFloat(row) * fontMetrics.lineHeight,
                width: frame.width,
                height: fontMetrics.lineHeight
            )
            lineLayer.contentsScale = scale
            lineLayer.font = fontMetrics.font
            lineLayer.fontSize = fontMetrics.fontSize
            lineLayer.isWrapped = false
            lineLayer.truncationMode = .end
            // Suppress implicit animations
            lineLayer.actions = ["contents": NSNull(), "string": NSNull()]
            containerLayer.addSublayer(lineLayer)
            lineLayers.append(lineLayer)
        }

        // Create cursor overlay
        cursorLayer = CALayer()
        cursorLayer.frame = CGRect(x: 0, y: 0, width: fontMetrics.charAdvance, height: fontMetrics.lineHeight)
        cursorLayer.backgroundColor = NSColor(hex: theme.responseText).cgColor
        cursorLayer.actions = ["position": NSNull(), "bounds": NSNull(), "hidden": NSNull()]
        containerLayer.addSublayer(cursorLayer)
    }

    func update(lines: [NSAttributedString], cursorPosition: (row: Int, col: Int), deltaTime: TimeInterval) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Update only changed lines (viewport shows bottom N lines)
        let visibleLines = Array(lines.suffix(fontMetrics.rows))
        for (index, lineLayer) in lineLayers.enumerated() {
            if index < visibleLines.count {
                let newLine = visibleLines[index].string
                if index >= previousLines.count || previousLines[index] != newLine {
                    lineLayer.string = visibleLines[index]
                }
            } else {
                if index < previousLines.count && !previousLines[index].isEmpty {
                    lineLayer.string = nil
                }
            }
        }
        previousLines = visibleLines.map { $0.string }

        // Update cursor position
        let cursorRow = min(cursorPosition.row, fontMetrics.rows - 1)
        let cursorX = CGFloat(cursorPosition.col) * fontMetrics.charAdvance
        let cursorY = CGFloat(cursorRow) * fontMetrics.lineHeight
        cursorLayer.frame = CGRect(x: cursorX, y: cursorY, width: fontMetrics.charAdvance, height: fontMetrics.lineHeight)

        // Cursor blink
        cursorBlinkAccumulator += deltaTime
        if cursorBlinkAccumulator >= cursorBlinkHalfPeriod {
            cursorBlinkAccumulator -= cursorBlinkHalfPeriod
            cursorVisible.toggle()
            cursorLayer.isHidden = !cursorVisible
        }

        CATransaction.commit()
    }

    func resize(to frame: CGRect) {
        // Rebuild for new dimensions — called when pane layout changes
        containerLayer.frame = frame
    }
}
