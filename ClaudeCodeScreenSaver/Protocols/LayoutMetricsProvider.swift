// ABOUTME: Protocol abstracting screen geometry for testability.
// ABOUTME: Allows tests to provide custom screen bounds.

import Foundation

protocol LayoutMetricsProvider {
    var screenBounds: CGRect { get }
}
