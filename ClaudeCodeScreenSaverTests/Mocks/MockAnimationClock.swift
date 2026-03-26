// ABOUTME: Test double for AnimationClock protocol.
// ABOUTME: Allows tests to control time progression precisely.

import Foundation

class MockAnimationClock: AnimationClock {
    var currentTime: TimeInterval = 0.0
    func advance(by interval: TimeInterval) { currentTime += interval }
}
