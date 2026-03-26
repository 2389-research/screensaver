// ABOUTME: Parses Claude Code JSONL session files line-by-line into SessionEvent values.
// ABOUTME: Handles all known event types, skips unknown types and malformed lines gracefully.

import Foundation

enum SessionParser {

    static func parseLine(_ line: String) -> SessionEvent? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

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

    private static func parseUserMessage(_ json: [String: Any]) -> SessionEvent? {
        guard let message = json["message"] as? [String: Any] else { return nil }
        let content = message["content"]

        if let text = content as? String {
            return .userPrompt(text: text)
        }

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
