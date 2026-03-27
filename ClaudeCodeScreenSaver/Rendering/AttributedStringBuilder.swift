// ABOUTME: Factory for building NSAttributedString instances for each Claude Code UI element.
// ABOUTME: Handles prompt chevron, response text, tool blocks with box-drawing chars, and spinner.

import AppKit
import CoreText

struct AttributedStringBuilder {
    let theme: ThemeColors
    let font: CTFont
    let nsFont: NSFont
    let boldFont: NSFont

    // Pre-converted colors — avoids NSColor(hex:) scanner parsing on every call
    let colorPromptChevron: NSColor
    let colorUserInput: NSColor
    let colorResponseText: NSColor
    let colorThinkingSpinner: NSColor
    let colorToolName: NSColor
    let colorToolBorder: NSColor
    let colorSuccessOutput: NSColor
    let colorErrorOutput: NSColor

    init(theme: ThemeColors, font: CTFont) {
        self.theme = theme
        self.font = font
        self.nsFont = font as NSFont
        self.boldFont = NSFontManager.shared.convert(font as NSFont, toHaveTrait: .boldFontMask)
        self.colorPromptChevron = NSColor(hex: theme.promptChevron)
        self.colorUserInput = NSColor(hex: theme.userInput)
        self.colorResponseText = NSColor(hex: theme.responseText)
        self.colorThinkingSpinner = NSColor(hex: theme.thinkingSpinner)
        self.colorToolName = NSColor(hex: theme.toolName)
        self.colorToolBorder = NSColor(hex: theme.toolBorder)
        self.colorSuccessOutput = NSColor(hex: theme.successOutput)
        self.colorErrorOutput = NSColor(hex: theme.errorOutput)
    }

    func promptLine(text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: "\u{276F} ",
            attributes: [.font: boldFont, .foregroundColor: colorPromptChevron]))
        result.append(NSAttributedString(string: text,
            attributes: [.font: boldFont, .foregroundColor: colorUserInput]))
        return result
    }

    func responseLine(text: String) -> NSAttributedString {
        NSAttributedString(string: text,
            attributes: [.font: nsFont, .foregroundColor: colorResponseText])
    }

    func toolCallHeader(tool: String, args: String) -> NSAttributedString {
        let header = "\u{256D}\u{2500} \(tool) \(args) "
        let padded = header + String(repeating: "\u{2500}", count: max(40 - header.count, 1)) + "\u{256E}"
        return NSAttributedString(string: padded,
            attributes: [.font: nsFont, .foregroundColor: colorToolName])
    }

    func toolResultLine(text: String) -> NSAttributedString {
        let line = "\u{2502} \(text)"
        return NSAttributedString(string: line,
            attributes: [.font: nsFont, .foregroundColor: colorToolBorder])
    }

    func toolBlockBottom(width: Int) -> NSAttributedString {
        let line = "\u{2570}" + String(repeating: "\u{2500}", count: max(width - 2, 1)) + "\u{256F}"
        return NSAttributedString(string: line,
            attributes: [.font: nsFont, .foregroundColor: colorToolBorder])
    }

    func bannerLine(text: String) -> NSAttributedString {
        NSAttributedString(string: text,
            attributes: [.font: nsFont, .foregroundColor: colorThinkingSpinner])
    }

    func warningLine(text: String) -> NSAttributedString {
        NSAttributedString(string: text,
            attributes: [.font: boldFont, .foregroundColor: colorErrorOutput])
    }

    func statusInfoLine(text: String) -> NSAttributedString {
        NSAttributedString(string: text,
            attributes: [.font: nsFont, .foregroundColor: colorThinkingSpinner])
    }

    func thinkingLine(frameIndex: Int) -> NSAttributedString {
        let frames = ["\u{280B}","\u{2819}","\u{2839}","\u{2838}","\u{283C}","\u{2834}","\u{2826}","\u{2827}","\u{2807}","\u{280F}"]
        let char = frames[frameIndex % frames.count]
        return NSAttributedString(string: "\(char) Thinking...",
            attributes: [.font: nsFont, .foregroundColor: colorThinkingSpinner])
    }

    func outputLine(text: String, isSuccess: Bool) -> NSAttributedString {
        let color = isSuccess ? colorSuccessOutput : colorErrorOutput
        return NSAttributedString(string: text,
            attributes: [.font: nsFont, .foregroundColor: color])
    }
}
