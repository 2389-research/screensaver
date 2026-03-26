// ABOUTME: Protocol abstracting time source for testability.
// ABOUTME: Allows mock clocks in tests to control animation timing.

import Foundation

protocol AnimationClock {
    var currentTime: TimeInterval { get }
}
