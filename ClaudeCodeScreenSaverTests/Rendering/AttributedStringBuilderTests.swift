// ABOUTME: Tests for NSAttributedString generation for each Code Agent UI element.
// ABOUTME: Verifies colors, bold attributes, and correct character content.

import XCTest
import AppKit
import CoreText

final class AttributedStringBuilderTests: XCTestCase {

    let darkTheme = ThemeColors.dark
    lazy var font: CTFont = CTFontCreateWithName("Menlo" as CFString, 12.0, nil)
    lazy var builder: AttributedStringBuilder = AttributedStringBuilder(theme: darkTheme, font: font)

    func testPromptLineStartsWithChevron() {
        let result = builder.promptLine(text: "fix the bug")
        XCTAssertTrue(result.string.hasPrefix("\u{276F}"))
        XCTAssertTrue(result.string.contains("fix the bug"))
    }

    func testPromptLineUserInputIsBold() {
        let result = builder.promptLine(text: "test")
        // Check attributes on the user input portion (after the chevron + space)
        let inputStart = result.string.distance(from: result.string.startIndex,
                                                  to: result.string.range(of: "test")!.lowerBound)
        let attrs = result.attributes(at: inputStart, effectiveRange: nil)
        let attrFont = attrs[.font] as! NSFont
        XCTAssertTrue(attrFont.fontDescriptor.symbolicTraits.contains(.bold),
                     "User input should be bold")
    }

    func testResponseLineColor() {
        let result = builder.responseLine(text: "I'll fix that.")
        let attrs = result.attributes(at: 0, effectiveRange: nil)
        let color = attrs[.foregroundColor] as! NSColor
        XCTAssertEqual(color, NSColor(hex: darkTheme.responseText))
    }

    func testToolCallHeaderContainsBoxDrawing() {
        let result = builder.toolCallHeader(tool: "Read", args: "src/auth.ts")
        XCTAssertTrue(result.string.contains("\u{256D}")) // top-left corner
        XCTAssertTrue(result.string.contains("Read"))
        XCTAssertTrue(result.string.contains("\u{256E}")) // top-right corner
    }

    func testToolResultLineContainsVerticalBorder() {
        let result = builder.toolResultLine(text: "file contents")
        XCTAssertTrue(result.string.hasPrefix("\u{2502}")) // vertical bar
    }

    func testToolBlockBottomContainsCorners() {
        let result = builder.toolBlockBottom(width: 40)
        XCTAssertTrue(result.string.hasPrefix("\u{2570}")) // bottom-left
        XCTAssertTrue(result.string.hasSuffix("\u{256F}")) // bottom-right
    }

    func testThinkingSpinnerCyclesThroughFrames() {
        let spinnerChars = ["\u{280B}","\u{2819}","\u{2839}","\u{2838}","\u{283C}","\u{2834}","\u{2826}","\u{2827}","\u{2807}","\u{280F}"]
        for (i, expected) in spinnerChars.enumerated() {
            let result = builder.thinkingLine(frameIndex: i)
            XCTAssertTrue(result.string.contains(expected), "Frame \(i) missing spinner char")
        }
    }

    func testThinkingSpinnerWraps() {
        let result0 = builder.thinkingLine(frameIndex: 0)
        let result10 = builder.thinkingLine(frameIndex: 10)
        XCTAssertEqual(result0.string, result10.string) // frame 10 wraps to frame 0
    }

    func testSuccessOutputColor() {
        let result = builder.outputLine(text: "PASS", isSuccess: true)
        let attrs = result.attributes(at: 0, effectiveRange: nil)
        let color = attrs[.foregroundColor] as! NSColor
        XCTAssertEqual(color, NSColor(hex: darkTheme.successOutput))
    }

    func testErrorOutputColor() {
        let result = builder.outputLine(text: "FAIL", isSuccess: false)
        let attrs = result.attributes(at: 0, effectiveRange: nil)
        let color = attrs[.foregroundColor] as! NSColor
        XCTAssertEqual(color, NSColor(hex: darkTheme.errorOutput))
    }

    func testLightThemePrompt() {
        let lightBuilder = AttributedStringBuilder(theme: ThemeColors.light, font: font)
        let result = lightBuilder.promptLine(text: "test")
        let attrs = result.attributes(at: 0, effectiveRange: nil)
        let color = attrs[.foregroundColor] as! NSColor
        XCTAssertEqual(color, NSColor(hex: ThemeColors.light.promptChevron))
    }
}
