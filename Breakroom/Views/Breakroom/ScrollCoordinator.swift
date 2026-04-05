import SwiftUI
import Combine

enum ScrollType {
    case none
    case outer
    case inner
}

@Observable
final class ScrollCoordinator {
    // MARK: - Configuration
    let velocityThreshold: CGFloat = 150 // points per second

    // MARK: - State
    private(set) var activeScrollType: ScrollType = .none
    private(set) var currentVelocity: CGFloat = 0
    private(set) var isDragging: Bool = false

    // For edge transfer during active drag
    private(set) var pendingEdgeTransferVelocity: CGFloat? = nil

    // MARK: - Public API

    /// Called when a scroll view wants to begin scrolling.
    /// Returns true if this scroll type is allowed to scroll.
    func requestScroll(type: ScrollType) -> Bool {
        // If nothing is active and we're below threshold, allow new scroll
        if activeScrollType == .none || currentVelocity < velocityThreshold {
            activeScrollType = type
            return true
        }

        // If same type is active, allow
        if activeScrollType == type {
            return true
        }

        // Different type is active and above threshold - deny
        return false
    }

    /// Called when drag begins
    /// Inner scrolls get priority when nothing is actively scrolling above threshold
    func beginDrag(type: ScrollType) {
        // Inner scroll always gets priority when system is idle or below threshold
        if type == .inner {
            if activeScrollType == .none || currentVelocity < velocityThreshold {
                activeScrollType = .inner
                isDragging = true
                pendingEdgeTransferVelocity = nil
                return
            } else if activeScrollType == .inner {
                isDragging = true
                return
            }
            // Outer is active above threshold - inner is blocked
            return
        }

        // Outer scroll: only take over if nothing active or below threshold AND not inner
        if activeScrollType == .none || (currentVelocity < velocityThreshold && activeScrollType != .inner) {
            activeScrollType = type
            isDragging = true
            pendingEdgeTransferVelocity = nil
        } else if activeScrollType == type {
            isDragging = true
        }
        // If different type is active above threshold, this drag is ignored
    }

    /// Called when drag ends
    func endDrag() {
        isDragging = false
        // activeScrollType stays locked until velocity drops below threshold
    }

    /// Called continuously with current scroll velocity
    func updateVelocity(_ velocity: CGFloat) {
        currentVelocity = abs(velocity)

        // If velocity drops below threshold and not dragging, release lock
        if currentVelocity < velocityThreshold && !isDragging {
            activeScrollType = .none
        }
    }

    /// Called when inner scroll hits an edge during active drag
    /// Triggers transfer to outer scroll with current velocity
    func innerScrollHitEdge(velocity: CGFloat) {
        guard isDragging && activeScrollType == .inner else { return }

        // Store velocity for outer scroll to pick up
        pendingEdgeTransferVelocity = velocity
        activeScrollType = .outer
    }

    /// Called by outer scroll to check if it should pick up momentum from edge transfer
    func consumeEdgeTransferVelocity() -> CGFloat? {
        guard let velocity = pendingEdgeTransferVelocity else { return nil }
        pendingEdgeTransferVelocity = nil
        return velocity
    }

    /// Called when scroll completely stops (deceleration finished)
    func scrollDidStop() {
        if !isDragging {
            currentVelocity = 0
            activeScrollType = .none
        }
    }

    /// Check if a scroll type is currently allowed to scroll
    func canScroll(type: ScrollType) -> Bool {
        // Inner scrolls get priority when nothing is scrolling fast
        if type == .inner {
            if activeScrollType == .none || activeScrollType == .inner {
                return true
            }
            // Outer is active - only allow inner if below threshold
            return currentVelocity < velocityThreshold
        }

        // Outer scroll
        if activeScrollType == .none {
            return true
        }
        if activeScrollType == .outer {
            return true
        }
        // Inner is active - only allow outer if below threshold
        return currentVelocity < velocityThreshold
    }
}
