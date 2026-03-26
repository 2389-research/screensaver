// ABOUTME: Color values as hex strings for dark and light themes.
// ABOUTME: Foundation-only — no AppKit/NSColor dependency. Conversion to NSColor happens in Rendering/.

import Foundation

struct ThemeColors {
    let background: String
    let promptChevron: String
    let userInput: String
    let responseText: String
    let thinkingSpinner: String
    let toolName: String
    let toolBorder: String
    let successOutput: String
    let errorOutput: String
    let paneBorderActive: String
    let paneBorderInactive: String
    let statusBarBackground: String
    let statusBarText: String

    static let dark = ThemeColors(
        background: "#1e1e2e", promptChevron: "#d4a574", userInput: "#ffffff",
        responseText: "#e0e0e0", thinkingSpinner: "#888888", toolName: "#7aa2f7",
        toolBorder: "#555555", successOutput: "#73daca", errorOutput: "#f7768e",
        paneBorderActive: "#00d7ff", paneBorderInactive: "#444444",
        statusBarBackground: "#1e2030", statusBarText: "#c0c0c0"
    )

    static let light = ThemeColors(
        background: "#ffffff", promptChevron: "#b5651d", userInput: "#000000",
        responseText: "#333333", thinkingSpinner: "#999999", toolName: "#0055aa",
        toolBorder: "#cccccc", successOutput: "#2d8659", errorOutput: "#cc3333",
        paneBorderActive: "#0088cc", paneBorderInactive: "#cccccc",
        statusBarBackground: "#e0e0e0", statusBarText: "#333333"
    )
}
