# Expert Panel Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the critical and important issues identified by the 7-expert review panel.

**Architecture:** Surgical fixes to existing files — no new components. The biggest theme is caching expensive objects, removing dead code, and fixing the stringly-typed line dispatch.

**Tech Stack:** Swift 5.9+, macOS 14+, existing Xcode project

**Spec:** `docs/superpowers/specs/2026-03-25-claude-code-screensaver-design.md`

---

## Overview

28 findings from 7 experts. This plan addresses the 16 critical + important issues. Minor issues are noted but deferred.

**Grouped into 8 tasks:**

1. **Hot-path caching** — DateFormatter, CTFont, boldFont, NSColor (findings 5-8)
2. **Typed terminal lines** — Replace stringly-typed convertLine with typed model (findings 10, 19)
3. **Dead code removal** — ThreadSafeBuffer, protocols, mocks, ghost feature UI (findings 1, 2, 17)
4. **configureSheet retain** — Hold strong reference to window (finding 3)
5. **displaySeed fix** — Move screen detection to startAnimation (finding 4)
6. **contentsScale fix** — Use window?.screen instead of NSScreen.main (finding 12)
7. **Border gap geometry** — Layout engine leaves gaps for border characters (findings 11, 13)
8. **Multi-content parser** — Parse all content blocks, not just first (finding 14)

---

## Task 1: Hot-Path Caching (Performance Critical)

**Files:**
- Modify: `ClaudeCodeScreenSaver/Rendering/TmuxChromeRenderer.swift`
- Modify: `ClaudeCodeScreenSaver/Rendering/AttributedStringBuilder.swift`
- Modify: `ClaudeCodeScreenSaver/View/ClaudeCodeScreenSaverView.swift`

- [ ] **Step 1: Cache DateFormatter as stored property on TmuxChromeRenderer**

In `TmuxChromeRenderer.swift`, change `statusBarRightText()` to use a cached formatter:

```swift
private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "HH:mm dd-MMM-yyyy"
    return f
}()

func statusBarRightText() -> String {
    Self.dateFormatter.string(from: Date())
}
```

- [ ] **Step 2: Cache boldFont as stored let on AttributedStringBuilder**

In `AttributedStringBuilder.swift`, change `boldFont` from computed var to stored let:

```swift
struct AttributedStringBuilder {
    let theme: ThemeColors
    let font: CTFont
    let nsFont: NSFont
    let boldFont: NSFont
    let cachedColors: CachedColors

    struct CachedColors {
        let promptChevron: NSColor
        let userInput: NSColor
        let responseText: NSColor
        let thinkingSpinner: NSColor
        let toolName: NSColor
        let toolBorder: NSColor
        let successOutput: NSColor
        let errorOutput: NSColor
    }

    init(theme: ThemeColors, font: CTFont) {
        self.theme = theme
        self.font = font
        self.nsFont = font as NSFont
        self.boldFont = NSFontManager.shared.convert(font as NSFont, toHaveTrait: .boldFontMask)
        self.cachedColors = CachedColors(
            promptChevron: NSColor(hex: theme.promptChevron),
            userInput: NSColor(hex: theme.userInput),
            responseText: NSColor(hex: theme.responseText),
            thinkingSpinner: NSColor(hex: theme.thinkingSpinner),
            toolName: NSColor(hex: theme.toolName),
            toolBorder: NSColor(hex: theme.toolBorder),
            successOutput: NSColor(hex: theme.successOutput),
            errorOutput: NSColor(hex: theme.errorOutput)
        )
    }
```

Update all methods to use `cachedColors.X` instead of `NSColor(hex: theme.X)`.

- [ ] **Step 3: Cache status bar font in ClaudeCodeScreenSaverView**

In `ClaudeCodeScreenSaverView.swift`, add a stored property:

```swift
private var statusBarFont: NSFont?
```

In `startAnimation()`, store it:
```swift
let statusFont = CTFontCreateWithName("Menlo" as CFString, 11.0, nil)
statusBarFont = statusFont as NSFont
```

In `updateStatusBarTime()`, use it:
```swift
guard let rightLayer = statusBarRightLayer, let chrome = chromeRenderer, let font = statusBarFont else { return }
```

- [ ] **Step 4: Run tests, verify pass**

- [ ] **Step 5: Commit**

```bash
git commit -m "perf: cache DateFormatter, boldFont, NSColor, and status bar font"
```

---

## Task 2: Typed Terminal Lines (Architecture Fix)

**Files:**
- Create: `ClaudeCodeScreenSaver/Models/TerminalLine.swift`
- Modify: `ClaudeCodeScreenSaver/Engine/SessionPlayer.swift`
- Modify: `ClaudeCodeScreenSaver/View/PaneController.swift`

- [ ] **Step 1: Create TerminalLine enum**

```swift
// Models/TerminalLine.swift
// ABOUTME: Typed terminal line model carrying semantic type alongside text content.
// ABOUTME: Eliminates stringly-typed prefix parsing in PaneController.

import Foundation

enum TerminalLine: Equatable {
    case prompt(text: String)
    case response(text: String)
    case toolCallHeader(text: String)
    case toolResultContent(text: String)
    case toolBlockBottom(text: String)
    case thinking(text: String)
    case empty
}
```

- [ ] **Step 2: Change SessionPlayer.visibleLines to return [TerminalLine]**

Change `allLines` from `[String]` to `[TerminalLine]`. Update `updateLinesForTyping` to emit typed lines:
- Prompt typing: `.prompt(text:)`
- Response typing: `.response(text:)`
- Tool call typing: `.toolCallHeader(text:)`
- Tool result: `.toolResultContent(text:)`

Update `visibleLines` return type to `[TerminalLine]`.

- [ ] **Step 3: Update PaneController to use typed dispatch**

Replace `convertLine(_ text: String)` with:

```swift
private func convertLine(_ line: TerminalLine) -> NSAttributedString {
    switch line {
    case .prompt(let text):
        return stringBuilder.promptLine(text: text)
    case .response(let text):
        return stringBuilder.responseLine(text: text)
    case .toolCallHeader(let text):
        return stringBuilder.toolCallHeader(tool: "", args: text)
    case .toolResultContent(let text):
        return stringBuilder.toolResultLine(text: text)
    case .toolBlockBottom(let text):
        return stringBuilder.toolBlockBottom(width: text.count)
    case .thinking(let text):
        return stringBuilder.thinkingLine(frameIndex: currentSpinnerFrame(text))
    case .empty:
        return stringBuilder.responseLine(text: "")
    }
}
```

- [ ] **Step 4: Only convert changed lines**

In `PaneController.advance()`, cache previous `[TerminalLine]` and only call `convertLine` for lines that differ:

```swift
let newLines = player.visibleLines
var attributedLines: [NSAttributedString] = []
for (i, line) in newLines.enumerated() {
    if i < previousLines.count && previousLines[i] == line {
        attributedLines.append(previousAttributed[i])
    } else {
        attributedLines.append(convertLine(line))
    }
}
previousLines = newLines
previousAttributed = attributedLines
```

- [ ] **Step 5: Update tests for new return type**

Update `SessionPlayerTests` to check for `TerminalLine` instead of `String`.

- [ ] **Step 6: Run all tests, verify pass**

- [ ] **Step 7: Commit**

```bash
git commit -m "refactor: replace stringly-typed lines with TerminalLine enum"
```

---

## Task 3: Dead Code Removal

**Files:**
- Delete: `ClaudeCodeScreenSaver/Engine/ThreadSafeBuffer.swift`
- Delete: `ClaudeCodeScreenSaver/Protocols/SessionDataSource.swift`
- Delete: `ClaudeCodeScreenSaver/Protocols/AnimationClock.swift`
- Delete: `ClaudeCodeScreenSaver/Protocols/LayoutMetricsProvider.swift`
- Delete: `ClaudeCodeScreenSaver/Helpers/SystemAnimationClock.swift`
- Delete: `ClaudeCodeScreenSaverTests/Engine/ThreadSafeBufferTests.swift`
- Delete: `ClaudeCodeScreenSaverTests/Mocks/MockAnimationClock.swift`
- Delete: `ClaudeCodeScreenSaverTests/Mocks/MockSessionDataSource.swift`
- Delete: `ClaudeCodeScreenSaverTests/Mocks/MockLayoutMetrics.swift`
- Modify: `ClaudeCodeScreenSaver/Models/Preferences.swift` — remove `useRealSessions` and `sessionDirectoryBookmark`
- Modify: `ClaudeCodeScreenSaver/View/PreferencesController.swift` — remove real sessions checkbox and privacy warning
- Modify: `ClaudeCodeScreenSaver/Engine/TmuxLayoutEngine.swift` — remove `rotateActivePane()` and duplicate `setActive` overload
- Modify: `ClaudeCodeScreenSaver/Rendering/TerminalRenderer.swift` — remove `resize(to:)` stub

- [ ] **Step 1: Remove dead protocol/mock/buffer files**

Delete all 9 files listed above. Remove their references from `project.pbxproj`.

- [ ] **Step 2: Remove ghost feature from Preferences**

In `Preferences.swift`, remove:
```swift
var useRealSessions: Bool = false
var sessionDirectoryBookmark: Data? = nil
```

In `PreferencesController.swift`, remove the real sessions checkbox, privacy warning alert, and path picker.

- [ ] **Step 3: Remove dead methods**

In `TmuxLayoutEngine.swift`: remove `rotateActivePane()` and the `setActive(id:in:)` overload (keep only `setActive(id:active:in:)`).

In `TerminalRenderer.swift`: remove `resize(to:)`.

In `Preferences.swift`: remove `paneDensityMin` (never read).

- [ ] **Step 4: Run all tests, verify pass** (test count will drop — that's expected)

- [ ] **Step 5: Commit**

```bash
git commit -m "chore: remove dead code (ThreadSafeBuffer, protocols, mocks, ghost features)"
```

---

## Task 4: configureSheet Window Retention

**Files:**
- Modify: `ClaudeCodeScreenSaver/View/ClaudeCodeScreenSaverView.swift`

- [ ] **Step 1: Add stored property for preferences window**

```swift
private var preferencesWindow: NSWindow?
```

- [ ] **Step 2: Update configureSheet to retain the window**

```swift
public override var configureSheet: NSWindow? {
    if preferencesWindow == nil {
        let controller = PreferencesController(bundleIdentifier: Self.bundleID)
        let window = NSWindow(contentViewController: controller)
        window.title = "Claude Code Screensaver"
        preferencesWindow = window
    }
    return preferencesWindow
}
```

- [ ] **Step 3: Run tests, verify pass**

- [ ] **Step 4: Commit**

```bash
git commit -m "fix: retain configureSheet window to prevent deallocation"
```

---

## Task 5: displaySeed Fix (Move to startAnimation)

**Files:**
- Modify: `ClaudeCodeScreenSaver/View/ClaudeCodeScreenSaverView.swift`

- [ ] **Step 1: Move screen detection from commonInit to startAnimation**

In `commonInit()`, remove the `displaySeed` block. In `startAnimation()`, add it after `super.startAnimation()`:

```swift
// Derive seed from screen — window is available now (not during init)
if let screenNumber = window?.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 {
    displaySeed = UInt64(screenNumber)
} else {
    displaySeed = UInt64(bitPattern: Int64(frame.origin.x.hashValue &+ frame.origin.y.hashValue))
}
```

- [ ] **Step 2: Run tests, verify pass**

- [ ] **Step 3: Commit**

```bash
git commit -m "fix: move displaySeed to startAnimation where window is available"
```

---

## Task 6: contentsScale Fix

**Files:**
- Modify: `ClaudeCodeScreenSaver/Rendering/TerminalRenderer.swift`
- Modify: `ClaudeCodeScreenSaver/Rendering/TmuxChromeRenderer.swift`
- Modify: `ClaudeCodeScreenSaver/View/ClaudeCodeScreenSaverView.swift`

- [ ] **Step 1: Pass backingScaleFactor as parameter instead of reading NSScreen.main**

In `TerminalRenderer.init`, accept a `scale: CGFloat` parameter instead of reading `NSScreen.main`:

```swift
init(frame: CGRect, theme: ThemeColors, scale: CGFloat = 2.0) {
    // Use passed scale instead of NSScreen.main?.backingScaleFactor
```

In `TmuxChromeRenderer.createStatusBarLayer`, accept a `scale: CGFloat` parameter.

In `ClaudeCodeScreenSaverView.startAnimation()`, compute scale once from `window?.screen`:

```swift
let scale = window?.screen?.backingScaleFactor ?? 2.0
```

Pass this scale to all renderers and border layer creation.

- [ ] **Step 2: Run tests, verify pass**

- [ ] **Step 3: Commit**

```bash
git commit -m "fix: use window.screen.backingScaleFactor instead of NSScreen.main"
```

---

## Task 7: Border Gap Geometry

**Files:**
- Modify: `ClaudeCodeScreenSaver/Engine/TmuxLayoutEngine.swift`
- Modify: `ClaudeCodeScreenSaver/View/ClaudeCodeScreenSaverView.swift`
- Modify: `ClaudeCodeScreenSaver/Rendering/BorderRenderer.swift`

- [ ] **Step 1: Make TmuxLayoutEngine leave 1-char gaps for borders**

When computing child frames in `splitFrame()`, subtract `charAdvance` (vertical split) or `lineHeight` (horizontal split) from the available space and leave the gap between children:

```swift
// For a vertical split (left/right), leave charAdvance gap:
let leftWidth = floor((frame.width - charAdvance) * ratio)
let rightWidth = frame.width - leftWidth - charAdvance
// Left child: x=frame.minX, width=leftWidth
// Gap: x=frame.minX+leftWidth, width=charAdvance
// Right child: x=frame.minX+leftWidth+charAdvance, width=rightWidth
```

This requires passing `charAdvance` and `lineHeight` to the engine at init time.

- [ ] **Step 2: Update BorderRenderer to find borders at actual gaps**

With real gaps, `BorderRenderer.computeSegments` can use simple gap detection instead of the current heuristic alignment fallbacks. Simplify the border detection to check for gaps of exactly `charAdvance` or `lineHeight` between adjacent pane edges.

- [ ] **Step 3: Fix totalBounds parameter**

In `ClaudeCodeScreenSaverView.renderBorders()`, pass the actual `paneBounds` (the full pane area) instead of `layouts.first?.frame`:

```swift
totalBounds: paneBounds,
```

Store `paneBounds` as a property so it's available in `updateBorderHighlights()` too.

- [ ] **Step 4: Update TmuxLayoutEngine tests for new gap-aware behavior**

Update minimum size test to account for gaps. Update bounds containment test.

- [ ] **Step 5: Run all tests, verify pass**

- [ ] **Step 6: Commit**

```bash
git commit -m "fix: layout engine leaves gaps for border characters"
```

---

## Task 8: Multi-Content Block Parser

**Files:**
- Modify: `ClaudeCodeScreenSaver/Engine/SessionParser.swift`
- Modify: `ClaudeCodeScreenSaverTests/Engine/SessionParserTests.swift`

- [ ] **Step 1: Write failing test for multi-block assistant message**

```swift
func testParseMultiContentAssistantMessage() {
    let line = #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"thinking","thinking":"hmm"},{"type":"text","text":"Here's the fix."}]}}"#
    let events = SessionParser.parseAllFromLine(line)
    XCTAssertEqual(events.count, 2)
    XCTAssertEqual(events[0], .thinking(durationHint: nil))
    XCTAssertEqual(events[1], .assistantText(text: "Here's the fix."))
}
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Add parseAllFromLine that returns [SessionEvent]**

Change `parseAssistantMessage` to collect ALL content blocks, not just the first:

```swift
static func parseAllFromLine(_ line: String) -> [SessionEvent] {
    // Same JSON parsing setup...
    // For assistant messages, iterate ALL content items and collect events
}
```

Update `parseFile` to use `flatMap` with `parseAllFromLine` instead of `compactMap` with `parseLine`.

Keep `parseLine` as a convenience that returns the first event (backward compatible).

- [ ] **Step 4: Run tests, verify pass**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat: parse all content blocks from assistant messages"
```

---

## Deferred (Minor Issues — Not in This Plan)

- Mark renderers as `final class` (#24)
- Add Cancel button to preferences (#27)
- Guard evolution speed range for corrupt prefs (#28)
- Add `seededRandom` to session selection (#15 — partial, needs more design)
- Remove `SplitAxis` naming confusion (#26)
- Fix sublayer index assumption for status bar (#25)
- Fix `resize(to:)` — removed in Task 3 instead
- Various test quality improvements (#18, 19, 20)
