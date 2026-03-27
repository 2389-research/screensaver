// ABOUTME: Parsed events from Code Agent JSONL session files.
// ABOUTME: Represents all displayable event types the renderer understands.

import Foundation

enum SessionEvent: Equatable {
    case userPrompt(text: String)
    case assistantText(text: String)
    case toolCall(tool: String, args: String)
    case toolResult(content: String)
    case thinking(durationHint: TimeInterval?)
}
