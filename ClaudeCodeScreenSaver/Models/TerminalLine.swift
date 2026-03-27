// ABOUTME: Typed terminal line model carrying semantic type alongside text content.
// ABOUTME: Eliminates stringly-typed prefix parsing in PaneController.

import Foundation

enum TerminalLine: Equatable {
    case prompt(text: String)
    case response(text: String)
    case toolCallHeader(tool: String, args: String)
    case toolResultContent(text: String)
    case toolBlockBottom(width: Int)
    case thinking(frameIndex: Int)
    case banner(text: String)
    case empty
}
