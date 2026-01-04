---
number: 63
title: Error Types
phase: phase-0-foundation
priority: High
depends_on: null
acceptance_criteria: 7
files_to_touch: 6
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 63: Error Types

**Phase:** 0 (Foundation)
**Priority:** High
**Status:** Not Started
**Depends On:** None
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Required Documentation

Before starting work on this issue, review these architecture and design documents:

### Core Architecture
- **[Error Handling & Recovery](../../docs/architecture/data/05-error-handling-recovery.md)** - CRITICAL: Error type hierarchy, UserFacingError, recovery patterns
- **[Data Flow (Messages)](../../docs/architecture/data/03-data-flow-messages.md)** - MessageValidationError patterns
- **[Backend Contracts](../../docs/architecture/data/04-backend-contracts.md)** - Error mapping from backend

### Foundation
- **[System Overview](../../docs/architecture/data/01-system-overview.md)** - Architecture context for error handling
- **[Design Decisions](../../docs/overview/design-decisions.md)** - Error handling decisions

### Workflows
- **[Execution Guardrails](../../docs/workflows/guardrails.md)** - Development rules and constraints

## Goal

Define a comprehensive, type-safe error hierarchy for CodingBridge that provides consistent error handling, user-friendly messages, structured logging, and recovery options.

## Scope

- In scope:
  - `AppError` enum covering all error domains
  - `UserFacingError` protocol for UI display
  - `ErrorRecoveryOption` for actionable recovery
  - Error mapping from system errors
  - ToolErrorClassification mapping for tool failures (permission, network, parse, unknown)
  - Logging integration
- Out of scope:
  - Crash reporting integration (Issue #47)
  - Remote error analytics (Issue #48)
  - Error rate alerting

## Non-goals

- Server-side error aggregation
- Automatic error recovery (beyond retry)
- Error prediction / prevention

## Dependencies

- None (foundational issue)

## Touch Set

- Files to create:
  - `CodingBridge/Core/Errors/AppError.swift`
  - `CodingBridge/Core/Errors/UserFacingError.swift`
  - `CodingBridge/Core/Errors/ErrorRecoveryOption.swift`
  - `CodingBridge/Core/Errors/ErrorMapping.swift`
- Files to modify:
  - `CodingBridge/Core/AppError.swift` (replace existing)
  - `CodingBridge/Views/ErrorBanner.swift` (use new types)

---

## Error Hierarchy

### AppError Enum

```swift
/// Comprehensive error type for all app operations.
///
/// `AppError` provides type-safe, domain-specific errors with
/// user-facing messages, recovery options, and logging metadata.
///
/// ## Usage
///
/// ```swift
/// func loadSession() async throws(AppError) -> Session {
///     guard isConnected else {
///         throw .networkUnavailable
///     }
///     // ...
/// }
/// ```
enum AppError: Error, Sendable, Equatable {

    // MARK: - Network

    /// No network connectivity available.
    case networkUnavailable

    /// Request timed out after specified duration.
    case timeout(seconds: Int)

    /// Server returned an error status.
    case serverError(status: Int, message: String?)

    /// SSL/TLS certificate validation failed.
    case sslError(description: String)

    /// DNS resolution failed for host.
    case dnsError(host: String)

    // MARK: - WebSocket

    /// WebSocket connection failed.
    case webSocketConnectionFailed(reason: String)

    /// WebSocket disconnected unexpectedly.
    case webSocketDisconnected(code: Int?, reason: String?)

    /// WebSocket message parsing failed.
    case webSocketMessageInvalid(detail: String)

    /// WebSocket ping timeout - connection may be dead.
    case webSocketPingTimeout

    // MARK: - API

    /// API endpoint not found (404).
    case apiNotFound(endpoint: String)

    /// API request was malformed (400).
    case apiBadRequest(message: String)

    /// API authentication failed (401).
    case apiUnauthorized

    /// API rate limit exceeded (429).
    case apiRateLimited(retryAfter: Int?)

    /// API response could not be decoded.
    case apiDecodingError(type: String, detail: String)

    /// API response missing required field.
    case apiMissingField(field: String)

    // MARK: - Agent

    /// Agent is already processing a request.
    case agentBusy

    /// Agent creation failed.
    case agentCreationFailed(reason: String)

    /// Agent was aborted by user.
    case agentAborted

    /// Agent encountered an error during execution.
    case agentExecutionError(message: String)

    /// Agent session not found.
    case agentSessionNotFound(sessionId: String)

    /// Agent model not available.
    case agentModelUnavailable(model: String)

    // MARK: - Permissions

    /// Permission was denied by user.
    case permissionDenied(tool: String)

    /// Permission request timed out.
    case permissionTimeout(tool: String, seconds: Int)

    /// Permission system unavailable.
    case permissionSystemError(detail: String)

    // MARK: - SSH

    /// SSH connection failed.
    case sshConnectionFailed(host: String, reason: String)

    /// SSH authentication failed.
    case sshAuthenticationFailed(method: String)

    /// SSH command execution failed.
    case sshCommandFailed(command: String, exitCode: Int, stderr: String?)

    /// SSH connection timed out.
    case sshTimeout(seconds: Int)

    /// SSH key is invalid or unsupported.
    case sshKeyInvalid(reason: String)

    /// SSH host key verification failed.
    case sshHostKeyMismatch(host: String)

    // MARK: - File System

    /// File not found at path.
    case fileNotFound(path: String)

    /// File could not be read.
    case fileReadError(path: String, reason: String)

    /// File could not be written.
    case fileWriteError(path: String, reason: String)

    /// Insufficient disk space.
    case insufficientDiskSpace(required: Int64, available: Int64)

    /// File permission denied.
    case filePermissionDenied(path: String)

    // MARK: - Persistence

    /// Data encoding failed.
    case encodingError(type: String, detail: String)

    /// Data decoding failed.
    case decodingError(type: String, detail: String)

    /// Database operation failed.
    case databaseError(operation: String, detail: String)

    /// Migration failed.
    case migrationError(from: Int, to: Int, reason: String)

    // MARK: - Validation

    /// Input validation failed.
    case validationError(field: String, message: String)

    /// URL is malformed.
    case invalidURL(string: String)

    /// Project path is invalid.
    case invalidProjectPath(path: String)

    // MARK: - Session

    /// Session not found.
    case sessionNotFound(id: String)

    /// Session is archived.
    case sessionArchived(id: String)

    /// Session export failed.
    case sessionExportFailed(reason: String)

    /// Session search failed.
    case sessionSearchFailed(query: String, reason: String)

    // MARK: - Project

    /// Project not found.
    case projectNotFound(path: String)

    /// Project clone failed.
    case projectCloneFailed(url: String, reason: String)

    /// Project already exists.
    case projectAlreadyExists(path: String)

    // MARK: - General

    /// Unknown error with message.
    case unknown(message: String)

    /// Internal error that shouldn't happen.
    case internalError(detail: String)

    /// Feature not available in current configuration.
    case featureUnavailable(feature: String)
}
```

---

## User-Facing Protocol

### UserFacingError

```swift
/// Protocol for errors that can be displayed to users.
protocol UserFacingError: Error {
    /// Short title for the error (1-4 words).
    var title: String { get }

    /// User-friendly description of what went wrong.
    var userMessage: String { get }

    /// Available recovery options.
    var recoveryOptions: [ErrorRecoveryOption] { get }

    /// SF Symbol name for the error.
    var icon: String { get }

    /// Severity level for UI styling.
    var severity: ErrorSeverity { get }
}

enum ErrorSeverity: Sendable {
    case info      // Blue, informational
    case warning   // Yellow, degraded but functional
    case error     // Red, action blocked
    case critical  // Red + haptic, app may be unusable
}
```

### AppError Conformance

```swift
extension AppError: UserFacingError {
    var title: String {
        switch self {
        case .networkUnavailable:
            return "No Connection"
        case .timeout:
            return "Request Timeout"
        case .serverError:
            return "Server Error"
        case .webSocketConnectionFailed, .webSocketDisconnected:
            return "Connection Lost"
        case .agentBusy:
            return "Agent Busy"
        case .sshConnectionFailed, .sshAuthenticationFailed:
            return "SSH Error"
        case .fileNotFound:
            return "File Not Found"
        case .sessionNotFound:
            return "Session Not Found"
        case .permissionDenied:
            return "Permission Denied"
        default:
            return "Error"
        }
    }

    var userMessage: String {
        switch self {
        case .networkUnavailable:
            return "Check your internet connection and try again."
        case .timeout(let seconds):
            return "The request took longer than \(seconds) seconds. Please try again."
        case .serverError(let status, let message):
            if let message {
                return "Server returned error \(status): \(message)"
            }
            return "The server encountered an error (\(status)). Please try again later."
        case .webSocketConnectionFailed(let reason):
            return "Couldn't connect to the server. \(reason)"
        case .webSocketDisconnected(_, let reason):
            return reason ?? "The connection was lost. Reconnecting..."
        case .agentBusy:
            return "The agent is still working on your previous request. Please wait for it to finish."
        case .sshConnectionFailed(let host, let reason):
            return "Couldn't connect to \(host). \(reason)"
        case .sshAuthenticationFailed(let method):
            return "Authentication failed using \(method). Check your credentials."
        case .sshCommandFailed(_, let exitCode, let stderr):
            var msg = "Command failed with exit code \(exitCode)."
            if let stderr, !stderr.isEmpty {
                msg += " \(stderr.prefix(100))"
            }
            return msg
        case .fileNotFound(let path):
            return "The file \"\(URL(fileURLWithPath: path).lastPathComponent)\" doesn't exist."
        case .sessionNotFound(let id):
            return "Session \(id.prefix(8))... was not found. It may have been deleted."
        case .permissionDenied(let tool):
            return "Permission to use \(tool) was denied."
        case .validationError(let field, let message):
            return "\(field): \(message)"
        default:
            return "An unexpected error occurred. Please try again."
        }
    }

    var recoveryOptions: [ErrorRecoveryOption] {
        switch self {
        case .networkUnavailable:
            return [.openSettings, .retry]
        case .timeout, .serverError:
            return [.retry, .cancel]
        case .webSocketConnectionFailed, .webSocketDisconnected:
            return [.reconnect, .checkSettings]
        case .agentBusy:
            return [.waitForCompletion, .abort]
        case .sshConnectionFailed, .sshAuthenticationFailed:
            return [.checkSettings, .retry]
        case .fileNotFound:
            return [.browse, .cancel]
        case .permissionDenied:
            return [.retryWithPermission, .skipTool]
        default:
            return [.dismiss]
        }
    }

    var icon: String {
        switch self {
        case .networkUnavailable:
            return "wifi.slash"
        case .timeout:
            return "clock.badge.exclamationmark"
        case .serverError:
            return "server.rack"
        case .webSocketConnectionFailed, .webSocketDisconnected:
            return "antenna.radiowaves.left.and.right.slash"
        case .agentBusy:
            return "hourglass"
        case .sshConnectionFailed, .sshAuthenticationFailed:
            return "terminal"
        case .fileNotFound, .fileReadError, .fileWriteError:
            return "doc.questionmark"
        case .permissionDenied:
            return "lock.shield"
        case .validationError:
            return "exclamationmark.triangle"
        default:
            return "exclamationmark.circle"
        }
    }

    var severity: ErrorSeverity {
        switch self {
        case .networkUnavailable, .webSocketDisconnected:
            return .warning
        case .agentBusy:
            return .info
        case .internalError:
            return .critical
        default:
            return .error
        }
    }
}
```

---

## Recovery Options

### ErrorRecoveryOption

```swift
/// Actionable recovery option for an error.
struct ErrorRecoveryOption: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let icon: String
    let style: ButtonStyle
    let action: @Sendable () async -> Void

    enum ButtonStyle: Sendable {
        case primary    // Prominent, recommended action
        case secondary  // Alternative action
        case destructive // Dangerous action (abort, delete)
    }

    // MARK: - Common Options

    static let retry = ErrorRecoveryOption(
        title: "Retry",
        icon: "arrow.clockwise",
        style: .primary
    ) { /* Caller provides action */ }

    static let cancel = ErrorRecoveryOption(
        title: "Cancel",
        icon: "xmark",
        style: .secondary
    ) { /* Dismiss */ }

    static let dismiss = ErrorRecoveryOption(
        title: "OK",
        icon: "checkmark",
        style: .primary
    ) { /* Dismiss */ }

    static let reconnect = ErrorRecoveryOption(
        title: "Reconnect",
        icon: "arrow.triangle.2.circlepath",
        style: .primary
    ) { /* Reconnect action */ }

    static let checkSettings = ErrorRecoveryOption(
        title: "Settings",
        icon: "gear",
        style: .secondary
    ) { /* Open settings */ }

    static let openSettings = ErrorRecoveryOption(
        title: "Open Settings",
        icon: "gear",
        style: .secondary
    ) { /* Open iOS Settings */ }

    static let abort = ErrorRecoveryOption(
        title: "Abort",
        icon: "xmark.octagon",
        style: .destructive
    ) { /* Abort action */ }

    static let waitForCompletion = ErrorRecoveryOption(
        title: "Wait",
        icon: "clock",
        style: .secondary
    ) { /* Just wait */ }

    static let browse = ErrorRecoveryOption(
        title: "Browse",
        icon: "folder",
        style: .secondary
    ) { /* Open file browser */ }

    static let retryWithPermission = ErrorRecoveryOption(
        title: "Grant Permission",
        icon: "checkmark.shield",
        style: .primary
    ) { /* Retry with permission */ }

    static let skipTool = ErrorRecoveryOption(
        title: "Skip",
        icon: "forward",
        style: .secondary
    ) { /* Skip tool use */ }
}
```

---

## Error Mapping

### From URLError

```swift
extension AppError {
    /// Map URLError to AppError.
    init(urlError: URLError) {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            self = .networkUnavailable
        case .timedOut:
            self = .timeout(seconds: 60)
        case .cannotFindHost, .dnsLookupFailed:
            self = .dnsError(host: urlError.failingURL?.host ?? "unknown")
        case .secureConnectionFailed, .serverCertificateUntrusted:
            self = .sslError(description: urlError.localizedDescription)
        case .badServerResponse:
            self = .serverError(status: 0, message: urlError.localizedDescription)
        default:
            self = .unknown(message: urlError.localizedDescription)
        }
    }
}
```

### From HTTP Status Codes

```swift
extension AppError {
    /// Map HTTP status code to AppError.
    init(httpStatus: Int, message: String? = nil, endpoint: String? = nil) {
        switch httpStatus {
        case 400:
            self = .apiBadRequest(message: message ?? "Bad request")
        case 401:
            self = .apiUnauthorized
        case 404:
            self = .apiNotFound(endpoint: endpoint ?? "unknown")
        case 429:
            self = .apiRateLimited(retryAfter: nil)
        case 500...599:
            self = .serverError(status: httpStatus, message: message)
        default:
            self = .serverError(status: httpStatus, message: message)
        }
    }
}
```

### From SSH Errors

```swift
extension AppError {
    /// Map SSH library error to AppError.
    init(sshError: Error, host: String) {
        let message = sshError.localizedDescription

        if message.contains("Authentication") || message.contains("auth") {
            self = .sshAuthenticationFailed(method: "password")
        } else if message.contains("timeout") || message.contains("Timeout") {
            self = .sshTimeout(seconds: 30)
        } else if message.contains("host key") {
            self = .sshHostKeyMismatch(host: host)
        } else {
            self = .sshConnectionFailed(host: host, reason: message)
        }
    }
}
```

---

## Logging Integration

### Error Logging

```swift
extension AppError {
    /// Log level for this error.
    var logLevel: Logger.Level {
        switch severity {
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        case .critical: return .fault
        }
    }

    /// Structured log metadata.
    var logMetadata: [String: String] {
        var metadata: [String: String] = [
            "error_type": String(describing: self).components(separatedBy: "(").first ?? "unknown",
            "severity": String(describing: severity),
        ]

        switch self {
        case .serverError(let status, _):
            metadata["http_status"] = String(status)
        case .sshConnectionFailed(let host, _):
            metadata["ssh_host"] = host
        case .sshCommandFailed(let command, let exitCode, _):
            metadata["ssh_command"] = command.prefix(50).description
            metadata["exit_code"] = String(exitCode)
        case .fileNotFound(let path), .fileReadError(let path, _), .fileWriteError(let path, _):
            metadata["file_path"] = path
        case .sessionNotFound(let id):
            metadata["session_id"] = id
        default:
            break
        }

        return metadata
    }

    /// Log the error with appropriate level.
    func log(file: String = #file, function: String = #function, line: Int = #line) {
        let logger = Logger(subsystem: "com.codingbridge", category: "error")

        let message = "\(title): \(userMessage)"

        switch logLevel {
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        case .fault:
            logger.fault("\(message, privacy: .public)")
        default:
            logger.debug("\(message, privacy: .public)")
        }
    }
}
```

---

## Usage in Views

### ErrorBanner Integration

```swift
struct ErrorBanner: View {
    let error: AppError
    let onRecovery: (ErrorRecoveryOption) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: error.icon)
                    .foregroundStyle(color)

                Text(error.title)
                    .font(.headline)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                }
            }

            Text(error.userMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !error.recoveryOptions.isEmpty {
                HStack {
                    ForEach(error.recoveryOptions) { option in
                        Button(action: { onRecovery(option) }) {
                            Label(option.title, systemImage: option.icon)
                        }
                        .buttonStyle(recoveryButtonStyle(for: option))
                    }
                }
            }
        }
        .padding()
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var color: Color {
        switch error.severity {
        case .info: return .blue
        case .warning: return .yellow
        case .error, .critical: return .red
        }
    }

    private var backgroundColor: Color {
        color.opacity(0.1)
    }
}
```

---

## Edge Cases

- **Nested errors**: Use `AppError.internalError` with description
- **Multiple simultaneous errors**: Show most severe, queue others
- **Recovery action fails**: Re-show error with updated message
- **Unknown error types**: Map to `AppError.unknown`

## Acceptance Criteria

- [ ] AppError covers all domains (network, SSH, API, agent, file, session)
- [ ] UserFacingError protocol with title, message, icon, severity
- [ ] ErrorRecoveryOption with common recovery actions
- [ ] Error mapping from URLError, HTTP status, SSH errors
- [ ] Logging integration with structured metadata
- [ ] ErrorBanner uses new error types
- [ ] All errors are Sendable

## Testing

```swift
class AppErrorTests: XCTestCase {
    func testNetworkErrorMapping() {
        let urlError = URLError(.notConnectedToInternet)
        let appError = AppError(urlError: urlError)

        XCTAssertEqual(appError, .networkUnavailable)
        XCTAssertEqual(appError.title, "No Connection")
        XCTAssertEqual(appError.severity, .warning)
    }

    func testHTTPErrorMapping() {
        let error = AppError(httpStatus: 429)

        XCTAssertEqual(error.title, "Error")
        XCTAssertTrue(error.userMessage.contains("rate"))
    }

    func testRecoveryOptions() {
        let error = AppError.networkUnavailable

        XCTAssertTrue(error.recoveryOptions.contains { $0.title == "Retry" })
    }
}
```
