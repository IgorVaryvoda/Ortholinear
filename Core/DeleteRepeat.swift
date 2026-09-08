import Foundation

/// Elapsed time is measured from touch-down, and starts fresh for every press.
enum DeleteRepeat {
    static let initialDelay: TimeInterval = 0.42

    static func interval(heldFor duration: TimeInterval) -> TimeInterval {
        // Ease from precise character deletion to fast clearing over four seconds.
        let progress = min(1, max(0, (duration - initialDelay) / 4))
        return 0.12 - 0.095 * progress
    }
}
