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

        // Create per-line text layers (row 0 at top, growing downward like a terminal)
        for row in 0..<fontMetrics.rows {
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

        // Bottom-align content: when fewer lines than rows, empty space at top, content at bottom.
        // When content fills or exceeds the viewport, show the most recent (bottom) lines.
        let visibleLines = Array(lines.suffix(fontMetrics.rows))
        let offset = fontMetrics.rows - visibleLines.count // empty rows at top

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
        // Track what each layer is showing for dirty detection
        previousLineMapping = (0..<fontMetrics.rows).map { index in
            let contentIndex = index - offset
            if contentIndex >= 0 && contentIndex < visibleLines.count {
                return visibleLines[contentIndex].string
            }
            return ""
        }
        previousLines = visibleLines.map { $0.string }

        // Update cursor position (bottom-aligned, flipped coords)
        let visibleCount = visibleLines.count
        let cursorRowInContent = min(cursorPosition.row, visibleCount - 1)
        let cursorLayerRow = cursorRowInContent + offset // map to layer index
        let cursorX = CGFloat(cursorPosition.col) * fontMetrics.charAdvance
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

        CATransaction.commit()
    }
}
