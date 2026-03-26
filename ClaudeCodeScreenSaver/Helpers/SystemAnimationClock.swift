// ABOUTME: Production implementation of AnimationClock using CACurrentMediaTime.
// ABOUTME: Isolated in Helpers/ because it requires QuartzCore import.

import QuartzCore

struct SystemAnimationClock: AnimationClock {
    var currentTime: TimeInterval {
        CACurrentMediaTime()
    }
}
