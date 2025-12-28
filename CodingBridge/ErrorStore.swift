import SwiftUI

// MARK: - Displayable Error

/// An error ready for display in the UI with optional retry action
struct DisplayableError: Identifiable {
    let id: UUID
    let error: AppError
    let timestamp: Date
    let retryAction: (() -> Void)?
    var isExpanded: Bool = false
    var isRetrying: Bool = false

    init(error: AppError, retryAction: (() -> Void)? = nil) {
        self.id = UUID()
        self.error = error
        self.timestamp = Date()
        self.retryAction = retryAction
    }

    /// Title for the error banner
    var title: String {
        ErrorAlert(error).title
    }

    /// Description of what went wrong
    var description: String {
        error.errorDescription ?? "An error occurred"
    }

    /// Recovery suggestion for the user
    var recoverySuggestion: String? {
        error.recoverySuggestion
    }

    /// Whether this error can be retried
    var canRetry: Bool {
        error.isRetryable && retryAction != nil
    }
}

// MARK: - Error Store

/// Global singleton for managing error display across the app
/// Post errors from any manager or view, and they'll be displayed as toast banners
@MainActor
class ErrorStore: ObservableObject {
    static let shared = ErrorStore()

    /// The currently displayed error (if any)
    @Published var currentError: DisplayableError?

    /// Queue of pending errors to display
    @Published private(set) var errorQueue: [DisplayableError] = []

    /// Auto-dismiss timer
    private var dismissTask: Task<Void, Never>?

    /// Auto-dismiss delay in seconds
    private let autoDismissDelay: TimeInterval = 5.0

    /// Debounce window for duplicate errors
    private let debounceWindow: TimeInterval = 2.0

    /// Recently posted error types for deduplication
    private var recentErrors: [(type: String, timestamp: Date)] = []

    private init() {}

    // MARK: - Public API

    /// Post an error to be displayed
    /// - Parameters:
    ///   - error: The AppError to display
    ///   - retryAction: Optional closure to retry the failed operation
    func post(_ error: AppError, retryAction: (() -> Void)? = nil) {
        // Deduplicate rapid duplicate errors
        let errorType = String(describing: error)
        let now = Date()

        // Clean up old entries
        recentErrors.removeAll { now.timeIntervalSince($0.timestamp) > debounceWindow }

        // Check for duplicate
        if recentErrors.contains(where: { $0.type == errorType }) {
            log.debug("Skipping duplicate error: \(errorType)")
            return
        }

        // Track this error
        recentErrors.append((type: errorType, timestamp: now))

        let displayable = DisplayableError(error: error, retryAction: retryAction)
        log.info("Error posted: \(displayable.title) - \(displayable.description)")

        if currentError == nil {
            // Show immediately
            showError(displayable)
        } else {
            // Queue for later
            errorQueue.append(displayable)
            log.debug("Error queued (\(self.errorQueue.count) pending)")
        }
    }

    /// Dismiss the current error and show the next one (if any)
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil

        withAnimation(.easeOut(duration: 0.2)) {
            currentError = nil
        }

        // Show next error after a brief delay
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            showNextError()
        }
    }

    /// Toggle the expanded state to show/hide recovery suggestion
    func toggleExpanded() {
        guard currentError != nil else { return }

        currentError?.isExpanded.toggle()

        // Cancel auto-dismiss if user expanded
        if currentError?.isExpanded == true {
            dismissTask?.cancel()
            dismissTask = nil
            log.debug("Auto-dismiss cancelled - user expanded error details")
        } else {
            startAutoDismiss()
        }
    }

    /// Retry the current error's action
    func retry() {
        guard let error = currentError, let action = error.retryAction else { return }

        // Mark as retrying
        currentError?.isRetrying = true
        log.info("Retrying action for: \(error.title)")

        // Execute retry action
        Task {
            action()

            // Dismiss after retry (the retry action should post a new error if it fails again)
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                dismiss()
            }
        }
    }

    /// Clear all errors
    func clearAll() {
        dismissTask?.cancel()
        dismissTask = nil
        currentError = nil
        errorQueue.removeAll()
        recentErrors.removeAll()
        log.info("All errors cleared")
    }

    // MARK: - Private Helpers

    private func showError(_ error: DisplayableError) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentError = error
        }
        startAutoDismiss()
    }

    private func showNextError() {
        guard !errorQueue.isEmpty else { return }
        let next = errorQueue.removeFirst()
        showError(next)
    }

    private func startAutoDismiss() {
        dismissTask?.cancel()
        dismissTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(autoDismissDelay * 1_000_000_000))
                if !Task.isCancelled {
                    dismiss()
                }
            } catch {
                // Task was cancelled, ignore
            }
        }
    }
}
