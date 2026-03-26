// ABOUTME: Layout data for a single pane in the tmux grid.
// ABOUTME: Produced by TmuxLayoutEngine, consumed by PaneController.

import Foundation

struct PaneLayout: Identifiable, Equatable {
    let id: UUID
    var frame: CGRect
    var isActive: Bool
}
