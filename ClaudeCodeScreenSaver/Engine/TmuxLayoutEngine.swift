// ABOUTME: Binary tree-based pane layout engine with split/close/resize operations.
// ABOUTME: Produces PaneLayout arrays consumed by PaneController to position panes on screen.

import Foundation
import CoreText

// MARK: - Seeded RNG

/// A simple linear congruential generator for deterministic, seedable randomness.
private struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        // LCG constants from Numerical Recipes
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    /// Returns a Double in [0, 1)
    mutating func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    /// Returns an Int in [0, upperBound)
    mutating func nextInt(_ upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(next() % UInt64(upperBound))
    }

    /// Returns a Double in [lo, hi]
    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + nextDouble() * (range.upperBound - range.lowerBound)
    }
}

// MARK: - Tree Nodes

private enum SplitAxis {
    case horizontal // splits left/right (vertical divider)
    case vertical   // splits top/bottom (horizontal divider)
}

private class LayoutNode {
    // Leaf nodes hold a pane; internal nodes hold a split.
}

private class LeafNode: LayoutNode {
    let id: UUID
    var isActive: Bool

    init(id: UUID = UUID(), isActive: Bool = false) {
        self.id = id
        self.isActive = isActive
    }
}

private class SplitNode: LayoutNode {
    var axis: SplitAxis
    /// Fraction of the space given to the first (left/top) child. Constrained to 0.4...0.6.
    var ratio: Double
    var first: LayoutNode
    var second: LayoutNode

    init(axis: SplitAxis, ratio: Double, first: LayoutNode, second: LayoutNode) {
        self.axis = axis
        self.ratio = ratio
        self.first = first
        self.second = second
    }
}

// MARK: - TmuxLayoutEngine

/// Manages a binary-tree pane layout, supporting split, close, and resize mutations.
final class TmuxLayoutEngine {
    private let bounds: CGRect
    private let minPanes: Int
    private let maxPanes: Int
    private var rng: SeededRNG
    private var root: LayoutNode

    // Minimum pane size in pixels (computed from 40 cols × 10 rows at 9pt Menlo).
    private let minPaneWidth: CGFloat
    private let minPaneHeight: CGFloat

    init(bounds: CGRect, minPanes: Int, maxPanes: Int, seed: UInt64) {
        self.bounds = bounds
        self.minPanes = max(1, minPanes)
        self.maxPanes = max(self.minPanes, maxPanes)
        self.rng = SeededRNG(seed: seed)

        // Compute minimum pane pixel dimensions from 9pt Menlo metrics.
        let floorFont = CTFontCreateWithName("Menlo" as CFString, 9.0, nil)
        var glyphs: [CGGlyph] = [0]
        let chars: [UniChar] = [0x4D] // 'M'
        CTFontGetGlyphsForCharacters(floorFont, chars, &glyphs, 1)
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(floorFont, .horizontal, glyphs, &advance, 1)
        self.minPaneWidth = CGFloat(40) * advance.width
        let lineHeight = CTFontGetAscent(floorFont) + CTFontGetDescent(floorFont) + CTFontGetLeading(floorFont)
        self.minPaneHeight = CGFloat(10) * lineHeight

        // Build the initial leaf and then randomly split until we reach a target count.
        let initialLeaf = LeafNode(isActive: true)
        self.root = initialLeaf

        // Target pane count in minPanes...maxPanes, biased toward the midpoint.
        let targetCount = self.minPanes + self.rng.nextInt(self.maxPanes - self.minPanes + 1)
        for _ in 1..<targetCount {
            self.splitRandomLeaf()
        }
    }

    // MARK: - Public API

    /// Returns the current list of pane layouts with computed frames.
    func currentLayouts() -> [PaneLayout] {
        var results: [PaneLayout] = []
        collectLayouts(node: root, frame: bounds, into: &results)
        return results
    }

    /// Attempts to split a random leaf node. Returns true if a split occurred.
    @discardableResult
    func trySplit() -> Bool {
        let layouts = currentLayouts()
        guard layouts.count < maxPanes else { return false }
        return splitRandomLeaf()
    }

    /// Attempts to close a random leaf node. Returns true if a close occurred.
    @discardableResult
    func tryClose() -> Bool {
        let layouts = currentLayouts()
        guard layouts.count > minPanes else { return false }

        // Collect all leaf parents and their positions.
        var candidates: [(parent: SplitNode, isFirst: Bool)] = []
        collectLeafParents(node: root, into: &candidates)

        guard !candidates.isEmpty else { return false }

        let idx = rng.nextInt(candidates.count)
        let (parent, isFirst) = candidates[idx]

        // Identify the sibling that will be promoted.
        let sibling = isFirst ? parent.second : parent.first

        // If the closed leaf was active, transfer the active flag to a remaining leaf.
        let removedLeaf = isFirst ? parent.first : parent.second
        let removedWasActive = (removedLeaf as? LeafNode)?.isActive ?? leafIsActive(removedLeaf)

        // Replace root or the parent's parent reference.
        replaceNode(parent, with: sibling, in: &root)

        if removedWasActive {
            activateFirstLeaf(in: root)
        }

        return true
    }

    /// Shifts a random internal node's split ratio by 5–15%.
    func tryResize() {
        var nodes: [SplitNode] = []
        collectSplitNodes(node: root, into: &nodes)
        guard !nodes.isEmpty else { return }

        let node = nodes[rng.nextInt(nodes.count)]
        let delta = rng.nextDouble(in: 0.05...0.15) * (rng.nextDouble() < 0.5 ? 1.0 : -1.0)
        node.ratio = min(0.6, max(0.4, node.ratio + delta))
    }

    // MARK: - Private helpers

    /// Walks the tree and computes frames, collecting PaneLayout values.
    private func collectLayouts(node: LayoutNode, frame: CGRect, into results: inout [PaneLayout]) {
        if let leaf = node as? LeafNode {
            results.append(PaneLayout(id: leaf.id, frame: frame, isActive: leaf.isActive))
        } else if let splitNode = node as? SplitNode {
            let (firstFrame, secondFrame) = splitFrame(frame, axis: splitNode.axis, ratio: splitNode.ratio)
            collectLayouts(node: splitNode.first, frame: firstFrame, into: &results)
            collectLayouts(node: splitNode.second, frame: secondFrame, into: &results)
        }
    }

    /// Splits a frame along an axis at the given ratio.
    private func splitFrame(_ frame: CGRect, axis: SplitAxis, ratio: Double) -> (CGRect, CGRect) {
        switch axis {
        case .horizontal:
            let w = frame.width * CGFloat(ratio)
            let left = CGRect(x: frame.minX, y: frame.minY, width: w, height: frame.height)
            let right = CGRect(x: frame.minX + w, y: frame.minY, width: frame.width - w, height: frame.height)
            return (left, right)
        case .vertical:
            let h = frame.height * CGFloat(ratio)
            let top = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: h)
            let bottom = CGRect(x: frame.minX, y: frame.minY + h, width: frame.width, height: frame.height - h)
            return (top, bottom)
        }
    }

    /// Finds a leaf in the tree large enough to split, and performs the split.
    @discardableResult
    private func splitRandomLeaf() -> Bool {
        // Gather all (leaf, frame) pairs large enough to be split.
        var candidates: [(LeafNode, CGRect)] = []
        collectSplittableLeaves(node: root, frame: bounds, into: &candidates)
        guard !candidates.isEmpty else { return false }

        let idx = rng.nextInt(candidates.count)
        let (leaf, leafFrame) = candidates[idx]

        // Pick axis: prefer splitting the longer dimension.
        let axis: SplitAxis
        let canSplitH = leafFrame.width >= minPaneWidth * 2
        let canSplitV = leafFrame.height >= minPaneHeight * 2
        if canSplitH && canSplitV {
            axis = leafFrame.width >= leafFrame.height ? .horizontal : .vertical
        } else if canSplitH {
            axis = .horizontal
        } else if canSplitV {
            axis = .vertical
        } else {
            return false
        }

        let ratio = rng.nextDouble(in: 0.4...0.6)
        let newLeaf = LeafNode(isActive: false)
        let splitNode = SplitNode(axis: axis, ratio: ratio, first: leaf, second: newLeaf)

        replaceNode(leaf, with: splitNode, in: &root)
        return true
    }

    /// Collects leaf nodes whose frames are large enough to be split.
    private func collectSplittableLeaves(node: LayoutNode, frame: CGRect, into results: inout [(LeafNode, CGRect)]) {
        if let leaf = node as? LeafNode {
            let canSplitH = frame.width >= minPaneWidth * 2
            let canSplitV = frame.height >= minPaneHeight * 2
            if canSplitH || canSplitV {
                results.append((leaf, frame))
            }
        } else if let split = node as? SplitNode {
            let (firstFrame, secondFrame) = self.splitFrame(frame, axis: split.axis, ratio: split.ratio)
            collectSplittableLeaves(node: split.first, frame: firstFrame, into: &results)
            collectSplittableLeaves(node: split.second, frame: secondFrame, into: &results)
        }
    }

    /// Collects (parent SplitNode, isFirst) pairs for all leaf nodes.
    private func collectLeafParents(node: LayoutNode, into results: inout [(parent: SplitNode, isFirst: Bool)]) {
        guard let split = node as? SplitNode else { return }
        if split.first is LeafNode { results.append((split, true)) }
        if split.second is LeafNode { results.append((split, false)) }
        collectLeafParents(node: split.first, into: &results)
        collectLeafParents(node: split.second, into: &results)
    }

    /// Recursively replaces `target` with `replacement` anywhere in the subtree rooted at `nodeRef`.
    private func replaceNode(_ target: LayoutNode, with replacement: LayoutNode, in nodeRef: inout LayoutNode) {
        if nodeRef === target {
            nodeRef = replacement
            return
        }
        guard let split = nodeRef as? SplitNode else { return }
        if split.first === target {
            split.first = replacement
        } else if split.second === target {
            split.second = replacement
        } else {
            replaceNode(target, with: replacement, in: &split.first)
            replaceNode(target, with: replacement, in: &split.second)
        }
    }

    /// Collects all SplitNode instances in the tree.
    private func collectSplitNodes(node: LayoutNode, into results: inout [SplitNode]) {
        guard let split = node as? SplitNode else { return }
        results.append(split)
        collectSplitNodes(node: split.first, into: &results)
        collectSplitNodes(node: split.second, into: &results)
    }

    /// Activates the leftmost leaf in the subtree.
    private func activateFirstLeaf(in node: LayoutNode) {
        if let leaf = node as? LeafNode {
            leaf.isActive = true
        } else if let split = node as? SplitNode {
            activateFirstLeaf(in: split.first)
        }
    }

    /// Returns true if any leaf in the subtree is active.
    private func leafIsActive(_ node: LayoutNode) -> Bool {
        if let leaf = node as? LeafNode { return leaf.isActive }
        if let split = node as? SplitNode {
            return leafIsActive(split.first) || leafIsActive(split.second)
        }
        return false
    }

    /// Sets the active flag on the leaf matching `id` to `active`, leaving others unchanged.
    private func setActive(id: UUID, active: Bool, in node: LayoutNode) {
        if let leaf = node as? LeafNode {
            if leaf.id == id { leaf.isActive = active }
        } else if let split = node as? SplitNode {
            setActive(id: id, active: active, in: split.first)
            setActive(id: id, active: active, in: split.second)
        }
    }
}
