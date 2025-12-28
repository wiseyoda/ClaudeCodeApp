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

    /// Lowest (most negative) offset observed (tracks bottom without relying on content size)
    private var lowestReportedOffset: CGFloat = 0

    /// Last reported content height
    private var lastContentHeight: CGFloat = 0

    /// Last reported viewport height
    private var lastViewportHeight: CGFloat = 0

    /// Threshold for considering offset changes significant (reduces noise)
    private let offsetThreshold: CGFloat = 30

    /// Threshold for considering "at bottom" (within this many points)
    private let atBottomThreshold: CGFloat = 100

    /// Track if bottom anchor visibility updates are driving auto-scroll state
    private var hasAnchorVisibilityUpdates = false

    // MARK: - Public API

    /// Call this from onPreferenceChange with the current scroll offset.
    /// This method debounces rapid calls to prevent UI freezes during scrolling.
    /// - Parameter offset: The content frame's minY in scroll coordinate space
    ///   - 0 when at top (not scrolled)
    ///   - Negative when scrolled down (content moved up)
    func handleScrollOffset(_ offset: CGFloat) {
        // Skip if offset hasn't changed significantly (reduces state churn)
        guard abs(offset - lastReportedOffset) > offsetThreshold else { return }
        lastReportedOffset = offset
        if offset < lowestReportedOffset {
            lowestReportedOffset = offset
        }

        // Recalculate at-bottom status
        recalculateAtBottom()
    }

    /// Update content and viewport dimensions for at-bottom calculation
    func updateScrollDimensions(contentHeight: CGFloat, viewportHeight: CGFloat) {
        lastContentHeight = contentHeight
        lastViewportHeight = viewportHeight
        // Recalculate at-bottom status when dimensions change
        recalculateAtBottom()
    }

    /// Recalculate whether we're at the bottom based on offset and dimensions
    private func recalculateAtBottom() {
        // Cancel any pending position update
        scrollPositionDebounceTask?.cancel()

        // Debounce the actual state update
        scrollPositionDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.positionDebounceDelay ?? 50_000_000)
            guard !Task.isCancelled, let self else { return }
            guard !self.hasAnchorVisibilityUpdates else { return }

            // Calculate if at bottom:
            // - scrollOffset is how much we've scrolled (negative of minY)
            // - maxScroll is the maximum we can scroll (contentHeight - viewportHeight)
            // - If scrollOffset is close to maxScroll, we're at the bottom
            let scrollOffset = -self.lastReportedOffset
            let maxScroll = max(0, self.lastContentHeight - self.lastViewportHeight)
            let dimensionDistance = maxScroll - scrollOffset
            let offsetDistance = self.lowestReportedOffset < 0
                ? max(0, self.lastReportedOffset - self.lowestReportedOffset)
                : 0
            let distanceFromBottom = max(dimensionDistance, offsetDistance)
            if distanceFromBottom < self.atBottomThreshold {
                self.userDidScrollToBottom()
            } else {
                self.userDidScrollUp()
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

    /// Record user scroll activity without changing auto-scroll state.
    func recordUserScrollGesture() {
        lastUserScrollTime = Date()
    }

    /// Call this when user scrolls back to bottom
    func userDidScrollToBottom() {
        // Avoid redundant state updates
        guard !isAutoScrollEnabled else { return }
        isAutoScrollEnabled = true
        lastUserScrollTime = nil
    }

    /// Update auto-scroll state based on bottom anchor visibility
    /// This is more reliable than offset tracking
    func updateBottomAnchorVisible(_ isVisible: Bool) {
        hasAnchorVisibilityUpdates = true
        if isVisible {
            // At bottom - enable auto-scroll, hide button
            guard !isAutoScrollEnabled else { return }
            isAutoScrollEnabled = true
            lastUserScrollTime = nil
        } else {
            // Not at bottom - only disable if the user is actively scrolling
            guard isUserActivelyScrolling else { return }
            userDidScrollUp()
        }
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
    /// Note: Does NOT set isAutoScrollEnabled=true immediately - that happens
    /// when scroll position tracking verifies we're actually at the bottom.
    /// This prevents the button from hiding before scroll completes.
    /// - Parameter animated: Whether to animate the scroll.
    func forceScrollToBottom(animated: Bool = true) {
        // Don't prematurely set isAutoScrollEnabled = true
        // Let handleScrollOffset() verify we're actually at bottom
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
        scrollPositionDebounceTask?.cancel()
        scrollPositionDebounceTask = nil
        isScrolling = false
        shouldScroll = false
        // Reset last offset to ensure first position update isn't skipped
        lastReportedOffset = 0
        lowestReportedOffset = 0
        lastContentHeight = 0
        lastViewportHeight = 0
        hasAnchorVisibilityUpdates = false
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
