// ABOUTME: Computes text-character borders between tmux panes with proper junction characters.
// ABOUTME: Produces BorderSegment arrays for rendering as CATextLayer instances in pane gaps.

import Foundation

struct BorderSegment: Equatable {
    let position: CGPoint  // where to render this character
    let character: String  // │ ─ ┼ ├ ┤ ┬ ┴
    let isAdjacentToActive: Bool  // true if this border touches the active pane
}

enum BorderRenderer {

    /// Computes border segments for the gaps between pane layouts.
    ///
    /// The pane frames from TmuxLayoutEngine leave 1-char-wide gaps between adjacent panes.
    /// This method finds border lines between panes and populates them with the correct
    /// box-drawing characters including junction detection.
    static func computeSegments(
        layouts: [PaneLayout],
        totalBounds: CGRect,
        charAdvance: CGFloat,
        lineHeight: CGFloat
    ) -> [BorderSegment] {
        guard layouts.count > 1, charAdvance > 0, lineHeight > 0 else { return [] }

        let tolerance = min(charAdvance, lineHeight) * 0.5

        // Find all border lines between pairs of panes
        var verticalBorders = findVerticalBorders(layouts: layouts, charAdvance: charAdvance, tolerance: tolerance)
        var horizontalBorders = findHorizontalBorders(layouts: layouts, lineHeight: lineHeight, tolerance: tolerance)

        // Merge overlapping/adjacent borders at the same position and extend through junctions
        verticalBorders = mergeBorders(verticalBorders, step: lineHeight, tolerance: tolerance)
        horizontalBorders = mergeBorders(horizontalBorders, step: charAdvance, tolerance: tolerance)

        var segments: [BorderSegment] = []
        var emitted: Set<String> = []

        // Collect junction Y positions from horizontal borders for each vertical border
        let hPositions = horizontalBorders.map { $0.position }

        // Emit vertical border segments
        for border in verticalBorders {
            // Build sorted list of Y positions: regular grid + junction points
            var yPositions: [CGFloat] = []
            var y = border.minExtent
            while y <= border.maxExtent + tolerance {
                yPositions.append(y)
                y += lineHeight
            }
            // Add junction Y positions that fall within this border's extent
            for hPos in hPositions {
                if hPos >= border.minExtent - tolerance && hPos <= border.maxExtent + tolerance {
                    // Only add if not already close to an existing position
                    let alreadyPresent = yPositions.contains { abs($0 - hPos) < tolerance }
                    if !alreadyPresent {
                        yPositions.append(hPos)
                    }
                }
            }
            yPositions.sort()

            for yPos in yPositions {
                let key = posKey(border.position, yPos)
                if emitted.contains(key) {
                    continue
                }
                emitted.insert(key)

                let isJunction = horizontalBorders.contains { hBorder in
                    abs(yPos - hBorder.position) < tolerance &&
                    hBorder.minExtent <= border.position + tolerance &&
                    hBorder.maxExtent >= border.position - tolerance
                }

                let character: String
                if isJunction {
                    character = classifyJunction(
                        x: border.position, y: yPos,
                        verticalBorders: verticalBorders,
                        horizontalBorders: horizontalBorders,
                        tolerance: tolerance,
                        lineHeight: lineHeight,
                        charAdvance: charAdvance
                    )
                } else {
                    character = "│"
                }

                let isActive = border.isAdjacentToActive || (isJunction && horizontalBorders.contains { hBorder in
                    abs(yPos - hBorder.position) < tolerance && hBorder.isAdjacentToActive
                })

                segments.append(BorderSegment(
                    position: CGPoint(x: border.position, y: yPos),
                    character: character,
                    isAdjacentToActive: isActive
                ))
            }
        }

        // Collect junction X positions from vertical borders
        let vPositions = verticalBorders.map { $0.position }

        // Emit horizontal border segments (skip positions covered by vertical borders)
        for border in horizontalBorders {
            // Build sorted list of X positions: regular grid + junction points
            var xPositions: [CGFloat] = []
            var xPos = border.minExtent
            while xPos <= border.maxExtent + tolerance {
                xPositions.append(xPos)
                xPos += charAdvance
            }
            for vPos in vPositions {
                if vPos >= border.minExtent - tolerance && vPos <= border.maxExtent + tolerance {
                    let alreadyPresent = xPositions.contains { abs($0 - vPos) < tolerance }
                    if !alreadyPresent {
                        xPositions.append(vPos)
                    }
                }
            }
            xPositions.sort()

            for x in xPositions {
                let key = posKey(x, border.position)
                if emitted.contains(key) {
                    continue
                }
                emitted.insert(key)

                segments.append(BorderSegment(
                    position: CGPoint(x: x, y: border.position),
                    character: "─",
                    isAdjacentToActive: border.isAdjacentToActive
                ))
            }
        }

        return segments
    }

    // MARK: - Border Detection

    /// Represents a border line (vertical or horizontal) between panes.
    private struct BorderLine {
        let position: CGFloat    // x for vertical borders, y for horizontal borders
        var minExtent: CGFloat   // start of the border line
        var maxExtent: CGFloat   // end of the border line
        let isAdjacentToActive: Bool
    }

    private static func posKey(_ x: CGFloat, _ y: CGFloat) -> String {
        "\(Int(round(x * 100)))_\(Int(round(y * 100)))"
    }

    /// Merges border lines that share the same position and are adjacent or overlapping.
    private static func mergeBorders(_ borders: [BorderLine], step: CGFloat, tolerance: CGFloat) -> [BorderLine] {
        guard !borders.isEmpty else { return [] }

        // Group by position (quantized)
        var grouped: [Int: [BorderLine]] = [:]
        for border in borders {
            let key = Int(round(border.position * 100))
            grouped[key, default: []].append(border)
        }

        var merged: [BorderLine] = []
        for (_, group) in grouped {
            // Sort by minExtent
            let sorted = group.sorted { $0.minExtent < $1.minExtent }
            var current = sorted[0]
            let isActive = group.contains { $0.isAdjacentToActive }

            for i in 1..<sorted.count {
                let next = sorted[i]
                // Merge if overlapping or adjacent (within one step + tolerance)
                if next.minExtent <= current.maxExtent + step + tolerance {
                    current = BorderLine(
                        position: current.position,
                        minExtent: current.minExtent,
                        maxExtent: max(current.maxExtent, next.maxExtent),
                        isAdjacentToActive: isActive
                    )
                } else {
                    merged.append(BorderLine(
                        position: current.position,
                        minExtent: current.minExtent,
                        maxExtent: current.maxExtent,
                        isAdjacentToActive: isActive
                    ))
                    current = next
                }
            }
            merged.append(BorderLine(
                position: current.position,
                minExtent: current.minExtent,
                maxExtent: current.maxExtent,
                isAdjacentToActive: isActive
            ))
        }

        return merged
    }

    /// Finds vertical borders between pairs of panes separated by ~charAdvance horizontally.
    private static func findVerticalBorders(
        layouts: [PaneLayout],
        charAdvance: CGFloat,
        tolerance: CGFloat
    ) -> [BorderLine] {
        var borders: [BorderLine] = []

        for i in 0..<layouts.count {
            for j in (i + 1)..<layouts.count {
                let a = layouts[i]
                let b = layouts[j]

                // Check if b is to the right of a
                let gapAB = b.frame.minX - a.frame.maxX
                if abs(gapAB - charAdvance) < tolerance {
                    let overlapMinY = max(a.frame.minY, b.frame.minY)
                    let overlapMaxY = min(a.frame.maxY, b.frame.maxY)
                    if overlapMaxY > overlapMinY + tolerance {
                        borders.append(BorderLine(
                            position: a.frame.maxX,
                            minExtent: overlapMinY,
                            maxExtent: overlapMaxY,
                            isAdjacentToActive: a.isActive || b.isActive
                        ))
                    }
                }

                // Check if a is to the right of b
                let gapBA = a.frame.minX - b.frame.maxX
                if abs(gapBA - charAdvance) < tolerance {
                    let overlapMinY = max(a.frame.minY, b.frame.minY)
                    let overlapMaxY = min(a.frame.maxY, b.frame.maxY)
                    if overlapMaxY > overlapMinY + tolerance {
                        borders.append(BorderLine(
                            position: b.frame.maxX,
                            minExtent: overlapMinY,
                            maxExtent: overlapMaxY,
                            isAdjacentToActive: a.isActive || b.isActive
                        ))
                    }
                }
            }
        }

        return borders
    }

    /// Finds horizontal borders between pairs of panes separated by ~lineHeight vertically.
    private static func findHorizontalBorders(
        layouts: [PaneLayout],
        lineHeight: CGFloat,
        tolerance: CGFloat
    ) -> [BorderLine] {
        var borders: [BorderLine] = []

        for i in 0..<layouts.count {
            for j in (i + 1)..<layouts.count {
                let a = layouts[i]
                let b = layouts[j]

                let overlapMinX = max(a.frame.minX, b.frame.minX)
                let overlapMaxX = min(a.frame.maxX, b.frame.maxX)
                guard overlapMaxX > overlapMinX + tolerance else { continue }

                // Standard gap: b sits above a with exactly lineHeight gap
                let gapAB = b.frame.minY - a.frame.maxY
                if abs(gapAB - lineHeight) < tolerance {
                    borders.append(BorderLine(
                        position: a.frame.maxY,
                        minExtent: overlapMinX,
                        maxExtent: overlapMaxX,
                        isAdjacentToActive: a.isActive || b.isActive
                    ))
                }

                // Standard gap: a sits above b with exactly lineHeight gap
                let gapBA = a.frame.minY - b.frame.maxY
                if abs(gapBA - lineHeight) < tolerance {
                    borders.append(BorderLine(
                        position: b.frame.maxY,
                        minExtent: overlapMinX,
                        maxExtent: overlapMaxX,
                        isAdjacentToActive: a.isActive || b.isActive
                    ))
                }

                // Offset origin case: one pane's minY = other's minY + lineHeight
                let minYDiffAB = a.frame.minY - b.frame.minY
                if abs(minYDiffAB - lineHeight) < tolerance {
                    borders.append(BorderLine(
                        position: b.frame.minY,
                        minExtent: overlapMinX,
                        maxExtent: overlapMaxX,
                        isAdjacentToActive: a.isActive || b.isActive
                    ))
                }
                if abs(-minYDiffAB - lineHeight) < tolerance {
                    borders.append(BorderLine(
                        position: a.frame.minY,
                        minExtent: overlapMinX,
                        maxExtent: overlapMaxX,
                        isAdjacentToActive: a.isActive || b.isActive
                    ))
                }

                // Offset top case: one pane's maxY = other's maxY + lineHeight
                let maxYDiffAB = a.frame.maxY - b.frame.maxY
                if abs(maxYDiffAB - lineHeight) < tolerance {
                    borders.append(BorderLine(
                        position: b.frame.maxY,
                        minExtent: overlapMinX,
                        maxExtent: overlapMaxX,
                        isAdjacentToActive: a.isActive || b.isActive
                    ))
                }
                if abs(-maxYDiffAB - lineHeight) < tolerance {
                    borders.append(BorderLine(
                        position: a.frame.maxY,
                        minExtent: overlapMinX,
                        maxExtent: overlapMaxX,
                        isAdjacentToActive: a.isActive || b.isActive
                    ))
                }
            }
        }

        return borders
    }

    // MARK: - Junction Classification

    /// Determines the junction character based on which directions have continuing borders.
    private static func classifyJunction(
        x: CGFloat, y: CGFloat,
        verticalBorders: [BorderLine],
        horizontalBorders: [BorderLine],
        tolerance: CGFloat,
        lineHeight: CGFloat,
        charAdvance: CGFloat
    ) -> String {
        let hasUp = verticalBorders.contains { border in
            abs(border.position - x) < tolerance && border.maxExtent > y + lineHeight * 0.5
        }
        let hasDown = verticalBorders.contains { border in
            abs(border.position - x) < tolerance && border.minExtent < y - lineHeight * 0.5
        }
        let hasLeft = horizontalBorders.contains { border in
            abs(border.position - y) < tolerance && border.minExtent < x - charAdvance * 0.5
        }
        let hasRight = horizontalBorders.contains { border in
            abs(border.position - y) < tolerance && border.maxExtent > x + charAdvance * 0.5
        }

        switch (hasUp, hasDown, hasLeft, hasRight) {
        case (true, true, true, true):
            return "┼"
        case (true, true, false, true):
            return "├"
        case (true, true, true, false):
            return "┤"
        case (false, true, true, true):
            return "┬"
        case (true, false, true, true):
            return "┴"
        default:
            return "┼"
        }
    }
}
