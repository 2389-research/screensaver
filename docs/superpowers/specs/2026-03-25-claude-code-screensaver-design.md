# Claude Code Screensaver — Design Spec

A native macOS screensaver (`.saver` bundle) that displays a grid of simulated Claude Code terminal instances in a tmux-style layout, all appearing to actively work on coding tasks.

## Decisions

| Decision | Choice |
|----------|--------|
| Technology | Native Swift `ScreenSaverView` with Core Animation |
| Rendering | `CATextLayer` attributed strings, `CAShapeLayer` borders |
| Content source | Real `~/.claude/projects/` JSONL + bundled fallback sessions |
| Tmux chrome | Full: status bar, pane borders, window tabs, pane numbers |
| Claude Code TUI | Full: prompt, responses, tool blocks, thinking spinner |
| Pane layout | Dynamic/varied sizes (like a real tmux session) |
| Typing speed | Realistic human-like speed with natural pauses |
| Layout evolution | Slowly evolving — splits, closes, resizes over time |
| Color scheme | Configurable: dark, light, or mixed |
| Target | macOS 14+ (Sonoma), Swift 5.9+, Xcode project |

## 1. Architecture

The `.saver` bundle contains six core components:

### ClaudeCodeScreenSaverView

Entry point. Subclass of `ScreenSaverView`. Responsibilities:

- Creates the root `CALayer` tree on `startAnimation()`
- Owns the `TmuxLayoutEngine` and all `PaneController` instances
- Drives the animation loop via `animateOneFrame()` at ~30fps
- Provides `configureSheet()` for the preferences panel
- Tears down layers on `stopAnimation()`

### TmuxLayoutEngine

Manages the pane tree as a binary tree of horizontal/vertical splits.

**Initial layout generation:**

- Starts with one pane covering the full screen
- Randomly splits 4-8 times (horizontal or vertical, ratios between 30-70%)
- Minimum pane size constraint: ~40 chars wide, ~10 lines tall
- Result resembles a real tmux session someone has been building up

**Slow evolution (every 30-120 seconds, random interval):**

- **Split**: pick a larger pane, split it; new pane starts a fresh session
- **Close**: pick a pane, animate it collapsing; neighbor absorbs the space
- **Resize**: shift a border between two siblings by 5-15%
- All mutations use `CAAnimation` with ~0.5s duration
- Pane count constrained to 3-12

**Output:** Array of `PaneLayout` structs, each with a `CGRect` frame and a unique pane ID.

### PaneController

One per visible pane. Contains:

- A `TerminalRenderer` for drawing terminal content
- A `TmuxChromeRenderer` for borders and status bar segments
- A `SessionPlayer` driving the content

### TerminalRenderer

Renders a character grid mimicking the Claude Code terminal.

**Grid calculation:**

- Monospace font: Menlo (primary) or SF Mono (fallback)
- Font size scaled to pane dimensions
- `cols = paneWidth / charWidth`, `rows = paneHeight / charHeight`
- Scrollback buffer: ~200 lines per pane

**Rendering:**

- Single `CATextLayer` per pane with `NSAttributedString` content
- Only re-renders when content changes (dirty tracking)
- Blinking block cursor at write position (~530ms blink rate)

**Claude Code UI elements:**

| Element | Rendering |
|---------|-----------|
| User prompt | `> ` prefix, bold, warm orange (`#d4a574`) |
| User input | Bold white |
| Response text | Light gray (`#e0e0e0`) |
| Thinking spinner | Dim (`#666666`), cycling: `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏` |
| Tool call header | Blue tool name (`#7aa2f7`) in bordered box |
| Tool result | Dimmed content in bordered box |
| Success output | Green (`#73daca`) |
| Error output | Red (`#f7768e`) |
| Box borders | `╭╮╰╯│─` characters in `#333333` |

**Color schemes:**

- **Dark mode**: background `#1a1a2e`, light text
- **Light mode**: white background, dark text, muted tool boxes
- **Mixed mode**: each pane randomly assigned dark or light

### SessionPlayer

Reads JSONL session files and drives one pane's content over time.

**Content sources (in priority order):**

1. Real Claude Code sessions from `~/.claude/projects/**/*.jsonl`
2. Bundled fallback sessions in the `.saver` Resources directory

**JSONL parsing (real Claude Code format):**

Each line is a JSON object. The player extracts displayable events:

| JSONL `type` field | Content path | Rendered as |
|--------------------|-------------|-------------|
| `"user"` | `message.content` (string) | Prompt input after `>` |
| `"assistant"` | `message.content[].type == "text"` | Typed response |
| `"assistant"` | `message.content[].type == "tool_use"` | Tool call block (name + input) |
| `"assistant"` | `message.content[].type == "thinking"` | Thinking spinner |
| `"user"` (tool result) | `message.content[].type == "tool_result"` | Tool output block |
| `"file-history-snapshot"` | — | Skipped |

Events with `isApiErrorMessage: true` or `isMeta: true` are skipped.

**Playback timing:**

| Content type | Speed |
|-------------|-------|
| User prompt text | ~40 chars/sec (typing feel) |
| Response text | ~60 chars/sec with slight random variation |
| Tool call rendering | ~200 chars/sec (fast, confident) |
| Tool result content | Instant (appears all at once) |
| Scrolling output (test results, logs) | Line-by-line, ~100ms per line |
| Thinking spinner | Plays for the lesser of: real `thinking` block duration or 2-4 seconds |
| Pause between messages | 0.5-2 seconds (random) |

**Session lifecycle:**

- On startup, each pane picks a random session file at a random offset
- When a session ends, the pane picks a new random session
- Sessions are shuffled so adjacent panes show different content

### TmuxChromeRenderer

Draws the tmux visual chrome using `CAShapeLayer` and `CATextLayer`:

- **Pane borders**: 1px lines between all panes
  - Dark mode: green (`#5faf5f`) for active pane, `#444444` for others
  - Light mode: gray borders
- **Status bar**: spans full screen width at bottom
  - Left: `[0] 0:claude*  1:claude  2:claude  3:claude`
  - Right: `hostname  HH:MM  DD-Mon-YY`
  - Green background (`#5faf5f`) with black text (classic tmux)
- **Pane numbers**: briefly flash (1.5s fade) when layout mutations occur, centered in each pane

## 2. Bundled Session Corpus

~20-30 hand-crafted `.jsonl` files in the real Claude Code format. Each represents a complete coding session covering different scenarios:

**Session themes:**

- Building a REST API with Express
- Fixing a React component bug
- Writing unit tests for a Python module
- Refactoring a database schema
- Setting up CI/CD pipeline
- Debugging a memory leak
- Adding authentication to a web app
- Writing a CLI tool in Rust
- Migrating a codebase to TypeScript
- Performance optimizing a SQL query
- Building a WebSocket server
- Writing documentation
- Code review and refactoring
- Setting up Docker containers
- Implementing a search feature

Each session is 50-200 events long, providing 2-10 minutes of content at realistic playback speed.

## 3. Preferences Panel

Accessible from System Settings > Screen Saver > Options.

**Controls:**

| Control | Type | Default | Range |
|---------|------|---------|-------|
| Color scheme | Segmented control | Dark | Dark / Light / Mixed |
| Pane density | Slider | Medium | Sparse (3-4) to Dense (8-12) |
| Use real sessions | Checkbox | On | — |
| Session directory | Path picker | `~/.claude/projects/` | Any directory |
| Evolution speed | Slider | Medium | Calm (2 min) to Active (30 sec) |

Preferences stored via `ScreenSaverDefaults` with the bundle identifier as suite name.

## 4. Bundle Structure

```
ClaudeCodeScreenSaver.saver/
  Contents/
    Info.plist
    MacOS/
      ClaudeCodeScreenSaver
    Resources/
      Sessions/
        build-rest-api.jsonl
        fix-react-bug.jsonl
        write-python-tests.jsonl
        ... (~20-30 files)
```

## 5. Performance

**Frame budget:** ~33ms at 30fps.

**Per-frame work:**

- Advance each `SessionPlayer` by elapsed delta time
- For each pane with new content: rebuild `NSAttributedString`, set on `CATextLayer`
- Cursor blink toggle (every ~530ms, not every frame)
- Layout mutations are timer-driven, not per-frame

**Optimizations:**

- Dirty-rect tracking: only update `CATextLayer`s that changed
- Attributed string caching: rebuild only the changed portion (append)
- Font metrics calculated once per pane resize, cached
- `CALayer` compositing handled by GPU

**Memory:** ~200 lines * ~120 chars * 12 panes = ~288KB of text buffer. JSONL files read lazily, one event at a time.

## 6. Testing Strategy

**Unit tests:**

- `TmuxLayoutEngine`: split/close/resize produce valid layouts, constraints respected
- `SessionPlayer`: JSONL parsing for all event types, timing calculations
- `TerminalRenderer`: attributed string generation for each UI element type
- Color scheme application

**Integration tests:**

- Full animation loop with mock timer: verify layers update correctly
- Layout evolution: verify pane count stays in bounds over many mutations
- Session cycling: verify panes pick new sessions when current ones end

**End-to-end tests:**

- Build and install `.saver` bundle
- Verify it loads in System Preferences preview
- Verify preferences panel opens and persists settings
- Visual inspection of rendering on different screen sizes
