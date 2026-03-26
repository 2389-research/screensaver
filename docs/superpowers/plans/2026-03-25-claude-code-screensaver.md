# Claude Code Screensaver Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS `.saver` screensaver that displays a grid of simulated Claude Code terminal instances in a tmux-style layout.

**Architecture:** Native Swift `ScreenSaverView` subclass using Core Animation. Per-line `CATextLayer` rendering with delta-time animation model. JSONL session replay on background queue. Protocol abstractions for all external dependencies. Pane borders rendered as text characters in the monospace grid (not `CALayer.borderWidth`).

**Tech Stack:** Swift 5.9+, macOS 14+ SDK, ScreenSaver.framework, QuartzCore (Core Animation), CoreText, IOKit (power source detection)

**Spec:** `docs/superpowers/specs/2026-03-25-claude-code-screensaver-design.md`

**Key constraint — visuals first:** This plan frontloads visual output. A working visual prototype exists by Task 2. Infrastructure is built to support what you've already seen on screen, not the other way around.

---

## File Structure

```
ClaudeCodeScreenSaver/
  ClaudeCodeScreenSaver.xcodeproj/
  LICENSE                               -- MIT license
  ClaudeCodeScreenSaver/
    Info.plist
    Helpers/
      NSColor+Hex.swift                 -- NSColor hex string extension (AppKit)
      SystemAnimationClock.swift        -- CACurrentMediaTime() wrapper (QuartzCore)
      PreferencesStorage.swift          -- ScreenSaverDefaults load/save (ScreenSaver.framework)
    Protocols/
      AnimationClock.swift              -- TimeInterval provider protocol (Foundation only)
      SessionDataSource.swift           -- Async session event stream protocol (Foundation only)
      LayoutMetricsProvider.swift       -- Screen bounds protocol (Foundation only)
    Models/
      SessionEvent.swift                -- Parsed JSONL event types (Foundation only)
      PaneLayout.swift                  -- Pane frame + ID + isActive (Foundation only)
      ThemeColors.swift                 -- Color values as hex strings (Foundation only)
      Preferences.swift                 -- Codable preferences struct (Foundation only)
    Engine/
      TmuxLayoutEngine.swift            -- Binary tree pane layout
      SessionPlayer.swift               -- JSONL replay state machine
      SessionParser.swift               -- Background JSONL line parser
      ThreadSafeBuffer.swift            -- Ring buffer for cross-thread event delivery
    Rendering/
      TerminalRenderer.swift            -- Per-line CATextLayer grid
      TmuxChromeRenderer.swift          -- Text-character borders, status bar
      BorderRenderer.swift              -- Junction-aware border character grid
      FontMetrics.swift                 -- CTFont measurement + caching
      AttributedStringBuilder.swift     -- NSAttributedString factories for each UI element
    View/
      ClaudeCodeScreenSaverView.swift   -- ScreenSaverView subclass (entry point)
      PaneController.swift              -- Owns renderer + chrome + player per pane
      PreferencesController.swift       -- configureSheet() panel
    Resources/
      Sessions/
        build-rest-api.jsonl
        ... (bundled sessions)
  ClaudeCodeScreenSaverTests/
    Engine/
      TmuxLayoutEngineTests.swift
      SessionPlayerTests.swift
      SessionParserTests.swift
      ThreadSafeBufferTests.swift
    Rendering/
      FontMetricsTests.swift
      AttributedStringBuilderTests.swift
      TerminalRendererTests.swift
      TmuxChromeRendererTests.swift     -- NOT optional
      BorderRendererTests.swift
    Models/
      PreferencesTests.swift
      SessionEventTests.swift
    Integration/
      AnimationLoopTests.swift
      LayoutEvolutionTests.swift
      SessionCyclingTests.swift
      StartupStaggerTests.swift
      BatteryModeTests.swift
    Mocks/
      MockAnimationClock.swift
      MockSessionDataSource.swift
      MockLayoutMetrics.swift
```

**Platform isolation:** Files in `Protocols/`, `Models/`, and `Engine/` import only `Foundation`. All AppKit/QuartzCore/ScreenSaver.framework imports are confined to `Helpers/`, `Rendering/`, and `View/`. This means the parser, layout engine, state machine, ring buffer, preferences struct, and color model can be tested without Apple-specific frameworks.

---

## Task 1: Visual Prototype (Proof of Concept)

**Purpose:** Get pixels on screen immediately. Validate that per-line `CATextLayer` on `#1e1e2e` background with text-character borders looks correct on real hardware before building infrastructure.

**Files:**
- Create: `ClaudeCodeScreenSaver.xcodeproj` (Xcode Screen Saver bundle target + test target)
- Create: `ClaudeCodeScreenSaver/Info.plist`
- Create: `ClaudeCodeScreenSaver/View/ClaudeCodeScreenSaverView.swift` (minimal prototype)
- Create: `ClaudeCodeScreenSaver/Helpers/NSColor+Hex.swift`
- Create: `LICENSE`

- [ ] **Step 1: Create Xcode project**

Create a new Xcode project with the "Screen Saver" template. Bundle identifier: `com.2389.ClaudeCodeScreenSaver`. Deployment target: macOS 14.0. Add a unit test target `ClaudeCodeScreenSaverTests`.

- [ ] **Step 2: Write NSColor hex extension**

```swift
// Helpers/NSColor+Hex.swift
// ABOUTME: Extension adding hex string initializer to NSColor.
// ABOUTME: Parses "#RRGGBB" format strings into sRGB NSColor values.

import AppKit

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        self.init(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
```

- [ ] **Step 3: Write minimal prototype ScreenSaverView**

A throwaway implementation that hardcodes 4 panes with static colored text. Each pane has:
- `#1e1e2e` background
- 5 `CATextLayer` lines with sample Claude Code content (prompt in `#d4a574`, response in `#e0e0e0`, tool block in `#7aa2f7`)
- Text-character borders between panes using `│─┼├┤┬┴` in `#444444`, with cyan `#00d7ff` on one pane
- A status bar `CATextLayer` at the bottom (height = 1 line of monospace font) with `#1e2030` background

No animation, no state machine, no JSONL parsing. Just static layers proving the visual approach works.

- [ ] **Step 4: Write MIT LICENSE file**

- [ ] **Step 5: Build and install**

Run: `xcodebuild build -scheme ClaudeCodeScreenSaver -configuration Debug -destination 'platform=macOS'`
Copy `.saver` to `~/Library/Screen Savers/`. Open System Settings > Screen Saver. Verify it appears, preview renders, and the colors/borders look correct on the actual display.

- [ ] **Step 6: VISUAL QUALITY GATE**

**Watch the preview for 2 minutes.** Evaluate:
- Does `#1e1e2e` background look right in dark room? Too blue? Too dark?
- Are text-character borders visible and correct at junction points?
- Is the status bar height (1 line) proportional?
- Is 9pt Menlo readable in the smallest pane?
- Does the cyan active border pop without being garish?

Adjust colors/sizing based on what you see before proceeding.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: visual prototype with static panes and text-character borders"
```

---

## Task 2: Protocols + Models (Foundation-Only)

**Files:**
- Create: `ClaudeCodeScreenSaver/Protocols/AnimationClock.swift`
- Create: `ClaudeCodeScreenSaver/Protocols/SessionDataSource.swift`
- Create: `ClaudeCodeScreenSaver/Protocols/LayoutMetricsProvider.swift`
- Create: `ClaudeCodeScreenSaver/Models/SessionEvent.swift`
- Create: `ClaudeCodeScreenSaver/Models/PaneLayout.swift`
- Create: `ClaudeCodeScreenSaver/Models/ThemeColors.swift`
- Create: `ClaudeCodeScreenSaver/Models/Preferences.swift`
- Create: `ClaudeCodeScreenSaver/Helpers/SystemAnimationClock.swift`
- Create: `ClaudeCodeScreenSaverTests/Mocks/MockAnimationClock.swift`
- Create: `ClaudeCodeScreenSaverTests/Mocks/MockSessionDataSource.swift`

- [ ] **Step 1: Write protocol definitions (Foundation only)**

```swift
// Protocols/AnimationClock.swift
// ABOUTME: Protocol abstracting time source for testability.
// ABOUTME: Allows mock clocks in tests to control animation timing.

import Foundation

protocol AnimationClock {
    var currentTime: TimeInterval { get }
}
```

```swift
// Helpers/SystemAnimationClock.swift
// ABOUTME: Production implementation of AnimationClock using CACurrentMediaTime.
// ABOUTME: Isolated in Helpers/ because it requires QuartzCore import.

import QuartzCore

struct SystemAnimationClock: AnimationClock {
    var currentTime: TimeInterval {
        CACurrentMediaTime()
    }
}
```

```swift
// Protocols/SessionDataSource.swift
// ABOUTME: Protocol for providing session event streams from JSONL files.
// ABOUTME: Async to support background parsing without loading full files into memory.

import Foundation

typealias SessionID = String

protocol SessionDataSource {
    var availableSessionIDs: [SessionID] { get }
    func loadEvents(for sessionID: SessionID) async throws -> [SessionEvent]
}
```

```swift
// Protocols/LayoutMetricsProvider.swift
// ABOUTME: Protocol abstracting screen geometry for testability.
// ABOUTME: Allows tests to provide custom screen bounds.

import Foundation

protocol LayoutMetricsProvider {
    var screenBounds: CGRect { get }
}
```

- [ ] **Step 2: Write model types (Foundation only)**

```swift
// Models/SessionEvent.swift
// ABOUTME: Parsed events from Claude Code JSONL session files.
// ABOUTME: Represents all displayable event types the renderer understands.

import Foundation

enum SessionEvent: Equatable {
    case userPrompt(text: String)
    case assistantText(text: String)
    case toolCall(tool: String, args: String)
    case toolResult(content: String)
    case thinking(durationHint: TimeInterval?)
}
```

```swift
// Models/PaneLayout.swift
// ABOUTME: Layout data for a single pane in the tmux grid.
// ABOUTME: Produced by TmuxLayoutEngine, consumed by PaneController.

import Foundation

struct PaneLayout: Identifiable, Equatable {
    let id: UUID
    var frame: CGRect
    var isActive: Bool
}
```

```swift
// Models/ThemeColors.swift
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
```

```swift
// Models/Preferences.swift
// ABOUTME: User-configurable screensaver settings.
// ABOUTME: Foundation-only Codable struct. Storage via ScreenSaverDefaults is in Helpers/PreferencesStorage.swift.

import Foundation

struct Preferences: Codable, Equatable {
    enum ColorSchemeChoice: String, Codable { case dark, light }

    var colorScheme: ColorSchemeChoice = .dark
    var paneDensityMin: Int = 5
    var paneDensityMax: Int = 8
    var useRealSessions: Bool = false
    var sessionDirectoryBookmark: Data? = nil
    var evolutionSpeedMin: TimeInterval = 60
    var evolutionSpeedMax: TimeInterval = 90
    var oledSafeMode: Bool = false
}
```

- [ ] **Step 3: Write mocks**

```swift
// Mocks/MockAnimationClock.swift
// ABOUTME: Test double for AnimationClock protocol.
// ABOUTME: Allows tests to control time progression precisely.

import Foundation
@testable import ClaudeCodeScreenSaver

class MockAnimationClock: AnimationClock {
    var currentTime: TimeInterval = 0.0
    func advance(by interval: TimeInterval) { currentTime += interval }
}
```

```swift
// Mocks/MockSessionDataSource.swift
// ABOUTME: Test double for SessionDataSource protocol.
// ABOUTME: Returns pre-loaded events for testing without JSONL file access.

import Foundation
@testable import ClaudeCodeScreenSaver

class MockSessionDataSource: SessionDataSource {
    var sessions: [SessionID: [SessionEvent]] = [:]
    var availableSessionIDs: [SessionID] { Array(sessions.keys) }
    func loadEvents(for sessionID: SessionID) async throws -> [SessionEvent] {
        sessions[sessionID] ?? []
    }
}
```

- [ ] **Step 4: Verify project builds**

Run: `xcodebuild build -scheme ClaudeCodeScreenSaver -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add protocols, models, and mocks (Foundation-only where possible)"
```

---

## Task 3: ThreadSafeBuffer

**Files:**
- Create: `ClaudeCodeScreenSaver/Engine/ThreadSafeBuffer.swift`
- Create: `ClaudeCodeScreenSaverTests/Engine/ThreadSafeBufferTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Engine/ThreadSafeBufferTests.swift
// ABOUTME: Tests for the thread-safe ring buffer used for cross-thread event delivery.
// ABOUTME: Verifies FIFO ordering, capacity limits, and concurrent access safety.

import XCTest
@testable import ClaudeCodeScreenSaver

final class ThreadSafeBufferTests: XCTestCase {

    func testEnqueueAndDequeue() {
        let buffer = ThreadSafeBuffer<Int>(capacity: 10)
        buffer.enqueue(42)
        XCTAssertEqual(buffer.dequeue(), 42)
    }

    func testDequeueFromEmptyReturnsNil() {
        let buffer = ThreadSafeBuffer<Int>(capacity: 10)
        XCTAssertNil(buffer.dequeue())
    }

    func testFIFOOrder() {
        let buffer = ThreadSafeBuffer<Int>(capacity: 10)
        for i in 1...3 { buffer.enqueue(i) }
        XCTAssertEqual(buffer.dequeue(), 1)
        XCTAssertEqual(buffer.dequeue(), 2)
        XCTAssertEqual(buffer.dequeue(), 3)
    }

    func testCapacityDropsOldest() {
        let buffer = ThreadSafeBuffer<Int>(capacity: 3)
        for i in 1...4 { buffer.enqueue(i) }
        XCTAssertEqual(buffer.dequeue(), 2)
    }

    func testConcurrentAccess() async {
        let buffer = ThreadSafeBuffer<Int>(capacity: 1000)
        await withTaskGroup(of: Void.self) { group in
            group.addTask { for i in 0..<500 { buffer.enqueue(i) } }
            group.addTask { for i in 500..<1000 { buffer.enqueue(i) } }
        }
        var count = 0
        while buffer.dequeue() != nil { count += 1 }
        XCTAssertEqual(count, 1000)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement ThreadSafeBuffer** (same as before — NSLock-based)

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add ThreadSafeBuffer for cross-thread event delivery"
```

---

## Task 4: SessionParser (JSONL Parsing)

Same as original Task 3. Additionally:

- [ ] **Step 1a: Create concrete sample JSONL fixture**

```jsonl
{"type":"user","message":{"role":"user","content":"fix the auth bug"}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"thinking","thinking":"analyzing..."}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"I'll fix the auth middleware."}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Read","input":{"file_path":"src/auth.ts"}}]}}
{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":"export function auth() {}"}]}}
{"type":"file-history-snapshot","snapshot":{}}
{"type":"progress","data":{}}
this is malformed json
{"type":"user","isMeta":true,"message":{"role":"user","content":"meta"}}
{"type":"assistant","isApiErrorMessage":true,"message":{"role":"assistant","content":[{"type":"text","text":"error"}]}}
```

All remaining steps same as original Task 3.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add SessionParser for JSONL line-by-line parsing"
```

---

## Task 5: FontMetrics + AttributedStringBuilder

**Files:**
- Create: `ClaudeCodeScreenSaver/Rendering/FontMetrics.swift`
- Create: `ClaudeCodeScreenSaver/Rendering/AttributedStringBuilder.swift`
- Create: `ClaudeCodeScreenSaverTests/Rendering/FontMetricsTests.swift`
- Create: `ClaudeCodeScreenSaverTests/Rendering/AttributedStringBuilderTests.swift`

- [ ] **Step 1: Write failing FontMetrics tests**

Test cols/rows from a given rect, 9pt floor, 14pt ceiling. Test that minimum pane (40 cols at 9pt) produces a known char advance width.

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement FontMetrics (with fixed measureCharAdvance)**

```swift
// Rendering/FontMetrics.swift
// ABOUTME: Computes monospace font metrics (char advance, line height, cols, rows) for a pane.
// ABOUTME: Uses CTFont for precise glyph measurement. Caches per pane size.

import Foundation
import CoreText

struct FontMetrics: Equatable {
    let font: CTFont
    let fontSize: CGFloat
    let charAdvance: CGFloat
    let lineHeight: CGFloat
    let cols: Int
    let rows: Int

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
```

- [ ] **Step 4: Run FontMetrics tests, verify pass**

- [ ] **Step 5: Write failing AttributedStringBuilder tests**

```swift
// Rendering/AttributedStringBuilderTests.swift
// ABOUTME: Tests for NSAttributedString generation for each Claude Code UI element.
// ABOUTME: Verifies colors, bold attributes, and correct character content.

import XCTest
import AppKit
@testable import ClaudeCodeScreenSaver

final class AttributedStringBuilderTests: XCTestCase {

    let darkTheme = ThemeColors.dark
    let font = CTFontCreateWithName("Menlo" as CFString, 12.0, nil)

    func testPromptLine() {
        let builder = AttributedStringBuilder(theme: darkTheme, font: font)
        let result = builder.promptLine(text: "fix the bug")
        let string = result.string
        XCTAssertTrue(string.hasPrefix("\u{276F}")) // U+276F chevron
        XCTAssertTrue(string.contains("fix the bug"))
        // Verify bold on user input portion
        let attrs = result.attributes(at: string.count - 1, effectiveRange: nil)
        let nsFont = attrs[.font] as! NSFont
        XCTAssertTrue(nsFont.fontDescriptor.symbolicTraits.contains(.bold))
    }

    func testResponseText() {
        let builder = AttributedStringBuilder(theme: darkTheme, font: font)
        let result = builder.responseLine(text: "I'll fix that.")
        let attrs = result.attributes(at: 0, effectiveRange: nil)
        let color = attrs[.foregroundColor] as! NSColor
        XCTAssertEqual(color, NSColor(hex: darkTheme.responseText))
    }

    func testToolCallHeader() {
        let builder = AttributedStringBuilder(theme: darkTheme, font: font)
        let result = builder.toolCallHeader(tool: "Read", args: "src/auth.ts")
        let string = result.string
        XCTAssertTrue(string.contains("\u{256D}")) // rounded corner top-left
        XCTAssertTrue(string.contains("Read"))
    }

    func testThinkingSpinner() {
        let builder = AttributedStringBuilder(theme: darkTheme, font: font)
        let spinnerChars = ["⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"]
        for (i, expected) in spinnerChars.enumerated() {
            let result = builder.thinkingLine(frameIndex: i)
            XCTAssertTrue(result.string.contains(expected))
        }
    }

    func testSuccessOutput() {
        let builder = AttributedStringBuilder(theme: darkTheme, font: font)
        let result = builder.outputLine(text: "PASS", isSuccess: true)
        let attrs = result.attributes(at: 0, effectiveRange: nil)
        let color = attrs[.foregroundColor] as! NSColor
        XCTAssertEqual(color, NSColor(hex: darkTheme.successOutput))
    }

    func testErrorOutput() {
        let builder = AttributedStringBuilder(theme: darkTheme, font: font)
        let result = builder.outputLine(text: "FAIL", isSuccess: false)
        let attrs = result.attributes(at: 0, effectiveRange: nil)
        let color = attrs[.foregroundColor] as! NSColor
        XCTAssertEqual(color, NSColor(hex: darkTheme.errorOutput))
    }
}
```

- [ ] **Step 6: Implement AttributedStringBuilder**

```swift
// Rendering/AttributedStringBuilder.swift
// ABOUTME: Factory for building NSAttributedString instances for each Claude Code UI element.
// ABOUTME: Handles prompt chevron, response text, tool blocks with box-drawing chars, and spinner.

import AppKit
import CoreText

struct AttributedStringBuilder {
    let theme: ThemeColors
    let font: CTFont
    private var nsFont: NSFont { font as NSFont }
    private var boldFont: NSFont {
        NSFontManager.shared.convert(nsFont, toHaveTrait: .boldFontMask)
    }

    func promptLine(text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: "\u{276F} ",
            attributes: [.font: boldFont, .foregroundColor: NSColor(hex: theme.promptChevron)]))
        result.append(NSAttributedString(string: text,
            attributes: [.font: boldFont, .foregroundColor: NSColor(hex: theme.userInput)]))
        return result
    }

    func responseLine(text: String) -> NSAttributedString {
        NSAttributedString(string: text,
            attributes: [.font: nsFont, .foregroundColor: NSColor(hex: theme.responseText)])
    }

    func toolCallHeader(tool: String, args: String) -> NSAttributedString {
        let header = "\u{256D} \(tool) \(args) "
        let padded = header.padding(toLength: max(header.count, 40), withPad: "\u{2500}", startingAt: 0) + "\u{256E}"
        return NSAttributedString(string: padded,
            attributes: [.font: nsFont, .foregroundColor: NSColor(hex: theme.toolName)])
    }

    func toolResultLine(text: String) -> NSAttributedString {
        let line = "\u{2502} \(text)"
        return NSAttributedString(string: line,
            attributes: [.font: nsFont, .foregroundColor: NSColor(hex: theme.toolBorder)])
    }

    func toolBlockBottom(width: Int) -> NSAttributedString {
        let line = "\u{2570}" + String(repeating: "\u{2500}", count: max(width - 2, 1)) + "\u{256F}"
        return NSAttributedString(string: line,
            attributes: [.font: nsFont, .foregroundColor: NSColor(hex: theme.toolBorder)])
    }

    func thinkingLine(frameIndex: Int) -> NSAttributedString {
        let frames = ["⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"]
        let char = frames[frameIndex % frames.count]
        return NSAttributedString(string: "\(char) Thinking...",
            attributes: [.font: nsFont, .foregroundColor: NSColor(hex: theme.thinkingSpinner)])
    }

    func outputLine(text: String, isSuccess: Bool) -> NSAttributedString {
        let color = isSuccess ? theme.successOutput : theme.errorOutput
        return NSAttributedString(string: text,
            attributes: [.font: nsFont, .foregroundColor: NSColor(hex: color)])
    }
}
```

- [ ] **Step 7: Run all tests, verify pass**

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: add FontMetrics and AttributedStringBuilder with full API"
```

---

## Task 6: TmuxLayoutEngine

Same as original Task 5, with these additions:

- [ ] **Additional test: Split ratio constrained to 40-60%**

```swift
func testSplitRatiosConstrainedTo40_60Percent() {
    let engine = TmuxLayoutEngine(bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                   minPanes: 3, maxPanes: 12, seed: 42)
    // Force several splits
    for _ in 0..<10 { _ = engine.trySplit() }

    let layouts = engine.currentLayouts()
    // Check that no pane is less than 30% or more than 70% of any sibling pair
    // (40-60 split means the smaller side is at least 40% = ratio >= 0.4)
    for layout in layouts {
        let widthRatio = layout.frame.width / 1920
        let heightRatio = layout.frame.height / 1080
        // No single pane should consume > 70% of either dimension after splits
        // (this is a proxy for the 40-60 constraint at each split level)
        XCTAssertLessThanOrEqual(widthRatio, 0.7, "Pane too wide: \(widthRatio)")
        XCTAssertLessThanOrEqual(heightRatio, 0.7, "Pane too tall: \(heightRatio)")
    }
}
```

- [ ] **Fix: Minimum size test uses 9pt floor directly**

```swift
func testMinimumPaneSizeRespected() {
    let engine = TmuxLayoutEngine(bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                   minPanes: 8, maxPanes: 12, seed: 42)
    // Compute minimum dimensions using the 9pt floor font directly
    let floorFont = CTFontCreateWithName("Menlo" as CFString, 9.0, nil)
    var glyphs: [CGGlyph] = [0]
    let chars: [UniChar] = [0x4D]
    CTFontGetGlyphsForCharacters(floorFont, chars, &glyphs, 1)
    var advance = CGSize.zero
    CTFontGetAdvancesForGlyphs(floorFont, .horizontal, glyphs, &advance, 1)
    let minWidth = CGFloat(40) * advance.width
    let lineHeight = CTFontGetAscent(floorFont) + CTFontGetDescent(floorFont) + CTFontGetLeading(floorFont)
    let minHeight = CGFloat(10) * lineHeight

    for layout in engine.currentLayouts() {
        XCTAssertGreaterThanOrEqual(layout.frame.width, minWidth - 1)
        XCTAssertGreaterThanOrEqual(layout.frame.height, minHeight - 1)
    }
}
```

- [ ] **Commit**

```bash
git add -A
git commit -m "feat: add TmuxLayoutEngine with split/close/resize"
```

---

## Task 7: SessionPlayer (Replay State Machine)

Same as original Task 6, with these required additional tests:

- [ ] **Test: Thinking spinner advances at 100ms intervals**

```swift
func testSpinnerAdvancesEvery100ms() {
    let player = SessionPlayer(events: [.thinking(durationHint: nil)], clock: mockClock)
    let frame0 = player.currentSpinnerFrame
    XCTAssertEqual(frame0, 0)

    player.advance(deltaTime: 0.099) // 99ms — should still be frame 0
    XCTAssertEqual(player.currentSpinnerFrame, 0)

    player.advance(deltaTime: 0.001) // now 100ms — advance to frame 1
    XCTAssertEqual(player.currentSpinnerFrame, 1)

    player.advance(deltaTime: 0.9) // 900ms more — should be frame 10 = wraps to 0
    XCTAssertEqual(player.currentSpinnerFrame, 0)
}
```

- [ ] **Test: Tool result fade-in over 300ms**

```swift
func testToolResultFadeIn() {
    let player = SessionPlayer(events: [.toolResult(content: "file contents")], clock: mockClock)
    XCTAssertEqual(player.currentToolResultOpacity, 0.0, accuracy: 0.01)

    player.advance(deltaTime: 0.15) // 150ms = half fade
    XCTAssertEqual(player.currentToolResultOpacity, 0.5, accuracy: 0.05)

    player.advance(deltaTime: 0.15) // 300ms = full
    XCTAssertEqual(player.currentToolResultOpacity, 1.0, accuracy: 0.01)
}
```

- [ ] **Test: Viewport tracks bottom of content**

```swift
func testViewportTracksBottom() {
    // Feed more lines than visible rows
    let longResponse = String(repeating: "line\n", count: 50)
    let player = SessionPlayer(events: [.assistantText(text: longResponse)], clock: mockClock)
    player.visibleRows = 20

    // Advance enough to type all content
    player.advance(deltaTime: 10.0)

    let visibleLines = player.visibleLines
    XCTAssertEqual(visibleLines.count, 20)
    // Last visible line should be the last line of content, not the first
    XCTAssertTrue(visibleLines.last?.string.contains("line") ?? false)
}
```

- [ ] **Commit**

```bash
git add -A
git commit -m "feat: add SessionPlayer with spinner, fade-in, and viewport tracking"
```

---

## Task 8: BorderRenderer (Text-Character Pane Borders)

**Files:**
- Create: `ClaudeCodeScreenSaver/Rendering/BorderRenderer.swift`
- Create: `ClaudeCodeScreenSaverTests/Rendering/BorderRendererTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Rendering/BorderRendererTests.swift
// ABOUTME: Tests for junction-aware text-character border grid generation.
// ABOUTME: Verifies correct junction characters where pane borders meet.

import XCTest
@testable import ClaudeCodeScreenSaver

final class BorderRendererTests: XCTestCase {

    func testTwoPanesVerticalSplitProducesVerticalBorder() {
        let layouts = [
            PaneLayout(id: UUID(), frame: CGRect(x: 0, y: 0, width: 100, height: 200), isActive: false),
            PaneLayout(id: UUID(), frame: CGRect(x: 101, y: 0, width: 100, height: 200), isActive: true)
        ]
        let grid = BorderRenderer.computeBorderGrid(layouts: layouts, totalBounds: CGRect(x: 0, y: 0, width: 201, height: 200))
        // The border column at x=100 should contain │ characters
        XCTAssertTrue(grid.contains("│"))
    }

    func testFourPaneGridProducesCrossJunction() {
        // 2x2 grid should produce ┼ at the center junction
        let layouts = [
            PaneLayout(id: UUID(), frame: CGRect(x: 0, y: 0, width: 100, height: 100), isActive: false),
            PaneLayout(id: UUID(), frame: CGRect(x: 101, y: 0, width: 100, height: 100), isActive: false),
            PaneLayout(id: UUID(), frame: CGRect(x: 0, y: 101, width: 100, height: 100), isActive: true),
            PaneLayout(id: UUID(), frame: CGRect(x: 101, y: 101, width: 100, height: 100), isActive: false)
        ]
        let grid = BorderRenderer.computeBorderGrid(layouts: layouts, totalBounds: CGRect(x: 0, y: 0, width: 201, height: 201))
        XCTAssertTrue(grid.contains("┼"))
    }

    func testTJunctionCharacters() {
        // Three panes in T-shape should produce ├ or ┤ or ┬ or ┴
        // (specific test depends on layout)
        let layouts = [
            PaneLayout(id: UUID(), frame: CGRect(x: 0, y: 0, width: 100, height: 200), isActive: false),
            PaneLayout(id: UUID(), frame: CGRect(x: 101, y: 0, width: 100, height: 100), isActive: true),
            PaneLayout(id: UUID(), frame: CGRect(x: 101, y: 101, width: 100, height: 100), isActive: false)
        ]
        let grid = BorderRenderer.computeBorderGrid(layouts: layouts, totalBounds: CGRect(x: 0, y: 0, width: 201, height: 201))
        let hasJunction = grid.contains("├") || grid.contains("┤") || grid.contains("┬") || grid.contains("┴")
        XCTAssertTrue(hasJunction, "Expected T-junction character in border grid")
    }
}
```

- [ ] **Step 2: Implement BorderRenderer**

Takes an array of `PaneLayout` and the total bounds, computes a grid of border characters at the gaps between panes. Uses `│` (vertical), `─` (horizontal), and the five junction characters (`┼ ├ ┤ ┬ ┴`) based on which directions have adjacent borders at each point. Renders as `CATextLayer` lines overlaid on the pane grid. Active pane's borders use the `paneBorderActive` color; others use `paneBorderInactive`.

- [ ] **Step 3: Run tests, verify pass**

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add BorderRenderer with junction-aware text-character borders"
```

---

## Task 9: TerminalRenderer (Per-Line CATextLayer Grid)

Same as original Task 7, with these required additions:

- [ ] **Test: Cursor X/Y positioning across multiple lines**

```swift
func testCursorPositionedOnCorrectLine() {
    let renderer = TerminalRenderer(frame: CGRect(x: 0, y: 0, width: 500, height: 300), theme: .dark)
    renderer.update(lines: ["line 1", "line 2", "line 3"], cursorPosition: (row: 2, col: 5), deltaTime: 0.0)
    // Cursor layer Y should be at row 2 * lineHeight (accounting for coordinate flip)
    let expectedY = renderer.fontMetrics.lineHeight * 2
    XCTAssertEqual(renderer.cursorLayer.frame.origin.y, expectedY, accuracy: 1.0)
    let expectedX = renderer.fontMetrics.charAdvance * 5
    XCTAssertEqual(renderer.cursorLayer.frame.origin.x, expectedX, accuracy: 1.0)
}
```

- [ ] **Test: Viewport bottom-tracking when content exceeds visible rows**

```swift
func testViewportShowsBottomOfContent() {
    let renderer = TerminalRenderer(frame: CGRect(x: 0, y: 0, width: 500, height: 300), theme: .dark)
    let manyLines = (0..<50).map { "Line \($0)" }
    renderer.update(lines: manyLines, cursorPosition: (row: 49, col: 0), deltaTime: 0.0)
    // The last visible CATextLayer should show "Line 49", not "Line 0"
    let lastLineLayer = renderer.lineLayers.last!
    XCTAssertTrue((lastLineLayer.string as? NSAttributedString)?.string.contains("49") ?? false)
}
```

- [ ] **Commit**

```bash
git add -A
git commit -m "feat: add TerminalRenderer with per-line layers, cursor, and viewport tracking"
```

---

## Task 10: TmuxChromeRenderer (Status Bar) — Tests NOT Optional

**Files:**
- Create: `ClaudeCodeScreenSaver/Rendering/TmuxChromeRenderer.swift`
- Create: `ClaudeCodeScreenSaverTests/Rendering/TmuxChromeRendererTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Rendering/TmuxChromeRendererTests.swift
// ABOUTME: Tests for tmux status bar text, active pane management, and border colors.
// ABOUTME: These tests are NOT optional — tmux chrome authenticity is critical.

import XCTest
@testable import ClaudeCodeScreenSaver

final class TmuxChromeRendererTests: XCTestCase {

    func testStatusBarLeftTextFormat() {
        let chrome = TmuxChromeRenderer(sessionName: "rest-api", windowCount: 4, activeWindow: 0, lastWindow: 1)
        let left = chrome.statusBarLeftText()
        XCTAssertTrue(left.hasPrefix("[rest-api]"))
        XCTAssertTrue(left.contains("0:claude*"))
        XCTAssertTrue(left.contains("1:claude-"))  // - flag on last window
        XCTAssertTrue(left.contains("2:claude"))
    }

    func testStatusBarRightTextFormat() {
        let chrome = TmuxChromeRenderer(sessionName: "test", windowCount: 1, activeWindow: 0, lastWindow: 0)
        let right = chrome.statusBarRightText()
        // Should match %H:%M %d-%b-%Y format (four-digit year, no hostname)
        let regex = try! NSRegularExpression(pattern: "\\d{2}:\\d{2} \\d{2}-[A-Z][a-z]{2}-\\d{4}")
        XCTAssertEqual(regex.numberOfMatches(in: right, range: NSRange(right.startIndex..., in: right)), 1)
    }

    func testStatusBarHeightIsOneLine() {
        let font = CTFontCreateWithName("Menlo" as CFString, 12.0, nil)
        let lineHeight = CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
        let chrome = TmuxChromeRenderer(sessionName: "test", windowCount: 1, activeWindow: 0, lastWindow: 0)
        let barHeight = chrome.statusBarHeight(for: font)
        XCTAssertEqual(barHeight, lineHeight, accuracy: 2.0)
    }

    func testSessionNameDerivedFromFileName() {
        // Session name should be derived from JSONL filename, not hardcoded
        let chrome = TmuxChromeRenderer(sessionName: "build-rest-api", windowCount: 4, activeWindow: 0, lastWindow: 1)
        XCTAssertTrue(chrome.statusBarLeftText().contains("[build-rest-api]"))
    }

    func testActivePaneBorderColor() {
        let theme = ThemeColors.dark
        let activeColor = NSColor(hex: theme.paneBorderActive)
        let inactiveColor = NSColor(hex: theme.paneBorderInactive)
        XCTAssertNotEqual(activeColor, inactiveColor)
    }
}
```

- [ ] **Step 2: Implement TmuxChromeRenderer**

Status bar as a `CALayer` at the bottom, height = 1 line of monospace font (derived from `FontMetrics.lineHeight`). Left `CATextLayer` left-aligned, right `CATextLayer` right-aligned. Session name derived from the first pane's JSONL filename (e.g., `build-rest-api.jsonl` -> `[build-rest-api]`). Window count matches pane count. Active pane changes when a `SessionPlayer` starts a new user prompt (content-driven, not random timer).

- [ ] **Step 3: Run tests, verify pass**

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add TmuxChromeRenderer with status bar and content-driven active pane"
```

---

## Task 11: Bundled Session Corpus (All 20-30 Sessions)

Build all sessions before wiring so the visual evaluation has enough content diversity.

**Files:**
- Create: 20-30 `.jsonl` files in `Resources/Sessions/`

- [ ] **Step 1: Generate all bundled sessions**

Create 20-30 JSONL files covering all themes from the spec. Vary session lengths (50-200 events). ASCII-safe content only. Each session has a distinct personality.

- [ ] **Step 2: Write test verifying all bundled sessions parse correctly**

```swift
func testAllBundledSessionsParse() {
    let bundle = Bundle(for: ClaudeCodeScreenSaverView.self)
    let sessionURLs = bundle.urls(forResourcesWithExtension: "jsonl", subdirectory: "Sessions") ?? []
    XCTAssertGreaterThanOrEqual(sessionURLs.count, 20)
    for url in sessionURLs {
        let events = SessionParser.parseFile(at: url)
        XCTAssertFalse(events.isEmpty, "Session \(url.lastPathComponent) produced no events")
        XCTAssertGreaterThanOrEqual(events.count, 20, "Session \(url.lastPathComponent) too short")
    }
}
```

- [ ] **Step 3: Run test, verify pass**

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add full bundled session corpus (20-30 sessions)"
```

---

## Task 12: Preferences (Codable + configureSheet + PreferencesStorage)

**Files:**
- Create: `ClaudeCodeScreenSaver/Helpers/PreferencesStorage.swift`
- Create: `ClaudeCodeScreenSaver/View/PreferencesController.swift`
- Create: `ClaudeCodeScreenSaverTests/Models/PreferencesTests.swift`

- [ ] **Step 1: Write failing Preferences tests**

Test `Codable` round-trip. Test default values. Test security-scoped bookmark serialization. Note: `Preferences.swift` itself is Foundation-only (created in Task 2). This task adds the platform-specific storage and UI.

- [ ] **Step 2: Implement PreferencesStorage**

```swift
// Helpers/PreferencesStorage.swift
// ABOUTME: Platform-specific load/save for Preferences via ScreenSaverDefaults.
// ABOUTME: Isolated here because it requires ScreenSaver.framework import.

import Foundation
import ScreenSaver

enum PreferencesStorage {
    static func load(bundleIdentifier: String) -> Preferences {
        guard let defaults = ScreenSaverDefaults(forModuleWithName: bundleIdentifier),
              let data = defaults.data(forKey: "preferences") else {
            return Preferences()
        }
        return (try? JSONDecoder().decode(Preferences.self, from: data)) ?? Preferences()
    }

    static func save(_ prefs: Preferences, bundleIdentifier: String) {
        guard let defaults = ScreenSaverDefaults(forModuleWithName: bundleIdentifier),
              let data = try? JSONEncoder().encode(prefs) else { return }
        defaults.set(data, forKey: "preferences")
        defaults.synchronize()
    }
}
```

- [ ] **Step 3: Implement PreferencesController**

NSViewController with: segmented control (dark/light), density slider, real sessions checkbox (privacy alert on toggle-on), path picker (NSOpenPanel, security-scoped bookmark), evolution speed slider, OLED-safe mode checkbox. All delegate references `weak`.

- [ ] **Step 4: Run tests, verify pass**

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add PreferencesStorage and configureSheet panel"
```

---

## Task 13: ClaudeCodeScreenSaverView (Entry Point + Wiring)

**Files:**
- Create: `ClaudeCodeScreenSaver/View/PaneController.swift`
- Modify: `ClaudeCodeScreenSaver/View/ClaudeCodeScreenSaverView.swift` (replace prototype)

- [ ] **Step 1: Write PaneController**

```swift
// View/PaneController.swift
// ABOUTME: Owns the TerminalRenderer, BorderRenderer contribution, and SessionPlayer for one pane.
// ABOUTME: Bridges the session state machine to the visual rendering layer.

import AppKit
```

Manages one pane: owns a `TerminalRenderer`, feeds it lines from `SessionPlayer`, tracks the pane's `PaneLayout`. Exposes `isTypingPrompt` for the active-pane-follows-content logic.

- [ ] **Step 2: Write failing integration tests**

Test: init with `isPreview: true`, `startAnimation()` creates layers, `animateOneFrame()` doesn't crash, `stopAnimation()` is idempotent.

- [ ] **Step 3: Wire ClaudeCodeScreenSaverView**

Replace the visual prototype with the real implementation:
- `init(frame:isPreview:)`: load preferences, create engine (reduced if preview), create PaneControllers
- `startAnimation()`: create layer tree with staggered activation, start SessionPlayers
- `animateOneFrame()`: deltaTime (clamped 0-200ms), advance players, update renderers, cursor blink, spinner, evolution timer, active pane follows content (when a player starts a new prompt, that pane becomes active)
- `stopAnimation()`: idempotent, cancel all tasks, remove all layers
- Multi-display: seed RNG with `NSScreen.displayID`
- Power: `IOPSCopyPowerSourcesInfo()`, reduce on battery
- OLED-safe mode: dim chrome to 50% opacity, force Active evolution, 2px pixel shift every 30s

- [ ] **Step 4: Run integration tests, verify pass**

- [ ] **Step 5: VISUAL QUALITY GATE**

Build, install to `~/Library/Screen Savers/`, activate full-screen. Watch for 10 minutes. Evaluate:
- Does the startup stagger look like "a system coming alive"?
- Do borders render correctly at all junction points?
- Is the status bar proportional (1 line height)?
- Does the active pane highlight follow content naturally?
- Are the typing speeds convincing?
- Does it feel ambient or attention-demanding?

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: wire ClaudeCodeScreenSaverView with full animation loop"
```

---

## Task 14: Startup Stagger + Battery Mode + OLED-Safe Mode Tests

**Files:**
- Create: `ClaudeCodeScreenSaverTests/Integration/StartupStaggerTests.swift`
- Create: `ClaudeCodeScreenSaverTests/Integration/BatteryModeTests.swift`

- [ ] **Step 1: Write startup stagger test**

```swift
func testPanesActivateWithStaggeredDelay() {
    let view = ClaudeCodeScreenSaverView(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), isPreview: false)
    view.startAnimation()
    // At t=0, only the first pane should be active
    let activePanes0 = view.paneControllers.filter { $0.isPlaying }
    XCTAssertEqual(activePanes0.count, 1)

    // Simulate 3 seconds of frames
    for _ in 0..<90 { view.animateOneFrame() }
    let activePanesLater = view.paneControllers.filter { $0.isPlaying }
    XCTAssertGreaterThan(activePanesLater.count, 1)
    view.stopAnimation()
}
```

- [ ] **Step 2: Write battery mode test**

```swift
func testBatteryModeReducesPanesAndFPS() {
    // This tests the logic, not actual IOKit detection
    let prefs = Preferences()
    let view = ClaudeCodeScreenSaverView(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), isPreview: false)
    view.simulateBatteryMode = true
    view.startAnimation()
    XCTAssertLessThanOrEqual(view.paneControllers.count, 4)
    XCTAssertEqual(view.animationTimeInterval, 1.0 / 15.0, accuracy: 0.01)
    view.stopAnimation()
}
```

- [ ] **Step 3: Run tests, verify pass**

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add startup stagger and battery mode with tests"
```

---

## Task 15: End-to-End Build + Install Verification

- [ ] **Step 1: Build Release .saver bundle**

Run: `xcodebuild build -scheme ClaudeCodeScreenSaver -configuration Release -destination 'platform=macOS'`

- [ ] **Step 2: Verify bundle structure**

Check `Contents/Resources/Sessions/` has 20+ JSONL files. Check `Info.plist` has correct `NSPrincipalClass`.

- [ ] **Step 3: Install and test in System Settings**

Copy to `~/Library/Screen Savers/`. Verify: appears in list, preview thumbnail renders (reduced panes), Options opens preferences, preferences persist across restarts.

- [ ] **Step 4: Performance benchmark**

Run screensaver full-screen for 5 minutes. Monitor with `top -pid <PID>`. Verify CPU stays below 8% sustained on Apple Silicon. Verify no memory growth. If on laptop, verify fans do not spin up on battery.

- [ ] **Step 5: Multi-display test (if available)**

Connect second display. Verify both screens show different content.

- [ ] **Step 6: Run all tests**

Run: `xcodebuild test -scheme ClaudeCodeScreenSaver -destination 'platform=macOS'`
Expected: All tests PASS

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore: verify end-to-end build, install, and performance"
```

---

## Task 16: Code Signing + Notarization

- [ ] **Step 1: Configure signing in Xcode project**

Set code signing identity to Developer ID Application. Enable hardened runtime. Add entitlements file if needed for security-scoped bookmarks.

- [ ] **Step 2: Build signed Release bundle**

Run: `xcodebuild build -scheme ClaudeCodeScreenSaver -configuration Release CODE_SIGN_IDENTITY="Developer ID Application" -destination 'platform=macOS'`

- [ ] **Step 3: Notarize**

```bash
xcrun notarytool submit ClaudeCodeScreenSaver.saver.zip --apple-id <ID> --team-id <TEAM> --password <APP_SPECIFIC_PASSWORD> --wait
xcrun stapler staple ClaudeCodeScreenSaver.saver
```

- [ ] **Step 4: Test signed bundle with SIP enabled**

Fresh install from Downloads (test App Translocation behavior). Verify Gatekeeper doesn't block. Verify preferences persist.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: add code signing and notarization configuration"
```

---

## Task 17: README + .gitignore + CLAUDE.md

**Files:**
- Create: `README.md`
- Create: `.gitignore`
- Create: `CLAUDE.md`

- [ ] **Step 1: Write README**

What it is, build instructions, installation (move to `~/Library/Screen Savers/` first), preferences, development setup, license (MIT).

- [ ] **Step 2: Write .gitignore**

Standard Xcode + `.superpowers/` + `*.saver` + `build/`.

- [ ] **Step 3: Write CLAUDE.md**

Project instructions: build/test commands, architecture overview, file layout, key constraints (delta-time, CATransaction, threading, Foundation-only models).

- [ ] **Step 4: FINAL VISUAL QUALITY GATE**

Install signed bundle. Activate screensaver. Watch for 20 minutes in a dark room. Confirm:
- Startup stagger works
- Borders look like tmux (junction characters visible)
- Content is varied and interesting across 20+ sessions
- Active pane follows content naturally
- Status bar shows real time, session name from file
- No fan spin-up on battery
- OLED-safe mode dims chrome and shifts pixels
- Light mode is usable (not blinding)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "docs: add README, .gitignore, and CLAUDE.md"
```
