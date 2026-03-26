// ABOUTME: Computes monospace font metrics (char advance, line height, cols, rows) for a pane.
// ABOUTME: Uses CTFont for precise glyph measurement with 9pt floor and 14pt ceiling.

import Foundation
import CoreText

struct FontMetrics: Equatable {
    let font: CTFont
    let fontSize: CGFloat
    let charAdvance: CGFloat
    let lineHeight: CGFloat
    let cols: Int
    let rows: Int

    static func == (lhs: FontMetrics, rhs: FontMetrics) -> Bool {
        lhs.fontSize == rhs.fontSize && lhs.charAdvance == rhs.charAdvance &&
        lhs.lineHeight == rhs.lineHeight && lhs.cols == rhs.cols && lhs.rows == rhs.rows
    }

    static func compute(for rect: CGRect, targetCols: Int = 40, targetRows: Int = 10) -> FontMetrics {
        let minFontSize: CGFloat = 9.0
        let maxFontSize: CGFloat = 14.0

        var fontSize = min(rect.height / CGFloat(targetRows) / 1.4,
                          rect.width / CGFloat(targetCols) / 0.62)
        fontSize = max(minFontSize, min(maxFontSize, fontSize))

        let font = CTFontCreateWithName("Menlo" as CFString, fontSize, nil)
        let charAdvance = measureCharAdvance(font: font)
        let lineHeight = CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)

        let cols = Int(floor(rect.width / charAdvance))
        let rows = Int(floor(rect.height / lineHeight))

        return FontMetrics(font: font, fontSize: fontSize, charAdvance: charAdvance,
                          lineHeight: lineHeight, cols: cols, rows: rows)
    }

    private static func measureCharAdvance(font: CTFont) -> CGFloat {
        var glyphs: [CGGlyph] = [0]
        let chars: [UniChar] = [0x4D] // 'M'
        CTFontGetGlyphsForCharacters(font, chars, &glyphs, 1)
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advance, 1)
        return advance.width
    }
}
