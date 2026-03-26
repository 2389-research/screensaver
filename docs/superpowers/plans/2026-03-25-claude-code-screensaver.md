# Claude Code Screensaver Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS `.saver` screensaver that displays a grid of simulated Claude Code terminal instances in a tmux-style layout.

**Architecture:** Native Swift `ScreenSaverView` subclass using Core Animation. Per-line `CATextLayer` rendering with delta-time animation model. JSONL session replay on background queue. Protocol abstractions for all external dependencies.

**Tech Stack:** Swift 5.9+, macOS 14+ SDK, ScreenSaver.framework, QuartzCore (Core Animation), CoreText, IOKit (power source detection)

**Spec:** `docs/superpowers/specs/2026-03-25-claude-code-screensaver-design.md`

---

## File Structure

```
ClaudeCodeScreenSaver/
  ClaudeCodeScreenSaver.xcodeproj/
  ClaudeCodeScreenSaver/
    Info.plist
    Protocols/
      AnimationClock.swift              -- TimeInterval provider protocol
      SessionDataSource.swift           -- Session event stream protocol
      LayoutMetricsProvider.swift        -- Screen bounds protocol
    Models/
      SessionEvent.swift                -- Parsed JSONL event types
      PaneLayout.swift                  -- Pane frame + ID + isActive
      ColorScheme.swift                 -- Dark/light theme colors
      Preferences.swift                 -- Codable preferences struct
    Engine/
      TmuxLayoutEngine.swift            -- Binary tree pane layout
      SessionPlayer.swift               -- JSONL replay state machine
      SessionParser.swift               -- Background JSONL line parser
      ThreadSafeBuffer.swift            -- Ring buffer for cross-thread event delivery
    Rendering/
      TerminalRenderer.swift            -- Per-line CATextLayer grid
      TmuxChromeRenderer.swift          -- Borders, status bar
      FontMetrics.swift                 -- CTFont measurement + caching
      AttributedStringBuilder.swift     -- NSAttributedString factories for each UI element
    View/
      ClaudeCodeScreenSaverView.swift   -- ScreenSaverView subclass (entry point)
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
    Models/
      PreferencesTests.swift
      SessionEventTests.swift
    Integration/
      AnimationLoopTests.swift
      LayoutEvolutionTests.swift
      SessionCyclingTests.swift
    Mocks/
      MockAnimationClock.swift
      MockSessionDataSource.swift
      MockLayoutMetrics.swift
```

---

## Task 1: Xcode Project Scaffold + Protocols

**Files:**
- Create: `ClaudeCodeScreenSaver.xcodeproj` (Xcode Screen Saver bundle target)
- Create: `ClaudeCodeScreenSaver/Info.plist`
- Create: `ClaudeCodeScreenSaver/Protocols/AnimationClock.swift`
- Create: `ClaudeCodeScreenSaver/Protocols/SessionDataSource.swift`
- Create: `ClaudeCodeScreenSaver/Protocols/LayoutMetricsProvider.swift`
- Create: `ClaudeCodeScreenSaver/Models/SessionEvent.swift`
- Create: `ClaudeCodeScreenSaver/Models/PaneLayout.swift`
- Create: `ClaudeCodeScreenSaverTests/Mocks/MockAnimationClock.swift`

- [ ] **Step 1: Create Xcode project**

Create a new Xcode project with the "Screen Saver" template. Bundle identifier: `com.2389.ClaudeCodeScreenSaver`. Deployment target: macOS 14.0. Add a unit test target `ClaudeCodeScreenSaverTests`.

- [ ] **Step 2: Write protocol definitions**

```swift
// Protocols/AnimationClock.swift
// ABOUTME: Protocol abstracting time source for testability.
// ABOUTME: Allows mock clocks in tests to control animation timing.

import Foundation

protocol AnimationClock {
    var currentTime: TimeInterval { get }
}

struct SystemAnimationClock: AnimationClock {
    var currentTime: TimeInterval {
        CACurrentMediaTime()
    }
}
```

```swift
// Protocols/SessionDataSource.swift
// ABOUTME: Protocol for providing session event streams.
// ABOUTME: Enables testing with mock sessions instead of real JSONL files.

import Foundation

typealias SessionID = String

protocol SessionDataSource {
    var availableSessionIDs: [SessionID] { get }
    func events(for sessionID: SessionID) -> [SessionEvent]
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

struct SystemLayoutMetrics: LayoutMetricsProvider {
    let screenBounds: CGRect
}
```

- [ ] **Step 3: Write model types**

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

- [ ] **Step 4: Write mock clock for tests**

```swift
// Mocks/MockAnimationClock.swift
// ABOUTME: Test double for AnimationClock protocol.
// ABOUTME: Allows tests to control time progression precisely.

import Foundation
@testable import ClaudeCodeScreenSaver

class MockAnimationClock: AnimationClock {
    var currentTime: TimeInterval = 0.0

    func advance(by interval: TimeInterval) {
        currentTime += interval
    }
}
```

- [ ] **Step 5: Verify project builds**

Run: `xcodebuild build -scheme ClaudeCodeScreenSaver -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: scaffold Xcode project with protocols and model types"
```

---

## Task 2: ThreadSafeBuffer

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
        buffer.enqueue(1)
        buffer.enqueue(2)
        buffer.enqueue(3)
        XCTAssertEqual(buffer.dequeue(), 1)
        XCTAssertEqual(buffer.dequeue(), 2)
        XCTAssertEqual(buffer.dequeue(), 3)
    }

    func testCapacityDropsOldest() {
        let buffer = ThreadSafeBuffer<Int>(capacity: 3)
        buffer.enqueue(1)
        buffer.enqueue(2)
        buffer.enqueue(3)
        buffer.enqueue(4) // drops 1
        XCTAssertEqual(buffer.dequeue(), 2)
    }

    func testConcurrentAccess() {
        let buffer = ThreadSafeBuffer<Int>(capacity: 1000)
        let expectation = expectation(description: "concurrent")
        expectation.expectedFulfillmentCount = 2

        DispatchQueue.global().async {
            for i in 0..<500 { buffer.enqueue(i) }
            expectation.fulfill()
        }
        DispatchQueue.global().async {
            for i in 500..<1000 { buffer.enqueue(i) }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
        var count = 0
        while buffer.dequeue() != nil { count += 1 }
        XCTAssertEqual(count, 1000)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme ClaudeCodeScreenSaver -destination 'platform=macOS' -only-testing:ClaudeCodeScreenSaverTests/ThreadSafeBufferTests`
Expected: FAIL (type not defined)

- [ ] **Step 3: Implement ThreadSafeBuffer**

```swift
// Engine/ThreadSafeBuffer.swift
// ABOUTME: Thread-safe FIFO ring buffer for cross-thread event delivery.
// ABOUTME: Used to pass parsed JSONL events from background queue to animation thread.

import Foundation

final class ThreadSafeBuffer<Element> {
    private var storage: [Element] = []
    private let capacity: Int
    private let lock = NSLock()

    init(capacity: Int) {
        self.capacity = capacity
        storage.reserveCapacity(capacity)
    }

    func enqueue(_ element: Element) {
        lock.lock()
        defer { lock.unlock() }
        if storage.count >= capacity {
            storage.removeFirst()
        }
        storage.append(element)
    }

    func dequeue() -> Element? {
        lock.lock()
        defer { lock.unlock() }
        guard !storage.isEmpty else { return nil }
        return storage.removeFirst()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme ClaudeCodeScreenSaver -destination 'platform=macOS' -only-testing:ClaudeCodeScreenSaverTests/ThreadSafeBufferTests`
Expected: All 5 tests PASS

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add ThreadSafeBuffer for cross-thread event delivery"
```

---

## Task 3: SessionParser (JSONL Parsing)

**Files:**
- Create: `ClaudeCodeScreenSaver/Engine/SessionParser.swift`
- Create: `ClaudeCodeScreenSaverTests/Engine/SessionParserTests.swift`
- Create: `ClaudeCodeScreenSaverTests/Fixtures/sample-session.jsonl`

- [ ] **Step 1: Create a sample JSONL fixture**

Create a minimal JSONL file with one of each event type, copied from real Claude Code format. Include: user prompt, assistant text, tool_use, tool_result, thinking, file-history-snapshot (to verify skip), unknown type (to verify skip), malformed line (to verify skip).

- [ ] **Step 2: Write failing tests**

```swift
// Engine/SessionParserTests.swift
// ABOUTME: Tests for JSONL line-by-line parsing into SessionEvent values.
// ABOUTME: Verifies correct parsing of all Claude Code event types and error resilience.

import XCTest
@testable import ClaudeCodeScreenSaver

final class SessionParserTests: XCTestCase {

    func testParseUserPrompt() {
        let line = #"{"type":"user","message":{"role":"user","content":"fix the auth bug"}}"#
        let event = SessionParser.parseLine(line)
        XCTAssertEqual(event, .userPrompt(text: "fix the auth bug"))
    }

    func testParseAssistantText() {
        let line = #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"I'll fix that."}]}}"#
        let event = SessionParser.parseLine(line)
        XCTAssertEqual(event, .assistantText(text: "I'll fix that."))
    }

    func testParseToolUse() {
        let line = #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Read","input":{"file_path":"src/auth.ts"}}]}}"#
        let event = SessionParser.parseLine(line)
        XCTAssertEqual(event, .toolCall(tool: "Read", args: "src/auth.ts"))
    }

    func testParseToolResult() {
        let line = #"{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"123","content":"file contents here"}]}}"#
        let event = SessionParser.parseLine(line)
        XCTAssertEqual(event, .toolResult(content: "file contents here"))
    }

    func testParseThinking() {
        let line = #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"thinking","thinking":"let me consider..."}]}}"#
        let event = SessionParser.parseLine(line)
        XCTAssertEqual(event, .thinking(durationHint: nil))
    }

    func testSkipFileHistorySnapshot() {
        let line = #"{"type":"file-history-snapshot","snapshot":{}}"#
        XCTAssertNil(SessionParser.parseLine(line))
    }

    func testSkipUnknownType() {
        let line = #"{"type":"progress","data":{}}"#
        XCTAssertNil(SessionParser.parseLine(line))
    }

    func testSkipMalformedJSON() {
        let line = "this is not json {"
        XCTAssertNil(SessionParser.parseLine(line))
    }

    func testSkipApiErrorMessage() {
        let line = #"{"type":"assistant","isApiErrorMessage":true,"message":{"role":"assistant","content":[{"type":"text","text":"error"}]}}"#
        XCTAssertNil(SessionParser.parseLine(line))
    }

    func testSkipMetaMessage() {
        let line = #"{"type":"user","isMeta":true,"message":{"role":"user","content":"meta info"}}"#
        XCTAssertNil(SessionParser.parseLine(line))
    }

    func testParseFileWithMixedEvents() {
        let fixturePath = Bundle(for: Self.self).path(forResource: "sample-session", ofType: "jsonl")!
        let events = SessionParser.parseFile(at: URL(fileURLWithPath: fixturePath))
        XCTAssertFalse(events.isEmpty)
        // Verify no file-history-snapshot or unknown types leaked through
        for event in events {
            switch event {
            case .userPrompt, .assistantText, .toolCall, .toolResult, .thinking:
                break // expected
            }
        }
    }
}
```

- [ ] **Step 2b: Run tests to verify they fail**

Run: `xcodebuild test -scheme ClaudeCodeScreenSaver -destination 'platform=macOS' -only-testing:ClaudeCodeScreenSaverTests/SessionParserTests`
Expected: FAIL

- [ ] **Step 3: Implement SessionParser**

```swift
// Engine/SessionParser.swift
// ABOUTME: Parses Claude Code JSONL session files line-by-line into SessionEvent values.
// ABOUTME: Handles all known event types, skips unknown types and malformed lines gracefully.

import Foundation

enum SessionParser {

    static func parseLine(_ line: String) -> SessionEvent? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Skip meta and error messages
        if json["isApiErrorMessage"] as? Bool == true { return nil }
        if json["isMeta"] as? Bool == true { return nil }

        guard let type = json["type"] as? String else { return nil }

        switch type {
        case "user":
            return parseUserMessage(json)
        case "assistant":
            return parseAssistantMessage(json)
        case "file-history-snapshot", "progress", "summary", "system",
             "last-prompt", "queue-operation":
            return nil
        default:
            return nil
        }
    }

    static func parseFile(at url: URL) -> [SessionEvent] {
        guard let data = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return data.components(separatedBy: .newlines)
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return nil }
                return parseLine(trimmed)
            }
    }

    // MARK: - Private

    private static func parseUserMessage(_ json: [String: Any]) -> SessionEvent? {
        guard let message = json["message"] as? [String: Any] else { return nil }
        let content = message["content"]

        // String content = human prompt
        if let text = content as? String {
            return .userPrompt(text: text)
        }

        // Array content = tool results
        if let array = content as? [[String: Any]] {
            for item in array {
                if item["type"] as? String == "tool_result" {
                    let resultContent: String
                    if let str = item["content"] as? String {
                        resultContent = str
                    } else if let arr = item["content"] as? [[String: Any]] {
                        resultContent = arr.compactMap { $0["text"] as? String }.joined(separator: "\n")
                    } else {
                        resultContent = ""
                    }
                    return .toolResult(content: resultContent)
                }
            }
        }

        return nil
    }

    private static func parseAssistantMessage(_ json: [String: Any]) -> SessionEvent? {
        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else {
            return nil
        }

        for item in content {
            guard let itemType = item["type"] as? String else { continue }

            switch itemType {
            case "text":
                if let text = item["text"] as? String {
                    return .assistantText(text: text)
                }
            case "tool_use":
                let tool = item["name"] as? String ?? "Unknown"
                let args: String
                if let input = item["input"] as? [String: Any] {
                    args = input["file_path"] as? String
                        ?? input["command"] as? String
                        ?? input["pattern"] as? String
                        ?? tool
                } else {
                    args = tool
                }
                return .toolCall(tool: tool, args: args)
            case "thinking":
                return .thinking(durationHint: nil)
            default:
                continue
            }
        }

        return nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme ClaudeCodeScreenSaver -destination 'platform=macOS' -only-testing:ClaudeCodeScreenSaverTests/SessionParserTests`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add SessionParser for JSONL line-by-line parsing"
```

---

## Task 4: FontMetrics + AttributedStringBuilder

**Files:**
- Create: `ClaudeCodeScreenSaver/Rendering/FontMetrics.swift`
- Create: `ClaudeCodeScreenSaver/Rendering/AttributedStringBuilder.swift`
- Create: `ClaudeCodeScreenSaver/Models/ColorScheme.swift`
- Create: `ClaudeCodeScreenSaverTests/Rendering/FontMetricsTests.swift`
- Create: `ClaudeCodeScreenSaverTests/Rendering/AttributedStringBuilderTests.swift`

- [ ] **Step 1: Write failing FontMetrics tests**

Test that FontMetrics computes cols/rows from a given rect, respects 9pt floor and 14pt ceiling, and uses `CTFontGetAdvancesForGlyphs` for char advance.

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement FontMetrics**

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

        // Try to fit targetCols x targetRows, respecting font size bounds
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
        var glyph = CTFontGetGlyphsForCharacters(font, [UniChar(0x4D)], nil, 1) // 'M'
        var advance = CGSize.zero
        var glyphVal: CGGlyph = 0
        let chars: [UniChar] = [0x4D] // 'M'
        CTFontGetGlyphsForCharacters(font, chars, &glyphVal, 1)
        CTFontGetAdvancesForGlyphs(font, .horizontal, [glyphVal], &advance, 1)
        return advance.width
    }
}
```

- [ ] **Step 4: Run FontMetrics tests, verify pass**

- [ ] **Step 5: Write failing AttributedStringBuilder tests**

Test that each Claude Code UI element (prompt, response, tool call, tool result, thinking spinner, success, error) produces correctly colored/styled `NSAttributedString`. Test both dark and light color schemes.

- [ ] **Step 6: Implement ColorScheme and AttributedStringBuilder**

```swift
// Models/ColorScheme.swift
// ABOUTME: Color definitions for dark and light screensaver themes.
// ABOUTME: All colors match the spec's Claude Code TUI color palette.

import AppKit

struct ColorScheme {
    let background: NSColor
    let promptChevron: NSColor
    let userInput: NSColor
    let responseText: NSColor
    let thinkingSpinner: NSColor
    let toolName: NSColor
    let toolBorder: NSColor
    let successOutput: NSColor
    let errorOutput: NSColor
    let paneBorderActive: NSColor
    let paneBorderInactive: NSColor
    let statusBarBackground: NSColor
    let statusBarText: NSColor

    static let dark = ColorScheme(
        background: NSColor(hex: "#1e1e2e"),
        promptChevron: NSColor(hex: "#d4a574"),
        userInput: .white,
        responseText: NSColor(hex: "#e0e0e0"),
        thinkingSpinner: NSColor(hex: "#888888"),
        toolName: NSColor(hex: "#7aa2f7"),
        toolBorder: NSColor(hex: "#555555"),
        successOutput: NSColor(hex: "#73daca"),
        errorOutput: NSColor(hex: "#f7768e"),
        paneBorderActive: NSColor(hex: "#00d7ff"),
        paneBorderInactive: NSColor(hex: "#444444"),
        statusBarBackground: NSColor(hex: "#1e2030"),
        statusBarText: NSColor(hex: "#c0c0c0")
    )

    static let light = ColorScheme(
        background: .white,
        promptChevron: NSColor(hex: "#b5651d"),
        userInput: .black,
        responseText: NSColor(hex: "#333333"),
        thinkingSpinner: NSColor(hex: "#999999"),
        toolName: NSColor(hex: "#0055aa"),
        toolBorder: NSColor(hex: "#cccccc"),
        successOutput: NSColor(hex: "#2d8659"),
        errorOutput: NSColor(hex: "#cc3333"),
        paneBorderActive: NSColor(hex: "#0088cc"),
        paneBorderInactive: NSColor(hex: "#cccccc"),
        statusBarBackground: NSColor(hex: "#e0e0e0"),
        statusBarText: NSColor(hex: "#333333")
    )
}
```

- [ ] **Step 7: Run AttributedStringBuilder tests, verify pass**

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: add FontMetrics and AttributedStringBuilder"
```

---

## Task 5: TmuxLayoutEngine

**Files:**
- Create: `ClaudeCodeScreenSaver/Engine/TmuxLayoutEngine.swift`
- Create: `ClaudeCodeScreenSaverTests/Engine/TmuxLayoutEngineTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Engine/TmuxLayoutEngineTests.swift
// ABOUTME: Tests for the binary-tree pane layout engine.
// ABOUTME: Verifies split/close/resize operations and constraint enforcement.

import XCTest
@testable import ClaudeCodeScreenSaver

final class TmuxLayoutEngineTests: XCTestCase {

    func testInitialLayoutProducesPanesInRange() {
        let engine = TmuxLayoutEngine(bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                       minPanes: 3, maxPanes: 8, seed: 42)
        let layouts = engine.currentLayouts()
        XCTAssertGreaterThanOrEqual(layouts.count, 3)
        XCTAssertLessThanOrEqual(layouts.count, 8)
    }

    func testAllPanesFitWithinBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let engine = TmuxLayoutEngine(bounds: bounds, minPanes: 5, maxPanes: 8, seed: 42)
        for layout in engine.currentLayouts() {
            XCTAssertTrue(bounds.contains(layout.frame),
                         "Pane \(layout.id) frame \(layout.frame) exceeds bounds")
        }
    }

    func testMinimumPaneSizeRespected() {
        let engine = TmuxLayoutEngine(bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                       minPanes: 8, maxPanes: 12, seed: 42)
        let metrics = FontMetrics.compute(for: CGRect(x: 0, y: 0, width: 100, height: 100))
        let minWidth = CGFloat(40) * metrics.charAdvance
        let minHeight = CGFloat(10) * metrics.lineHeight

        for layout in engine.currentLayouts() {
            XCTAssertGreaterThanOrEqual(layout.frame.width, minWidth - 1, // 1px tolerance for borders
                                       "Pane \(layout.id) too narrow: \(layout.frame.width)")
            XCTAssertGreaterThanOrEqual(layout.frame.height, minHeight - 1,
                                       "Pane \(layout.id) too short: \(layout.frame.height)")
        }
    }

    func testExactlyOneActivePane() {
        let engine = TmuxLayoutEngine(bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                       minPanes: 5, maxPanes: 8, seed: 42)
        let activeCount = engine.currentLayouts().filter(\.isActive).count
        XCTAssertEqual(activeCount, 1)
    }

    func testSplitIncreasesPaneCount() {
        let engine = TmuxLayoutEngine(bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                       minPanes: 3, maxPanes: 12, seed: 42)
        let before = engine.currentLayouts().count
        let didSplit = engine.trySplit()
        if didSplit {
            XCTAssertEqual(engine.currentLayouts().count, before + 1)
        }
    }

    func testCloseDecreasesPaneCount() {
        let engine = TmuxLayoutEngine(bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                       minPanes: 3, maxPanes: 12, seed: 42)
        let before = engine.currentLayouts().count
        guard before > 3 else { return }
        let didClose = engine.tryClose()
        if didClose {
            XCTAssertEqual(engine.currentLayouts().count, before - 1)
        }
    }

    func testPaneCountNeverExceedsMax() {
        let engine = TmuxLayoutEngine(bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                       minPanes: 3, maxPanes: 8, seed: 42)
        for _ in 0..<100 {
            _ = engine.trySplit()
        }
        XCTAssertLessThanOrEqual(engine.currentLayouts().count, 8)
    }

    func testPaneCountNeverDropsBelowMin() {
        let engine = TmuxLayoutEngine(bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                       minPanes: 3, maxPanes: 8, seed: 42)
        for _ in 0..<100 {
            _ = engine.tryClose()
        }
        XCTAssertGreaterThanOrEqual(engine.currentLayouts().count, 3)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement TmuxLayoutEngine**

Binary tree of `SplitNode` (axis + ratio + children) and `LeafNode` (pane ID). `currentLayouts()` walks the tree and computes frames. `trySplit()` picks a random leaf and splits it. `tryClose()` picks a random leaf and removes it, promoting its sibling. Seeded `RandomNumberGenerator` for deterministic tests.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add TmuxLayoutEngine with split/close/resize"
```

---

## Task 6: SessionPlayer (Replay State Machine)

**Files:**
- Create: `ClaudeCodeScreenSaver/Engine/SessionPlayer.swift`
- Create: `ClaudeCodeScreenSaverTests/Engine/SessionPlayerTests.swift`
- Create: `ClaudeCodeScreenSaverTests/Mocks/MockSessionDataSource.swift`

- [ ] **Step 1: Write failing tests**

Test the state machine: given a sequence of `SessionEvent` values and a mock clock, verify that `advance(deltaTime:)` produces the correct terminal lines at the correct timing. Test: prompt typing at 40 chars/sec, response at 60 chars/sec, thinking spinner cycling, pause between messages, session wrap-around.

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement SessionPlayer**

State machine with states: `.idle`, `.typingPrompt(charIndex)`, `.thinking(elapsed)`, `.typingResponse(charIndex)`, `.toolCall(charIndex)`, `.toolResult(fadeElapsed)`, `.pausing(elapsed)`. `advance(deltaTime:)` progresses through the current event based on accumulated time and char rates. Outputs: array of terminal lines (the current visible content).

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add SessionPlayer replay state machine"
```

---

## Task 7: TerminalRenderer (Per-Line CATextLayer Grid)

**Files:**
- Create: `ClaudeCodeScreenSaver/Rendering/TerminalRenderer.swift`
- Create: `ClaudeCodeScreenSaverTests/Rendering/TerminalRendererTests.swift`

- [ ] **Step 1: Write failing tests**

Test that `TerminalRenderer` creates the correct number of `CATextLayer` sublayers for visible rows, updates only dirty lines, positions the cursor overlay correctly, and toggles cursor visibility based on blink accumulator.

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement TerminalRenderer**

Creates `rows` count of `CATextLayer` sublayers inside a container `CALayer`. Each line layer has `contentsScale` set for Retina. Cursor is a separate `CALayer` with background color. `update(lines:cursorPosition:deltaTime:)` diffs against previous lines, only sets `.string` on changed layers, all within `CATransaction.setDisableActions(true)`. Cursor blink accumulator toggles `isHidden`.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add TerminalRenderer with per-line CATextLayer grid"
```

---

## Task 8: TmuxChromeRenderer (Borders + Status Bar)

**Files:**
- Create: `ClaudeCodeScreenSaver/Rendering/TmuxChromeRenderer.swift`
- Create: `ClaudeCodeScreenSaverTests/Rendering/TmuxChromeRendererTests.swift` (optional — mostly visual)

- [ ] **Step 1: Write tests for status bar text generation**

Test that status bar left text formats as `[project] 0:claude*  1:claude-  2:claude  3:claude` and right text uses `%H:%M %d-%b-%Y` (four-digit year, no hostname).

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement TmuxChromeRenderer**

Status bar: `CALayer` at bottom of screen with `CATextLayer` for left/right text. Pane borders: set `borderWidth = 1.0` and `borderColor` on each pane's container layer. Active pane rotation: track a timer, pick new random active pane every 15-30s.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add TmuxChromeRenderer with status bar and pane borders"
```

---

## Task 9: Preferences (Codable + configureSheet)

**Files:**
- Create: `ClaudeCodeScreenSaver/Models/Preferences.swift`
- Create: `ClaudeCodeScreenSaver/View/PreferencesController.swift`
- Create: `ClaudeCodeScreenSaverTests/Models/PreferencesTests.swift`

- [ ] **Step 1: Write failing tests**

Test `Codable` round-trip for `Preferences` struct. Test default values. Test that security-scoped bookmark data can be serialized/deserialized (mock with a temp file URL).

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement Preferences**

```swift
// Models/Preferences.swift
// ABOUTME: User-configurable screensaver settings stored via ScreenSaverDefaults.
// ABOUTME: Single Codable struct stored as Data for type safety.

import Foundation
import ScreenSaver

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

    static func load(bundleIdentifier: String) -> Preferences {
        guard let defaults = ScreenSaverDefaults(forModuleWithName: bundleIdentifier),
              let data = defaults.data(forKey: "preferences") else {
            return Preferences()
        }
        return (try? JSONDecoder().decode(Preferences.self, from: data)) ?? Preferences()
    }

    func save(bundleIdentifier: String) {
        guard let defaults = ScreenSaverDefaults(forModuleWithName: bundleIdentifier),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: "preferences")
        defaults.synchronize()
    }
}
```

- [ ] **Step 4: Implement PreferencesController**

NSViewController loaded via `configureSheet()`. Contains: segmented control for color scheme, slider for pane density, checkbox for real sessions (with privacy alert on toggle-on), path picker button (opens `NSOpenPanel`, stores security-scoped bookmark), slider for evolution speed, checkbox for OLED-safe mode. All delegate references to the screensaver view are `weak`.

- [ ] **Step 5: Run tests to verify they pass**

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add Preferences model and configureSheet panel"
```

---

## Task 10: ClaudeCodeScreenSaverView (Entry Point + Wiring)

**Files:**
- Create: `ClaudeCodeScreenSaver/View/ClaudeCodeScreenSaverView.swift`

- [ ] **Step 1: Write failing integration test**

Test that `ClaudeCodeScreenSaverView` can be initialized with `isPreview: true`, `startAnimation()` creates layers, `animateOneFrame()` doesn't crash, and `stopAnimation()` cleans up.

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Implement ClaudeCodeScreenSaverView**

Wire everything together:
- `init(frame:isPreview:)`: load preferences, create `TmuxLayoutEngine` (reduced panes if preview), create `PaneController` array
- `startAnimation()`: create layer tree, start `SessionPlayer` instances (bundled only if preview or if real sessions disabled), set `animationTimeInterval`
- `animateOneFrame()`: compute deltaTime (clamped 0-200ms), advance each `SessionPlayer`, update each `TerminalRenderer`, update cursor blink, check evolution timer, update active pane rotation
- `stopAnimation()`: idempotent teardown, cancel all tasks, remove all layers
- `configureSheet()`: return `PreferencesController`
- Multi-display: seed RNG with `NSScreen` display ID
- Power: check `IOPSCopyPowerSourcesInfo()`, reduce panes/fps on battery

- [ ] **Step 4: Run integration test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add ClaudeCodeScreenSaverView entry point"
```

---

## Task 11: Bundled Session Corpus (5 Initial Sessions)

**Files:**
- Create: `ClaudeCodeScreenSaver/Resources/Sessions/build-rest-api.jsonl`
- Create: `ClaudeCodeScreenSaver/Resources/Sessions/fix-react-bug.jsonl`
- Create: `ClaudeCodeScreenSaver/Resources/Sessions/write-python-tests.jsonl`
- Create: `ClaudeCodeScreenSaver/Resources/Sessions/refactor-database.jsonl`
- Create: `ClaudeCodeScreenSaver/Resources/Sessions/debug-memory-leak.jsonl`

- [ ] **Step 1: Generate 5 bundled sessions**

Create 5 JSONL files in the real Claude Code format. Each should be 50-100 events, covering a complete coding session. Use ASCII-safe content only. Each session should have a distinct "personality" — different tools used, different response lengths, different amounts of thinking time.

- [ ] **Step 2: Write test verifying all bundled sessions parse correctly**

```swift
func testAllBundledSessionsParse() {
    let bundle = Bundle(for: ClaudeCodeScreenSaverView.self)
    let sessionURLs = bundle.urls(forResourcesWithExtension: "jsonl", subdirectory: "Sessions") ?? []
    XCTAssertGreaterThanOrEqual(sessionURLs.count, 5)
    for url in sessionURLs {
        let events = SessionParser.parseFile(at: url)
        XCTAssertFalse(events.isEmpty, "Session \(url.lastPathComponent) produced no events")
    }
}
```

- [ ] **Step 3: Run test to verify it passes**

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add 5 bundled session JSONL files"
```

---

## Task 12: End-to-End Build + Install Verification

**Files:**
- Modify: `ClaudeCodeScreenSaver/Info.plist` (verify all keys)

- [ ] **Step 1: Build the .saver bundle**

Run: `xcodebuild build -scheme ClaudeCodeScreenSaver -configuration Release -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED, produces `ClaudeCodeScreenSaver.saver`

- [ ] **Step 2: Verify bundle structure**

Check that `ClaudeCodeScreenSaver.saver/Contents/Resources/Sessions/` contains the bundled JSONL files. Check `Info.plist` has correct `NSPrincipalClass`.

- [ ] **Step 3: Install and test in System Settings**

Copy `.saver` to `~/Library/Screen Savers/`, open System Settings > Screen Saver, verify it appears, verify preview thumbnail renders, verify Options button opens preferences panel.

- [ ] **Step 4: Run all tests**

Run: `xcodebuild test -scheme ClaudeCodeScreenSaver -destination 'platform=macOS'`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: verify end-to-end build and installation"
```

---

## Task 13: Remaining Bundled Sessions (15-25 More)

**Files:**
- Create: additional `.jsonl` files in `Resources/Sessions/`

- [ ] **Step 1: Generate remaining sessions**

Create 15-25 more JSONL session files covering the remaining themes from the spec. Vary session lengths (50-200 events). Ensure diversity in tool usage patterns.

- [ ] **Step 2: Run bundled session parse test**

Verify all sessions parse without errors.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add remaining bundled session corpus"
```

---

## Task 14: README + .gitignore + CLAUDE.md

**Files:**
- Create: `README.md`
- Create: `.gitignore`
- Create: `CLAUDE.md`

- [ ] **Step 1: Write README**

Include: what it is, screenshot placeholder, build instructions (`xcodebuild`), installation instructions (move to `~/Library/Screen Savers/` first, then double-click), preferences description, development setup.

- [ ] **Step 2: Write .gitignore**

Standard Xcode gitignore + `.superpowers/` + `*.saver` build artifacts.

- [ ] **Step 3: Write CLAUDE.md**

Project-specific instructions: build command, test command, architecture overview, file layout reference, key constraints (delta-time, CATransaction, threading model).

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "docs: add README, .gitignore, and CLAUDE.md"
```
