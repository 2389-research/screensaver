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

    // Catppuccin Mocha (default)
    static let catppuccinMocha = ThemeColors(
        background: "#1e1e2e", promptChevron: "#d4a574", userInput: "#ffffff",
        responseText: "#e0e0e0", thinkingSpinner: "#888888", toolName: "#7aa2f7",
        toolBorder: "#555555", successOutput: "#73daca", errorOutput: "#f7768e",
        paneBorderActive: "#00d7ff", paneBorderInactive: "#444444",
        statusBarBackground: "#1e2030", statusBarText: "#c0c0c0"
    )

    // Tokyo Night
    static let tokyoNight = ThemeColors(
        background: "#1a1b26", promptChevron: "#e0af68", userInput: "#c0caf5",
        responseText: "#a9b1d6", thinkingSpinner: "#565f89", toolName: "#7aa2f7",
        toolBorder: "#3b4261", successOutput: "#9ece6a", errorOutput: "#f7768e",
        paneBorderActive: "#7dcfff", paneBorderInactive: "#3b4261",
        statusBarBackground: "#16161e", statusBarText: "#a9b1d6"
    )

    // Dracula
    static let dracula = ThemeColors(
        background: "#282a36", promptChevron: "#ffb86c", userInput: "#f8f8f2",
        responseText: "#f8f8f2", thinkingSpinner: "#6272a4", toolName: "#8be9fd",
        toolBorder: "#44475a", successOutput: "#50fa7b", errorOutput: "#ff5555",
        paneBorderActive: "#bd93f9", paneBorderInactive: "#44475a",
        statusBarBackground: "#21222c", statusBarText: "#f8f8f2"
    )

    // Nord
    static let nord = ThemeColors(
        background: "#2e3440", promptChevron: "#d08770", userInput: "#eceff4",
        responseText: "#d8dee9", thinkingSpinner: "#4c566a", toolName: "#88c0d0",
        toolBorder: "#434c5e", successOutput: "#a3be8c", errorOutput: "#bf616a",
        paneBorderActive: "#88c0d0", paneBorderInactive: "#434c5e",
        statusBarBackground: "#272c36", statusBarText: "#d8dee9"
    )

    // Gruvbox Dark
    static let gruvbox = ThemeColors(
        background: "#282828", promptChevron: "#fe8019", userInput: "#ebdbb2",
        responseText: "#d5c4a1", thinkingSpinner: "#665c54", toolName: "#83a598",
        toolBorder: "#504945", successOutput: "#b8bb26", errorOutput: "#fb4934",
        paneBorderActive: "#fabd2f", paneBorderInactive: "#504945",
        statusBarBackground: "#1d2021", statusBarText: "#d5c4a1"
    )

    // Solarized Dark
    static let solarized = ThemeColors(
        background: "#002b36", promptChevron: "#cb4b16", userInput: "#fdf6e3",
        responseText: "#839496", thinkingSpinner: "#586e75", toolName: "#268bd2",
        toolBorder: "#073642", successOutput: "#859900", errorOutput: "#dc322f",
        paneBorderActive: "#2aa198", paneBorderInactive: "#073642",
        statusBarBackground: "#002028", statusBarText: "#93a1a1"
    )

    // All dark theme variants for per-pane assignment
    static let darkVariants: [ThemeColors] = [
        .catppuccinMocha, .tokyoNight, .dracula, .nord, .gruvbox, .solarized
    ]

    // Aliases for backward compatibility
    static let dark = catppuccinMocha

    static let light = ThemeColors(
        background: "#ffffff", promptChevron: "#b5651d", userInput: "#000000",
        responseText: "#333333", thinkingSpinner: "#999999", toolName: "#0055aa",
        toolBorder: "#cccccc", successOutput: "#2d8659", errorOutput: "#cc3333",
        paneBorderActive: "#0088cc", paneBorderInactive: "#cccccc",
        statusBarBackground: "#e0e0e0", statusBarText: "#333333"
    )
}
