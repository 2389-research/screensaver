// ABOUTME: Protocol for providing session event streams from JSONL files.
// ABOUTME: Async to support background parsing without loading full files into memory.

import Foundation

typealias SessionID = String

protocol SessionDataSource {
    var availableSessionIDs: [SessionID] { get }
    func loadEvents(for sessionID: SessionID) async throws -> [SessionEvent]
}
