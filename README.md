# Code Agent Screensaver

A native macOS screensaver that displays a grid of simulated Code Agent terminal instances in a tmux-style layout, all appearing to actively work on coding tasks.

## What It Looks Like

A full-screen tmux session with 5-8 panes, each showing a Code Agent instance reading files, writing code, running tests, and thinking through problems. Text-character borders with proper junction characters. A status bar at the bottom with session name and timestamp. Panes slowly split, close, and resize over time.

## Install (Download)

1. Download `ClaudeCodeScreenSaver.saver.zip` from [Releases](../../releases)
2. Unzip it
3. Move `ClaudeCodeScreenSaver.saver` to `~/Library/Screen Savers/` (important — do this *before* double-clicking to avoid App Translocation issues)
4. Open **System Settings > Screen Saver** and select it

## Install (Build from Source)

Requirements: macOS 14.0+ (Sonoma), Xcode 15.0+

```bash
make install
```

Or manually:

```bash
make build
cp -R ~/Library/Developer/Xcode/DerivedData/ClaudeCodeScreenSaver-*/Build/Products/Release/ClaudeCodeScreenSaver.saver ~/Library/Screen\ Savers/
```

Then open **System Settings > Screen Saver** and select "ClaudeCodeScreenSaver".

## Preferences

Click **Options** in System Settings to configure:

| Setting | Default | Description |
|---------|---------|-------------|
| Color Scheme | Dark | Dark or Light terminal theme |
| Pane Density | 5-8 | Number of terminal panes (3-12) |
| Use Real Sessions | Off | Replay your actual Code Agent sessions |
| Evolution Speed | 60-90s | How often panes split/close/resize |
| OLED-Safe Mode | Off | Dims chrome and shifts pixels to prevent burn-in |

### Privacy Note

When "Use Real Sessions" is enabled, the screensaver replays content from your `~/.claude/projects/` directory. This may include file paths, code snippets, and other sensitive content visible on screen while the screensaver is active.

## Testing

```bash
make test
```

## Architecture

- **ScreenSaverView** subclass with Core Animation rendering
- Per-line `CATextLayer` for terminal content (dirty-line tracking, no full rebuilds)
- Delta-time animation model (no fixed frame rate assumptions)
- Binary tree layout engine for tmux-style pane management
- JSONL session parser for Code Agent replay format
- Text-character borders with junction characters
- Protocol abstractions for testability

See `docs/superpowers/specs/` for the full design spec and `docs/superpowers/plans/` for the implementation plan.

## License

MIT
