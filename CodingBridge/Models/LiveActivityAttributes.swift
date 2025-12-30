import Foundation
import ActivityKit

// MARK: - Live Activity Attributes
// Data models for CodingBridge Live Activities
// Used for displaying task progress on Lock Screen and Dynamic Island

/// Static attributes for the Live Activity (set once when activity starts)
struct CodingBridgeAttributes: ActivityAttributes {
    /// Unique session identifier
    let sessionId: String

    /// Project name being worked on
    let projectName: String

    /// Model name (e.g., "claude-sonnet-4")
    let modelName: String?

    /// When the task started
    let startedAt: Date

    /// Dynamic state that updates during the activity
    struct ContentState: Codable, Hashable {
        /// Current activity status
        var status: LiveActivityStatus

        /// Human-readable description of current operation
        var currentOperation: String?

        /// Seconds since task started
        var elapsedSeconds: Int

        /// Todo list progress (if available)
        var todoProgress: LAProgress?

        /// Pending approval request (if waiting)
        var approvalRequest: LAApprovalInfo?

        /// Pending question (if waiting for answer)
        var question: LAQuestionInfo?

        /// Error information (if error occurred)
        var error: LAErrorInfo?

        init(
            status: LiveActivityStatus,
            currentOperation: String? = nil,
            elapsedSeconds: Int = 0,
            todoProgress: LAProgress? = nil,
            approvalRequest: LAApprovalInfo? = nil,
            question: LAQuestionInfo? = nil,
            error: LAErrorInfo? = nil
        ) {
            self.status = status
            self.currentOperation = currentOperation
            self.elapsedSeconds = elapsedSeconds
            self.todoProgress = todoProgress
            self.approvalRequest = approvalRequest
            self.question = question
            self.error = error
        }
    }
}

// MARK: - Live Activity Status

/// Status values for Live Activity display
enum LiveActivityStatus: String, Codable, Hashable {
    /// Claude is actively processing
    case processing

    /// Waiting for tool approval
    case awaitingApproval = "awaiting_approval"

    /// Waiting for user to answer a question
    case awaitingAnswer = "awaiting_answer"

    /// Task completed successfully
    case complete

    /// Error occurred
    case error

    /// Display text for the status
    var displayText: String {
        switch self {
        case .processing:
            return "Working..."
        case .awaitingApproval:
            return "Needs Approval"
        case .awaitingAnswer:
            return "Question"
        case .complete:
            return "Complete"
        case .error:
            return "Error"
        }
    }

    /// SF Symbol icon for the status
    var icon: String {
        switch self {
        case .processing:
            return "gearshape.2.fill"
        case .awaitingApproval:
            return "checkmark.shield.fill"
        case .awaitingAnswer:
            return "questionmark.bubble.fill"
        case .complete:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Live Activity Supporting Types
// Using LA prefix to avoid conflicts with existing types

/// Progress through a todo list (for Live Activities)
struct LAProgress: Codable, Hashable {
    /// Number of completed tasks
    let completed: Int

    /// Total number of tasks
    let total: Int

    /// Current task being worked on
    let currentTask: String?

    /// Progress as percentage (0-100)
    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total) * 100
    }

    /// Display string like "2/5"
    var displayText: String {
        "\(completed)/\(total)"
    }

    /// Convert from the main TodoProgress type
    init(from progress: TodoProgress) {
        self.completed = progress.completed
        self.total = progress.total
        self.currentTask = progress.currentTask
    }

    init(completed: Int, total: Int, currentTask: String? = nil) {
        self.completed = completed
        self.total = total
        self.currentTask = currentTask
    }
}

/// Information about a pending approval request (for Live Activities)
struct LAApprovalInfo: Codable, Hashable {
    /// Unique approval request ID
    let id: String

    /// Tool name requiring approval
    let toolName: String

    /// Brief summary of what's being requested
    let summary: String
}

/// Information about a pending question (for Live Activities)
struct LAQuestionInfo: Codable, Hashable {
    /// Unique question ID
    let id: String

    /// Preview of the question text
    let preview: String
}

/// Information about an error (for Live Activities)
struct LAErrorInfo: Codable, Hashable {
    /// Error message
    let message: String

    /// Whether the error is recoverable
    let recoverable: Bool
}

// MARK: - Factory Methods

extension CodingBridgeAttributes.ContentState {
    /// Create initial processing state
    static func processing(operation: String? = "Starting...") -> CodingBridgeAttributes.ContentState {
        CodingBridgeAttributes.ContentState(status: .processing, currentOperation: operation)
    }

    /// Create awaiting approval state
    static func awaitingApproval(approval: LAApprovalInfo) -> CodingBridgeAttributes.ContentState {
        CodingBridgeAttributes.ContentState(
            status: .awaitingApproval,
            currentOperation: "Waiting for approval: \(approval.toolName)",
            approvalRequest: approval
        )
    }

    /// Create awaiting answer state
    static func awaitingAnswer(question: LAQuestionInfo) -> CodingBridgeAttributes.ContentState {
        CodingBridgeAttributes.ContentState(
            status: .awaitingAnswer,
            currentOperation: "Question from Claude",
            question: question
        )
    }

    /// Create completed state
    static func complete(elapsedSeconds: Int) -> CodingBridgeAttributes.ContentState {
        CodingBridgeAttributes.ContentState(
            status: .complete,
            currentOperation: "Task completed",
            elapsedSeconds: elapsedSeconds
        )
    }

    /// Create error state
    static func error(_ error: LAErrorInfo) -> CodingBridgeAttributes.ContentState {
        CodingBridgeAttributes.ContentState(
            status: .error,
            currentOperation: error.message,
            error: error
        )
    }
}
