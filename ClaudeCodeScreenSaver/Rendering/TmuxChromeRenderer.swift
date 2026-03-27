// ABOUTME: Renders tmux visual chrome: status bar with session name, window list, and time.
// ABOUTME: Status bar height is exactly one line of monospace font. No pane number flashing.

import AppKit
import CoreText

class TmuxChromeRenderer {
    private(set) var sessionName: String
    private(set) var windowCount: Int
    private(set) var activeWindow: Int
    private(set) var lastWindow: Int

    init(sessionName: String, windowCount: Int, activeWindow: Int, lastWindow: Int) {
        self.sessionName = sessionName
        self.windowCount = windowCount
        self.activeWindow = activeWindow
        self.lastWindow = lastWindow
    }

    func statusBarLeftText() -> String {
        var parts = "[\(sessionName)] "
        for i in 0..<windowCount {
            let flag: String
            if i == activeWindow { flag = "*" }
            else if i == lastWindow { flag = "-" }
            else { flag = "" }
            parts += "\(i):agent\(flag)"
            if i < windowCount - 1 { parts += "  " }
        }
        return parts
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm dd-MMM-yyyy"
        return f
    }()

    func statusBarRightText() -> String {
        Self.dateFormatter.string(from: Date())
    }

    func statusBarHeight(for font: CTFont) -> CGFloat {
        CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
    }

    func updateActiveWindow(_ index: Int) {
        lastWindow = activeWindow
        activeWindow = index
    }

    func createStatusBarLayer(width: CGFloat, font: CTFont, theme: ThemeColors, scale: CGFloat = 2.0) -> CALayer {
        let height = statusBarHeight(for: font)
        let barLayer = CALayer()
        barLayer.frame = CGRect(x: 0, y: 0, width: width, height: height)
        barLayer.backgroundColor = NSColor(hex: theme.statusBarBackground).cgColor

        let nsFont = font as NSFont

        // Left text
        let leftLayer = CATextLayer()
        leftLayer.frame = CGRect(x: 4, y: 0, width: width * 0.6, height: height)
        leftLayer.string = NSAttributedString(
            string: statusBarLeftText(),
            attributes: [.font: nsFont, .foregroundColor: NSColor(hex: theme.statusBarText)]
        )
        leftLayer.contentsScale = scale
        leftLayer.alignmentMode = .left
        leftLayer.actions = ["contents": NSNull(), "string": NSNull()]
        barLayer.addSublayer(leftLayer)

        // Right text
        let rightLayer = CATextLayer()
        rightLayer.frame = CGRect(x: width * 0.6, y: 0, width: width * 0.4 - 4, height: height)
        rightLayer.string = NSAttributedString(
            string: statusBarRightText(),
            attributes: [.font: nsFont, .foregroundColor: NSColor(hex: theme.statusBarText)]
        )
        rightLayer.contentsScale = scale
        rightLayer.alignmentMode = .right
        rightLayer.actions = ["contents": NSNull(), "string": NSNull()]
        barLayer.addSublayer(rightLayer)

        return barLayer
    }
}
