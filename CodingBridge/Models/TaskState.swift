import Foundation

// MARK: - Task Status

/// Represents the current status of a Claude task
enum TaskStatus: Codable, Equatable {
    case idle
    case processing(operation: String?)
    case awaitingApproval(request: BackgroundApprovalRequest)
    case awaitingAnswer(question: BackgroundUserQuestion)
    case completed(result: TaskResult)
    case error(message: String)

    // MARK: - Display Properties

    var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .processing(let operation):
            return operation ?? "Working..."
        case .awaitingApproval(let request):
            return "Needs approval: \(request.toolName)"
        case .awaitingAnswer:
            return "Question pending"
        case .completed(let result):
            switch result {
            case .success: return "Complete"
            case .failure: return "Failed"
            case .cancelled: return "Cancelled"
            }
        case .error(let message):
            return "Error: \(message)"
        }
    }

    var color: TaskStateColor {
        switch self {
        case .idle: return .gray
        case .processing: return .blue
        case .awaitingApproval: return .orange
        case .awaitingAnswer: return .purple
        case .completed(let result):
            switch result {
            case .success: return .green
            case .failure, .cancelled: return .red
            }
        case .error: return .red
        }
    }

    var requiresUserAction: Bool {
        switch self {
        case .awaitingApproval, .awaitingAnswer:
            return true
        default:
            return false
        }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type, operation, request, question, result, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "idle":
            self = .idle
        case "processing":
            let operation = try container.decodeIfPresent(String.self, forKey: .operation)
            self = .processing(operation: operation)
        case "awaitingApproval":
            let request = try container.decode(BackgroundApprovalRequest.self, forKey: .request)
            self = .awaitingApproval(request: request)
        case "awaitingAnswer":
            let question = try container.decode(BackgroundUserQuestion.self, forKey: .question)
            self = .awaitingAnswer(question: question)
        case "completed":
            let result = try container.decode(TaskResult.self, forKey: .result)
            self = .completed(result: result)
        case "error":
            let message = try container.decode(String.self, forKey: .message)
            self = .error(message: message)
        default:
            self = .idle
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .idle:
            try container.encode("idle", forKey: .type)
        case .processing(let operation):
            try container.encode("processing", forKey: .type)
            try container.encodeIfPresent(operation, forKey: .operation)
        case .awaitingApproval(let request):
            try container.encode("awaitingApproval", forKey: .type)
            try container.encode(request, forKey: .request)
        case .awaitingAnswer(let question):
            try container.encode("awaitingAnswer", forKey: .type)
            try container.encode(question, forKey: .question)
        case .completed(let result):
            try container.encode("completed", forKey: .type)
            try container.encode(result, forKey: .result)
        case .error(let message):
            try container.encode("error", forKey: .type)
            try container.encode(message, forKey: .message)
        }
    }
}

// MARK: - Task State

/// Complete state of a Claude task for persistence and Live Activity updates
struct TaskState: Codable, Equatable {
    let sessionId: String
    let projectPath: String
    var status: TaskStatus
    let startTime: Date
    var lastUpdateTime: Date
    var elapsedSeconds: Int
    var todoProgress: TodoProgress?

    init(
        sessionId: String,
        projectPath: String,
        status: TaskStatus = .idle,
        startTime: Date = Date(),
        todoProgress: TodoProgress? = nil
    ) {
        self.sessionId = sessionId
        self.projectPath = projectPath
        self.status = status
        self.startTime = startTime
        self.lastUpdateTime = startTime
        self.elapsedSeconds = 0
        self.todoProgress = todoProgress
    }

    mutating func updateStatus(_ newStatus: TaskStatus) {
        self.status = newStatus
        self.lastUpdateTime = Date()
        self.elapsedSeconds = Int(Date().timeIntervalSince(startTime))
    }

    mutating func updateProgress(_ progress: TodoProgress) {
        self.todoProgress = progress
        self.lastUpdateTime = Date()
    }
}

// MARK: - Supporting Types

/// Progress through a todo list
struct TodoProgress: Codable, Equatable {
    let completed: Int
    let total: Int
    let currentTask: String?

    var progressText: String { "\(completed) of \(total)" }
    var progressFraction: Double { Double(completed) / Double(max(total, 1)) }

    init(completed: Int, total: Int, currentTask: String? = nil) {
        self.completed = completed
        self.total = total
        self.currentTask = currentTask
    }
}

/// Approval request for background notifications
/// Separate from Models.swift ApprovalRequest to avoid coupling
struct BackgroundApprovalRequest: Codable, Equatable {
    let id: String
    let toolName: String
    let summary: String
    let details: String?
    let expiresAt: Date?

    init(id: String, toolName: String, summary: String, details: String? = nil, expiresAt: Date? = nil) {
        self.id = id
        self.toolName = toolName
        self.summary = summary
        self.details = details
        self.expiresAt = expiresAt ?? Date().addingTimeInterval(60) // 60-second default timeout
    }

    /// Create from existing ApprovalRequest in Models.swift
    init(from approval: ApprovalRequest) {
        self.id = approval.id
        self.toolName = approval.toolName
        self.summary = approval.displayDescription
        self.details = nil  // ApprovalRequest only has displayDescription
        self.expiresAt = Date().addingTimeInterval(60)
    }
}

/// User question for background notifications
struct BackgroundUserQuestion: Codable, Equatable {
    let id: String
    let question: String
    let options: [String]?

    init(id: String, question: String, options: [String]? = nil) {
        self.id = id
        self.question = question
        self.options = options
    }
}

/// Result of a completed task
enum TaskResult: Codable, Equatable {
    case success(summary: String?)
    case failure(error: String)
    case cancelled

    private enum CodingKeys: String, CodingKey {
        case type, summary, error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "success":
            let summary = try container.decodeIfPresent(String.self, forKey: .summary)
            self = .success(summary: summary)
        case "failure":
            let error = try container.decode(String.self, forKey: .error)
            self = .failure(error: error)
        case "cancelled":
            self = .cancelled
        default:
            self = .cancelled
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .success(let summary):
            try container.encode("success", forKey: .type)
            try container.encodeIfPresent(summary, forKey: .summary)
        case .failure(let error):
            try container.encode("failure", forKey: .type)
            try container.encode(error, forKey: .error)
        case .cancelled:
            try container.encode("cancelled", forKey: .type)
        }
    }
}

/// Color representation for task states (avoids SwiftUI import in model)
enum TaskStateColor: String, Codable {
    case gray, blue, orange, purple, green, red

    var hexValue: String {
        switch self {
        case .gray: return "#8E8E93"
        case .blue: return "#007AFF"
        case .orange: return "#FF9500"
        case .purple: return "#AF52DE"
        case .green: return "#34C759"
        case .red: return "#FF3B30"
        }
    }
}
