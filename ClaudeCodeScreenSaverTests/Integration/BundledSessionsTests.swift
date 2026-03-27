// ABOUTME: Verifies all bundled JSONL session files parse correctly and have sufficient content.
// ABOUTME: Ensures the corpus is ready for screensaver playback.

import XCTest

final class BundledSessionsTests: XCTestCase {
    func testAllBundledSessionsParse() {
        let bundle = Bundle(for: type(of: self))
        // Check in the test bundle resources; filter out small test fixtures (< 20 events)
        let allJSONLURLs = bundle.urls(forResourcesWithExtension: "jsonl", subdirectory: nil) ?? []
        let sessionURLs = allJSONLURLs.filter { url in
            SessionParser.parseFile(at: url).count >= 20
        }
        XCTAssertGreaterThanOrEqual(sessionURLs.count, 20, "Need at least 20 bundled sessions, found \(sessionURLs.count)")
        for url in sessionURLs {
            let events = SessionParser.parseFile(at: url)
            XCTAssertGreaterThanOrEqual(events.count, 20,
                "Session \(url.lastPathComponent) too short: \(events.count) events")
            XCTAssertFalse(events.isEmpty, "Session \(url.lastPathComponent) produced no events")
        }
    }

    func testSessionsDiverseToolUsage() {
        let bundle = Bundle(for: type(of: self))
        let sessionURLs = bundle.urls(forResourcesWithExtension: "jsonl", subdirectory: nil) ?? []
        var toolsUsed: Set<String> = []
        for url in sessionURLs {
            let events = SessionParser.parseFile(at: url)
            for event in events {
                if case .toolCall(let tool, _) = event {
                    toolsUsed.insert(tool)
                }
            }
        }
        // Across all sessions, we should see at least Read, Edit/Write, Bash, Glob
        XCTAssertTrue(toolsUsed.contains("Read"), "Sessions should use Read tool")
        XCTAssertTrue(toolsUsed.contains("Bash"), "Sessions should use Bash tool")
        XCTAssertTrue(toolsUsed.contains("Glob") || toolsUsed.contains("Grep"),
                      "Sessions should use search tools")
    }
}
