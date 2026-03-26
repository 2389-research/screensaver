// ABOUTME: Test double for SessionDataSource protocol.
// ABOUTME: Returns pre-loaded events for testing without JSONL file access.

import Foundation

class MockSessionDataSource: SessionDataSource {
    var sessions: [SessionID: [SessionEvent]] = [:]
    var availableSessionIDs: [SessionID] { Array(sessions.keys) }
    func loadEvents(for sessionID: SessionID) async throws -> [SessionEvent] {
        sessions[sessionID] ?? []
    }
}
