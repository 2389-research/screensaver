# Claude Code Screensaver — Design Spec

A native macOS screensaver (`.saver` bundle) that displays a grid of simulated Claude Code terminal instances in a tmux-style layout, all appearing to actively work on coding tasks.

## Decisions

| Decision | Choice |
|----------|--------|
| Technology | Native Swift `ScreenSaverView` with Core Animation |
| Rendering | Per-line `CATextLayer` with cursor overlay layer, `CALayer.borderWidth` for pane borders |
| Content source | Bundled sessions (default) + opt-in real `~/.claude/projects/` JSONL via security-scoped bookmark |
| Tmux chrome | Full: status bar, pane borders, window tabs |
| Claude Code TUI | Full: prompt, responses, tool blocks, thinking spinner |
| Pane layout | Dynamic/varied sizes (like a real tmux session) |
| Typing speed | Realistic human-like speed with natural pauses |
| Layout evolution | Slowly evolving — splits, closes, resizes over time |
| Color scheme | Configurable: dark or light |
| Target | macOS 14+ (Sonoma), Swift 5.9+, Xcode project, Developer ID signed + notarized |

## Architectural Constraints

- **No audio.** This screensaver produces no audio output under any circumstance. No `AVAudioSession`, no system sounds, no typing sounds.
- **Delta-time model.** All animation timing is driven by elapsed wall-clock time (`CACurrentMediaTime()`), never frame count. `animateOneFrame()` is not called at a fixed rate.
- **All content updates wrapped in `CATransaction.setDisableActions(true)`.** `CATextLayer` has a default 0.25s cross-fade implicit animation on `.string` changes that must be suppressed.
- **JSONL parsing on a background queue.** File I/O never occurs on the animation thread. Pre-parsed events are consumed from a thread-safe buffer.
- **Protocol abstractions for testability.** All external dependencies (file system, clock, layout metrics) are behind protocols. Test doubles conform to the same protocols.

## 1. Architecture

The `.saver` bundle contains six core components:

### ClaudeCodeScreenSaverView

Entry point. Subclass of `ScreenSaverView`. Responsibilities:

- Creates the root `CALayer` tree on `startAnimation()`
- Owns the `TmuxLayoutEngine` and all `PaneController` instances
- Records `CACurrentMediaTime()` each frame and computes `deltaTime` for all subsystems
- Provides `configureSheet()` for the preferences panel (all delegate/callback references back to the view must be `weak` to prevent retain cycles)
- Tears down layers and cancels all `Task` instances on `stopAnimation()`
- `stopAnimation()` is idempotent — safe to call without a preceding `startAnimation()`

**Preview mode (`isPreview == true`):**

- Maximum 2-3 panes using bundled sessions only
- No layout evolution timers
- No real session loading
- Reduced `animationTimeInterval`

**Multi-display:** macOS creates one instance per connected screen. Each instance seeds its random number generator with a hash of `NSScreen.displayID` so displays show different content. Only the main display instance scans for real JSONL files; secondary displays use bundled sessions.

**Power awareness:** Detect power source via `IOPSCopyPowerSourcesInfo()`. On battery: reduce to maximum 4 panes and 15fps. Target sustained CPU below 8% on Apple Silicon.

### TmuxLayoutEngine

Manages the pane tree as a binary tree of horizontal/vertical splits.

**Initial layout generation:**

- Starts with one pane covering the full screen
- Randomly splits 4-8 times (horizontal or vertical, ratios between 40-60% to match real tmux 50/50 default behavior with slight variation)
- Minimum pane size constraint: 40 chars wide, 10 lines tall (hard minimum, no approximation)
- Minimum font size: 9pt. If a pane cannot fit 40 columns at 9pt, the split is rejected.

**Startup sequence:** Panes activate with a staggered delay of 0.5-1 second each, creating a visible "system coming alive" effect rather than all panes starting simultaneously.

**Slow evolution:** Mutations occur at intervals determined by the Evolution Speed preference (see Section 3). Distribution is uniform random within the configured range.

- **Split**: pick a larger pane, split it 50/50; new pane starts a fresh session
- **Close**: pick a pane, snap-resize the neighbor to absorb the space (no animated resize — tmux resize is instantaneous)
- **Resize**: shift a border between two siblings by 5-15%, applied instantly
- Geometry changes use `CATransaction` with explicit animation only for the frame property, content layers update within the same transaction with actions disabled
- Pane count constrained to bounds set by the Pane Density preference (default 3-8)

**During layout mutations:** The `SessionPlayer` in a splitting pane pauses during the split, then resumes. A closing pane freezes content immediately. After any geometry change, affected `PaneController` instances recalculate font metrics and rebuild visible content within the same `CATransaction`.

**Output:** Array of `PaneLayout` structs, each with a `CGRect` frame, unique pane ID, and `isActive` flag.

### PaneController

One per visible pane. Contains:

- A `TerminalRenderer` for drawing terminal content
- A `TmuxChromeRenderer` for borders and status bar segments
- A `SessionPlayer` driving the content

### TerminalRenderer

Renders a character grid mimicking the Claude Code terminal.

**Grid calculation:**

- Monospace font: Menlo (primary) or `NSFont.monospacedSystemFont(ofSize:weight:)` (fallback). SF Mono is not used (not reliably available as a system font).
- Font size: computed as `min(paneHeight / targetRows / lineHeightMultiplier, paneWidth / targetCols / charAdvanceWidth)` with a floor of 9pt and ceiling of 14pt
- Column count: `Int(floor(paneWidth / charAdvance))` using `CTFontGetAdvancesForGlyphs` for precise measurement
- Row count: `Int(floor(paneHeight / lineHeight))`
- Scrollback buffer: 200 lines per pane in a circular buffer of pre-built `NSAttributedString` line objects

**Rendering:**

- One `CATextLayer` per visible line (not one per pane). Only dirty lines are rebuilt. GPU compositing handles the rest.
- Cursor rendered as a separate overlay `CALayer` (`FULL BLOCK` U+2588) positioned at the current write position. Cursor blink driven by delta-time accumulator in `animateOneFrame()` (530ms half-period: 530ms visible, 530ms hidden). Cursor only shown at active write positions — not in tool output blocks.
- **Viewport always shows the bottom of content** (terminal scroll behavior). When content exceeds visible rows, older lines scroll up and the viewport tracks the tail.

**Claude Code UI elements:**

| Element | Rendering |
|---------|-----------|
| User prompt | `❯ ` (U+276F) prefix, bold, warm orange (`#d4a574`) |
| User input | Bold white |
| Response text | Light gray (`#e0e0e0`) |
| Thinking spinner | Muted (`#888888`), cycling `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏` at 100ms per frame (every 3rd animation frame at 30fps) |
| Tool call header | Blue tool name (`#7aa2f7`) in rounded-corner bordered box (`╭╮╰╯│─`) |
| Tool result | Dimmed content in rounded-corner bordered box |
| Success output | Green (`#73daca`) |
| Error output | Red (`#f7768e`) |
| Tool block box borders | `╭╮╰╯│─` characters in `#555555` |

**Color schemes:**

- **Dark mode**: background `#1e1e2e` (Catppuccin Mocha base), light text. Tool block borders `#555555`.
- **Light mode**: white background, dark text, muted tool boxes

### SessionPlayer

Reads JSONL session files and drives one pane's content over time. Conforms to a `SessionDataSource` protocol for testability.

**Content sources:**

1. Bundled sessions in the `.saver` Resources directory (always available, used by default)
2. Real Claude Code sessions from a user-configured directory (opt-in, requires security-scoped bookmark)

**JSONL parsing (real Claude Code format):**

Each line is a JSON object. Parsing happens on a background `DispatchQueue`. Pre-parsed events are fed to the animation thread via a thread-safe ring buffer. Lines that fail JSON parsing are silently skipped. Files that are entirely unreadable are skipped.

The player extracts displayable events:

| JSONL `type` field | Content path | Rendered as |
|--------------------|-------------|-------------|
| `"user"` | `message.content` is a string | Prompt input after `❯` |
| `"user"` | `message.content` is an array containing `tool_result` items | Tool output block |
| `"assistant"` | `message.content[].type == "text"` | Typed response |
| `"assistant"` | `message.content[].type == "tool_use"` | Tool call block (name + input) |
| `"assistant"` | `message.content[].type == "thinking"` | Thinking spinner |
| `"file-history-snapshot"` | — | Skipped |
| `"progress"`, `"summary"`, `"system"`, `"last-prompt"`, `"queue-operation"` | — | Skipped |
| Any unknown type | — | Silently skipped |

**Disambiguation:** User messages where `message.content` is a plain string are human prompts. User messages where `message.content` is an array (containing `tool_result` objects) are tool outputs from the previous assistant tool call. `tool_result.content` may be a string, array, or null — handle all cases.

Events with `isApiErrorMessage: true` or `isMeta: true` are skipped.

**Playback timing (all driven by delta-time accumulator, not frame count):**

| Content type | Speed |
|-------------|-------|
| User prompt text | ~40 chars/sec |
| Response text | ~60 chars/sec with slight random variation |
| Tool call rendering | ~200 chars/sec |
| Tool result content | Fade in over 300ms (not instant — prevents visual "pop" that breaks ambient feel) |
| Scrolling output (test results, logs) | Line-by-line, ~100ms per line, viewport tracks bottom |
| Thinking spinner | Plays for the lesser of the real `thinking` block duration or a uniform random 2-4 seconds. Minimum display: 500ms. |
| Pause between messages | 0.5-2 seconds (uniform random) |

**Session lifecycle:**

- On startup, each pane picks a random session file at a random offset (staggered by the startup sequence)
- When a session ends, the pane picks a new random session
- Sessions are assigned so no two panes sharing a border play the same session file. On reassignment, the constraint is re-checked.

### TmuxChromeRenderer

Draws the tmux visual chrome:

- **Pane borders**: `CALayer.borderWidth = 1.0` on each pane layer (GPU-composited, zero rasterization cost, implicitly animatable)
  - Dark mode: cyan (`#00d7ff`, tmux default `colour51`) for active pane, `#444444` for others
  - Light mode: gray borders
- **Active pane**: One pane is designated "active" at random. The active pane rotates to a new random pane every 15-30 seconds (uniform random) to prevent a fixed visual hot spot.
- **Status bar**: spans full screen width at bottom, muted background `#1e2030` with light text (not bright green — too visually dominant for a screensaver)
  - Left: `[project] 0:claude*  1:claude-  2:claude  3:claude` (named session, `-` flag on previous window)
  - Right: `%H:%M %d-%b-%Y` (time and date only, no hostname — tmux default has no hostname, four-digit year)
- **No pane number flashing.** The `display-panes` overlay is an interactive affordance that serves no purpose in a non-interactive screensaver.

## 2. Bundled Session Corpus

20-30 `.jsonl` files in the real Claude Code format, generated by running actual Claude Code sessions and saving the output. Each represents a complete coding session.

**Session themes:**

- Building a REST API with Express
- Fixing a React component bug
- Writing unit tests for a Python module
- Refactoring a database schema
- Setting up a CI/CD pipeline
- Debugging a memory leak
- Adding authentication to a web app
- Writing a CLI tool in Rust
- Migrating a codebase to TypeScript
- Optimizing SQL query performance
- Building a WebSocket server
- Writing documentation
- Code review and refactoring
- Setting up Docker containers
- Implementing a search feature

Each session is 50-200 events long, providing 2-10 minutes of content at realistic playback speed. All bundled sessions use ASCII-safe file paths and content to avoid wide-character rendering issues.

## 3. Preferences Panel

Accessible from System Settings > Screen Saver > Options.

**Controls:**

| Control | Type | Default | Range |
|---------|------|---------|-------|
| Color scheme | Segmented control | Dark | Dark / Light |
| Pane density | Slider | Medium (5-8) | Sparse (3-4) to Dense (8-12) |
| Use real sessions | Checkbox | **Off** | — |
| Session directory | Path picker (NSOpenPanel) | `~/.claude/projects/` | Any directory (stored as security-scoped bookmark) |
| Evolution speed | Slider | Medium (60-90s) | Calm (90-120s) to Active (30-60s) |

**Privacy warning:** When "Use real sessions" is toggled on, display a one-time alert: "Real sessions may contain file paths, API keys, and other sensitive content. This content will be visible on screen when the screensaver is active."

**Preferences storage:** Typed `Codable` struct encoded to `Data`, stored as a single key in `ScreenSaverDefaults`. Session directory persisted as a security-scoped bookmark URL via `URL.bookmarkData(options: .withSecurityScope)`.

**OLED-safe mode:** Checkbox (default: off). When enabled: dims all static chrome elements to 50% opacity, forces evolution speed to Active range, and applies a 2px periodic pixel shift to the entire composition every 30 seconds.

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

**Code signing:** Developer ID Application certificate, hardened runtime enabled. Notarized via `notarytool` with stapling. Test with SIP enabled — never test screensavers with SIP off.

**Installation:** Users must move the `.saver` to `~/Library/Screen Savers/` or `/Library/Screen Savers/` before double-clicking to avoid App Translocation (which causes `ScreenSaverDefaults` to fail to persist). Document this in README.

## 5. Performance

**Target frame rate:** Default 30fps via `animationTimeInterval`. On battery: 15fps. In preview mode: 15fps.

**Per-frame work:**

- Record `CACurrentMediaTime()`, compute `deltaTime` (clamped to 0-200ms to prevent catch-up bursts after system sleep)
- Advance each `SessionPlayer` by `deltaTime`
- For each pane with dirty lines: update only the changed `CATextLayer` line instances within a `CATransaction` with disabled actions
- Cursor blink: accumulate `deltaTime`, toggle visibility when accumulated time exceeds 530ms
- Spinner advance: accumulate `deltaTime`, advance frame when accumulated time exceeds 100ms

**Threading model:**

- `animateOneFrame()` runs on the animation thread (main thread in default `ScreenSaverView` config)
- JSONL file discovery and parsing run on a dedicated background `DispatchQueue`
- Pre-parsed events are consumed via a thread-safe ring buffer
- All `CALayer` property mutations happen within `CATransaction` blocks on the animation thread

**Memory:** ~200 lines * ~120 chars * 12 panes = ~288KB of text buffer. JSONL files read line-by-line via `FileHandle` with manual line buffering (not loaded into memory).

## 6. Testing Strategy

**Protocol abstractions enabling testability:**

```swift
protocol SessionDataSource {
    func events(for sessionID: SessionID) -> AsyncThrowingStream<SessionEvent, Error>
}

protocol AnimationClock {
    var currentTime: TimeInterval { get }
}

protocol LayoutMetricsProvider {
    var screenBounds: CGRect { get }
}
```

**Unit tests:**

- `TmuxLayoutEngine`: split/close/resize produce valid layouts, constraints respected, pane counts stay in bounds
- `SessionPlayer`: JSONL parsing for all event types including unknown types (silently skipped), malformed lines (skipped), timing calculations against mock clock
- `TerminalRenderer`: attributed string generation for each UI element type, line-buffer dirty tracking
- Color scheme application
- Preferences `Codable` round-trip including security-scoped bookmark serialization

**Integration tests:**

- Full animation loop with mock `AnimationClock`: verify line layers update correctly with delta-time
- Layout evolution: verify pane count stays in bounds over 1000 mutations
- Session cycling: verify panes pick new sessions when current ones end, no adjacent duplicates

**End-to-end tests:**

- Build and install `.saver` bundle
- Verify it loads in System Settings preview without excessive CPU usage
- Verify preferences panel opens, persists settings across screensaver restarts, and survives reboot
- Verify multi-display: two instances show different content
- Verify battery mode: reduced pane count and frame rate
