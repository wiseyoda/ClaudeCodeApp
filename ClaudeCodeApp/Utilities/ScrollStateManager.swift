import SwiftUI

/// Manages scroll state for chat views with debouncing and user intent tracking.
@MainActor
final class ScrollStateManager: ObservableObject {
    /// Whether auto-scroll is currently enabled (user hasn't scrolled up).
    @Published private(set) var isAutoScrollEnabled = true

    /// Pending scroll request (debounced).
    @Published private(set) var shouldScroll = false

    /// Debounce timer for scroll requests.
    private var scrollDebounceTask: Task<Void, Never>?

    /// Debounce delay for scroll requests (50ms coalesces rapid updates).
    private let debounceDelay: UInt64 = 50_000_000  // nanoseconds

    /// Track if we're in the middle of a scroll animation.
    private var isScrolling = false

    // MARK: - Public API

    /// Request a scroll to bottom (debounced).
    /// - Parameter animated: Whether to animate the scroll.
    func requestScrollToBottom(animated: Bool = true) {
        guard isAutoScrollEnabled else { return }

        // Cancel any pending scroll.
        scrollDebounceTask?.cancel()

        // Debounce the scroll request.
        scrollDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.debounceDelay ?? 50_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self?.performScroll(animated: animated)
            }
        }
    }

    /// Force an immediate scroll to bottom (no debounce).
    /// - Parameter animated: Whether to animate the scroll.
    func forceScrollToBottom(animated: Bool = true) {
        isAutoScrollEnabled = true
        scrollDebounceTask?.cancel()
        performScroll(animated: animated)
    }

    /// Reset scroll state (e.g., when loading new content).
    func reset() {
        isAutoScrollEnabled = true
        scrollDebounceTask?.cancel()
        scrollDebounceTask = nil
        isScrolling = false
        shouldScroll = false
    }

    // MARK: - Private

    private func performScroll(animated: Bool) {
        guard !isScrolling else { return }

        isScrolling = true
        shouldScroll = true

        // Reset the flag after animation completes.
        Task {
            try? await Task.sleep(nanoseconds: animated ? 200_000_000 : 50_000_000)
            await MainActor.run {
                self.shouldScroll = false
                self.isScrolling = false
            }
        }
    }

    deinit {
        scrollDebounceTask?.cancel()
    }
}
