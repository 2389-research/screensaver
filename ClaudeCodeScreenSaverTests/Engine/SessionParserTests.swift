// ABOUTME: Tests for JSONL line-by-line parsing into SessionEvent values.
// ABOUTME: Verifies correct parsing of all Claude Code event types and error resilience.

import XCTest

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
        XCTAssertEqual(events.count, 5) // prompt, thinking, text, tool_use, tool_result
        XCTAssertEqual(events[0], .userPrompt(text: "fix the auth bug"))
        XCTAssertEqual(events[1], .thinking(durationHint: nil))
        XCTAssertEqual(events[2], .assistantText(text: "I'll fix the auth middleware."))
        XCTAssertEqual(events[3], .toolCall(tool: "Read", args: "src/auth.ts"))
        XCTAssertEqual(events[4], .toolResult(content: "export function auth() {}"))
    }

    func testToolResultWithNullContent() {
        let line = #"{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":null}]}}"#
        let event = SessionParser.parseLine(line)
        XCTAssertEqual(event, .toolResult(content: ""))
    }

    func testToolUseWithCommandInput() {
        let line = #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"npm test"}}]}}"#
        let event = SessionParser.parseLine(line)
        XCTAssertEqual(event, .toolCall(tool: "Bash", args: "npm test"))
    }
}
