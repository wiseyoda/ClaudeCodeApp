import SwiftUI

/// Manages scroll state for chat views with debouncing and user intent tracking.
///
/// This manager prevents UI freezes by:
/// 1. Debouncing rapid scroll position updates from onPreferenceChange
/// 2. Coalescing scroll requests during message streaming
/// 3. Tracking user scroll intent to avoid fighting with auto-scroll
@MainActor
final class ScrollStateManager: ObservableObject {
    /// Whether auto-scroll is currently enabled (user hasn't scrolled up).
    @Published private(set) var isAutoScrollEnabled = true

    /// Pending scroll request (debounced).
    @Published private(set) var shouldScroll = false

    /// Debounce timer for scroll requests.
    private var scrollDebounceTask: Task<Void, Never>?

    /// Debounce timer for scroll position updates (prevents UI freeze from rapid onPreferenceChange).
    private var scrollPositionDebounceTask: Task<Void, Never>?

    /// Debounce delay for scroll requests (100ms coalesces rapid streaming updates).
    private let debounceDelay: UInt64 = 100_000_000  // nanoseconds

    /// Debounce delay for scroll position detection (50ms to coalesce rapid onPreferenceChange calls).
    private let positionDebounceDelay: UInt64 = 50_000_000  // nanoseconds

    /// Track if we're in the middle of a scroll animation.
    private var isScrolling = false

    /// Tracks when user last scrolled (to detect active scrolling)
    private var lastUserScrollTime: Date?

    /// Time window during which we consider user to be actively scrolling
    private let userScrollCooldown: TimeInterval = 0.5

    /// Last reported scroll offset (to avoid redundant state updates)
    private var lastReportedOffset: CGFloat = 0

    /// Threshold for considering offset changes significant (reduces noise)
    private let offsetThreshold: CGFloat = 30

    // MARK: - Public API

    /// Call this from onPreferenceChange with the current scroll offset.
    /// This method debounces rapid calls to prevent UI freezes during scrolling.
    /// - Parameter offset: The current scroll offset (negative when scrolled down, 0 at top)
    func handleScrollOffset(_ offset: CGFloat) {
        // Skip if offset hasn't changed significantly (reduces state churn)
        guard abs(offset - lastReportedOffset) > offsetThreshold else { return }
        lastReportedOffset = offset

        // Cancel any pending position update
        scrollPositionDebounceTask?.cancel()

        // Debounce the actual state update
        scrollPositionDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.positionDebounceDelay ?? 50_000_000)
            guard !Task.isCancelled, let self else { return }

            // If user is more than 50pt from bottom, they're scrolling up
            if offset < -50 {
                self.userDidScrollUp()
            } else if offset >= -20 {
                // User is near bottom - re-enable auto-scroll
                self.userDidScrollToBottom()
            }
        }
    }

    /// Call this when user performs a scroll gesture (scrolls up from bottom)
    func userDidScrollUp() {
        // Avoid redundant state updates
        guard isAutoScrollEnabled else { return }
        isAutoScrollEnabled = false
        lastUserScrollTime = Date()
        scrollDebounceTask?.cancel()  // Cancel any pending auto-scroll
    }

    /// Call this when user scrolls back to bottom
    func userDidScrollToBottom() {
        // Avoid redundant state updates
        guard !isAutoScrollEnabled else { return }
        isAutoScrollEnabled = true
        lastUserScrollTime = nil
    }

    /// Check if user is actively scrolling (recently scrolled)
    var isUserActivelyScrolling: Bool {
        guard let lastScroll = lastUserScrollTime else { return false }
        return Date().timeIntervalSince(lastScroll) < userScrollCooldown
    }

    /// Request a scroll to bottom (debounced).
    /// - Parameter animated: Whether to animate the scroll.
    func requestScrollToBottom(animated: Bool = true) {
        // Don't interrupt user if they're actively scrolling
        guard isAutoScrollEnabled, !isUserActivelyScrolling else { return }

        // Cancel any pending scroll.
        scrollDebounceTask?.cancel()

        // Debounce the scroll request.
        scrollDebounceTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.debounceDelay)
            guard !Task.isCancelled else { return }
            self.performScroll(animated: animated)
        }
    }

    /// Force an immediate scroll to bottom (no debounce).
    /// - Parameter animated: Whether to animate the scroll.
    func forceScrollToBottom(animated: Bool = true) {
        isAutoScrollEnabled = true
        lastUserScrollTime = nil
        scrollDebounceTask?.cancel()
        performScroll(animated: animated)
    }

    /// Reset scroll state (e.g., when loading new content).
    func reset() {
        isAutoScrollEnabled = true
        lastUserScrollTime = nil
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
        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: animated ? 200_000_000 : 50_000_000)
            self.shouldScroll = false
            self.isScrolling = false
        }
    }

    deinit {
        scrollDebounceTask?.cancel()
        scrollPositionDebounceTask?.cancel()
    }
}
