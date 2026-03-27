// ABOUTME: Compile-time build metadata for the dev version overlay.
// ABOUTME: Shows git hash and timestamp so you know which build is running.

import Foundation

enum BuildInfo {
    // These are replaced by the build script, or fall back to defaults
    static let gitHash: String = {
        // Try to read from bundle's Info.plist (set by build phase script)
        if let hash = Bundle(for: ClaudeCodeScreenSaverView.self).infoDictionary?["GitHash"] as? String, !hash.isEmpty {
            return hash
        }
        return "dev"
    }()

    static let buildDate: String = {
        if let date = Bundle(for: ClaudeCodeScreenSaverView.self).infoDictionary?["BuildDate"] as? String, !date.isEmpty {
            return date
        }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()

    static var versionString: String {
        "DEV \(gitHash) (\(buildDate))"
    }
}
