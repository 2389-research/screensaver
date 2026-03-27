# Code Agent Screensaver — Project Instructions

## Build & Test

```bash
# Build
xcodebuild build -scheme ClaudeCodeScreenSaver -destination 'platform=macOS'

# Test (115 tests)
xcodebuild test -scheme ClaudeCodeScreenSaver -destination 'platform=macOS'

# Release build
xcodebuild build -scheme ClaudeCodeScreenSaver -configuration Release -destination 'platform=macOS'
```

## Architecture

Native macOS `.saver` bundle using `ScreenSaverView` + Core Animation.

### Key Constraints

- **Delta-time model**: All animation timing uses `CACurrentMediaTime()` deltas, never frame count. `animateOneFrame()` is not called at a fixed rate.
- **CATransaction.setDisableActions(true)**: Required for ALL `CATextLayer` content updates. Without it, Core Animation applies a 0.25s cross-fade.
- **Threading**: JSONL parsing happens on a background queue. Layer mutations happen on the animation thread inside `CATransaction` blocks.
- **Platform isolation**: `Models/` and `Protocols/` import Foundation only. AppKit/QuartzCore confined to `Helpers/`, `Rendering/`, `View/`.

### File Layout

```
ClaudeCodeScreenSaver/
  Protocols/     — Foundation-only protocols (AnimationClock, SessionDataSource, LayoutMetricsProvider)
  Models/        — Foundation-only data types (SessionEvent, PaneLayout, ThemeColors, Preferences)
  Helpers/       — Platform-specific implementations (NSColor+Hex, SystemAnimationClock, PreferencesStorage)
  Engine/        — Core logic (TmuxLayoutEngine, SessionPlayer, SessionParser, ThreadSafeBuffer)
  Rendering/     — CALayer rendering (TerminalRenderer, TmuxChromeRenderer, BorderRenderer, FontMetrics, AttributedStringBuilder)
  View/          — ScreenSaverView entry point (ClaudeCodeScreenSaverView, PaneController, PreferencesController)
  Resources/Sessions/  — Bundled JSONL session files (20 files)
```

### Pane Borders

Rendered as text characters (`│─┼├┤┬┴`) in the monospace grid, NOT as `CALayer.borderWidth`. This produces authentic tmux junction characters.

### Active Pane

Follows content, not a random timer. When a `SessionPlayer` starts typing a new user prompt, that pane becomes the active pane (cyan border).

### SourceKit False Alarms

The LSP reports false "Cannot find type" errors for types defined in other files within the Xcode project. These are SourceKit issues — the actual `xcodebuild` compiles successfully. Always verify with `xcodebuild build` if SourceKit reports errors.

## Spec & Plan

- Design spec: `docs/superpowers/specs/2026-03-25-claude-code-screensaver-design.md`
- Implementation plan: `docs/superpowers/plans/2026-03-25-claude-code-screensaver.md`
