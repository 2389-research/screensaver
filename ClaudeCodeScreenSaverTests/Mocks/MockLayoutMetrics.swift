// ABOUTME: Test double for LayoutMetricsProvider protocol.
// ABOUTME: Provides a fixed screen bounds for deterministic layout tests.

import Foundation

struct MockLayoutMetrics: LayoutMetricsProvider {
    var screenBounds: CGRect
}
