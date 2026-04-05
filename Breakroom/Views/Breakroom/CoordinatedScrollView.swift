import SwiftUI
import UIKit

/// A ScrollView that coordinates with other scroll views via ScrollCoordinator.
/// Supports velocity tracking, edge detection, and scroll locking.
struct CoordinatedScrollView<Content: View>: UIViewRepresentable {
    let scrollType: ScrollType
    let coordinator: ScrollCoordinator
    let axes: Axis.Set
    let showsIndicators: Bool
    let bounces: Bool
    @ViewBuilder let content: () -> Content

    init(
        scrollType: ScrollType,
        coordinator: ScrollCoordinator,
        axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        bounces: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.scrollType = scrollType
        self.coordinator = coordinator
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.bounces = bounces
        self.content = content
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsVerticalScrollIndicator = showsIndicators && axes.contains(.vertical)
        scrollView.showsHorizontalScrollIndicator = showsIndicators && axes.contains(.horizontal)
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false

        // For inner scrolls, we control bounce based on edge transfer
        if scrollType == .inner {
            scrollView.bounces = false
        } else {
            scrollView.bounces = bounces
        }

        // Host the SwiftUI content
        let hostController = UIHostingController(rootView: content())
        hostController.view.backgroundColor = .clear
        hostController.view.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(hostController.view)

        NSLayoutConstraint.activate([
            hostController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        context.coordinator.hostController = hostController
        context.coordinator.scrollCoordinator = self.coordinator
        context.coordinator.scrollType = self.scrollType

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.hostController?.rootView = content()
        context.coordinator.scrollCoordinator = self.coordinator
        context.coordinator.scrollType = self.scrollType

        // Check for pending edge transfer velocity (for outer scroll)
        if scrollType == .outer, let transferVelocity = coordinator.consumeEdgeTransferVelocity() {
            // Apply the momentum to outer scroll
            let currentOffset = scrollView.contentOffset
            let maxOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)

            // Determine direction and apply velocity
            if transferVelocity < 0 {
                // Scrolling up (content moving down)
                let targetOffset = max(0, currentOffset.y + transferVelocity * 0.5)
                scrollView.setContentOffset(CGPoint(x: currentOffset.x, y: targetOffset), animated: true)
            } else {
                // Scrolling down (content moving up)
                let targetOffset = min(maxOffset, currentOffset.y + transferVelocity * 0.5)
                scrollView.setContentOffset(CGPoint(x: currentOffset.x, y: targetOffset), animated: true)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostController: UIHostingController<Content>?
        weak var scrollCoordinator: ScrollCoordinator?
        var scrollType: ScrollType = .none

        private var lastContentOffset: CGPoint = .zero
        private var lastUpdateTime: Date = Date()
        private var currentVelocity: CGFloat = 0
        private var isDragging = false

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            guard let coordinator = scrollCoordinator else { return }

            // Inner scrolls claim immediately
            if scrollType == .inner {
                coordinator.beginDrag(type: .inner)
                isDragging = true
                scrollView.isScrollEnabled = true
            } else {
                // Outer scroll: check if inner scroll already claimed
                // Give a tiny delay to let inner scroll claim first
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, let coordinator = self.scrollCoordinator else { return }

                    // Only claim if inner hasn't taken over
                    if coordinator.activeScrollType != .inner {
                        coordinator.beginDrag(type: .outer)
                        self.isDragging = true
                    }
                }
            }

            lastContentOffset = scrollView.contentOffset
            lastUpdateTime = Date()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let coordinator = scrollCoordinator else { return }

            // Only process if this scroll type is the active one
            guard coordinator.activeScrollType == scrollType || (scrollType == .inner && isDragging) else {
                return
            }

            // Calculate velocity
            let now = Date()
            let timeDelta = now.timeIntervalSince(lastUpdateTime)
            if timeDelta > 0 {
                let offsetDelta = scrollView.contentOffset.y - lastContentOffset.y
                currentVelocity = offsetDelta / timeDelta
                coordinator.updateVelocity(currentVelocity)
            }

            lastContentOffset = scrollView.contentOffset
            lastUpdateTime = now

            // Check for edge hits (inner scroll only, during active drag)
            if scrollType == .inner && isDragging {
                let offset = scrollView.contentOffset.y
                let maxOffset = scrollView.contentSize.height - scrollView.bounds.height

                // Hit top edge while scrolling up
                if offset <= 0 && currentVelocity < -10 {
                    coordinator.innerScrollHitEdge(velocity: currentVelocity)
                    scrollView.contentOffset.y = 0
                }
                // Hit bottom edge while scrolling down
                else if offset >= maxOffset && maxOffset > 0 && currentVelocity > 10 {
                    coordinator.innerScrollHitEdge(velocity: currentVelocity)
                    scrollView.contentOffset.y = maxOffset
                }
            }
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            isDragging = false
            scrollCoordinator?.endDrag()

            if !decelerate {
                scrollCoordinator?.scrollDidStop()
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            scrollCoordinator?.scrollDidStop()
        }

        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            // Update coordinator with final velocity
            scrollCoordinator?.updateVelocity(velocity.y * 1000) // Convert to points/sec
        }
    }
}

// MARK: - Inner Scroll View (convenience wrapper for widgets)

struct InnerScrollView<Content: View>: View {
    let coordinator: ScrollCoordinator
    let maxHeight: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        CoordinatedScrollView(
            scrollType: .inner,
            coordinator: coordinator,
            showsIndicators: true,
            bounces: false,
            content: content
        )
        .frame(maxHeight: maxHeight)
    }
}
