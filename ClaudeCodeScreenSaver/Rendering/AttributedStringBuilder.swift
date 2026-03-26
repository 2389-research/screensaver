// ABOUTME: Factory for building NSAttributedString instances for each Claude Code UI element.
// ABOUTME: Handles prompt chevron, response text, tool blocks with box-drawing chars, and spinner.

import AppKit
import CoreText

struct AttributedStringBuilder {
    let theme: ThemeColors
    let font: CTFont

    private var nsFont: NSFont { font as NSFont }
    private var boldFont: NSFont {
        NSFontManager.shared.convert(nsFont, toHaveTrait: .boldFontMask)
    }

    func promptLine(text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: "\u{276F} ",
            attributes: [.font: boldFont, .foregroundColor: NSColor(hex: theme.promptChevron)]))
        result.append(NSAttributedString(string: text,
            attributes: [.font: boldFont, .foregroundColor: NSColor(hex: theme.userInput)]))
        return result
    }

    func responseLine(text: String) -> NSAttributedString {
        NSAttributedString(string: text,
            attributes: [.font: nsFont, .foregroundColor: NSColor(hex: theme.responseText)])
    }

    func toolCallHeader(tool: String, args: String) -> NSAttributedString {
        let header = "\u{256D}\u{2500} \(tool) \(args) "
        let padded = header + String(repeating: "\u{2500}", count: max(40 - header.count, 1)) + "\u{256E}"
        return NSAttributedString(string: padded,
            attributes: [.font: nsFont, .foregroundColor: NSColor(hex: theme.toolName)])
    }

    func toolResultLine(text: String) -> NSAttributedString {
        let line = "\u{2502} \(text)"
        return NSAttributedString(string: line,
            attributes: [.font: nsFont, .foregroundColor: NSColor(hex: theme.toolBorder)])
    }

    func toolBlockBottom(width: Int) -> NSAttributedString {
        let line = "\u{2570}" + String(repeating: "\u{2500}", count: max(width - 2, 1)) + "\u{256F}"
        return NSAttributedString(string: line,
            attributes: [.font: nsFont, .foregroundColor: NSColor(hex: theme.toolBorder)])
    }

    func thinkingLine(frameIndex: Int) -> NSAttributedString {
        let frames = ["\u{280B}","\u{2819}","\u{2839}","\u{2838}","\u{283C}","\u{2834}","\u{2826}","\u{2827}","\u{2807}","\u{280F}"]
        let char = frames[frameIndex % frames.count]
        return NSAttributedString(string: "\(char) Thinking...",
            attributes: [.font: nsFont, .foregroundColor: NSColor(hex: theme.thinkingSpinner)])
    }

    func outputLine(text: String, isSuccess: Bool) -> NSAttributedString {
        let color = isSuccess ? theme.successOutput : theme.errorOutput
        return NSAttributedString(string: text,
            attributes: [.font: nsFont, .foregroundColor: NSColor(hex: color)])
    }
}
