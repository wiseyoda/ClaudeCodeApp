import Foundation
import UserNotifications

// MARK: - Debug Log Helper

/// Helper to access debug log store on MainActor
/// Note: This is only used within @MainActor context in WebSocketManager
@MainActor private var debugLog: DebugLogStore { DebugLogStore.shared }

// MARK: - Connection State

/// Represents the current state of the WebSocket connection
enum ConnectionState: Equatable {
    case disconnected       // Not connected, not attempting to connect
    case connecting         // Initial connection attempt
    case connected          // WebSocket is connected and healthy
    case reconnecting(attempt: Int)  // Lost connection, attempting to reconnect

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isConnecting: Bool {
        switch self {
        case .connecting, .reconnecting: return true
        default: return false
        }
    }

    var displayText: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .reconnecting(let attempt): return "Reconnecting (\(attempt))..."
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .disconnected: return "Server disconnected"
        case .connecting: return "Connecting to server"
        case .connected: return "Connected to server"
        case .reconnecting(let attempt): return "Reconnecting to server, attempt \(attempt)"
        }
    }
}

@MainActor
class WebSocketManager: ObservableObject {
    private var webSocket: URLSessionWebSocketTask?
    private var settings: AppSettings

    /// When true, parse messages synchronously (for tests). When false (default), parse async on background queue.
    private let parseSynchronously: Bool

    /// Background queue for JSON parsing to avoid blocking main thread during streaming
    private static let parsingQueue = DispatchQueue(label: "com.codingbridge.websocket.parsing", qos: .userInitiated)

    /// Unique ID for the current connection - used to detect stale receive callbacks
    private var connectionId: UUID = UUID()

    /// Current connection state - use this instead of isConnected
    @Published var connectionState: ConnectionState = .disconnected

    /// Legacy property for backward compatibility
    var isConnected: Bool {
        get { connectionState.isConnected }
        set {
            if newValue && !connectionState.isConnected {
                connectionState = .connected
            } else if !newValue && connectionState.isConnected {
                connectionState = .disconnected
            }
        }
    }

    @Published var isProcessing = false
    @Published var isAborting = false  // True while waiting for abort confirmation
    @Published var currentText = ""
    @Published var lastError: String?

    /// Buffer for accumulating streaming text before publishing (reduces view updates)
    private var textBuffer = ""
    /// Debounce task for flushing text buffer
    private var textFlushTask: Task<Void, Never>?
    /// Debounce delay for text updates (50ms balances responsiveness with performance)
    private let textFlushDelay: UInt64 = 50_000_000  // nanoseconds
    @Published var sessionId: String?
    @Published var tokenUsage: TokenUsage?
    @Published var currentModel: ClaudeModel?
    @Published var currentModelId: String?  // The full model ID (e.g., "claude-sonnet-4-5-20250929")
    @Published var isSwitchingModel = false

    /// Track whether app is in foreground - reads from BackgroundManager for consistency
    var isAppInForeground: Bool {
        !BackgroundManager.shared.isAppInBackground
    }

    // Reconnection state
    private var isReconnecting = false
    private var reconnectAttempt = 0
    private var reconnectTask: Task<Void, Never>?
    private let maxReconnectAttempt = 4  // 1s, 2s, 4s, 8s max

    // Processing timeout - configurable via settings.processingTimeout (default 5 mins)
    private var processingTimeoutTask: Task<Void, Never>?
    private var lastResponseTime: Date?
    private var lastActiveToolName: String?  // Track last tool for timeout diagnostics

    struct TokenUsage {
        let used: Int
        let total: Int
    }

    // Message retry queue
    struct PendingMessage: Identifiable {
        let id = UUID()
        let message: String
        let projectPath: String
        let sessionId: String?
        let permissionMode: String?
        let imageData: Data?
        let model: String?
        var attempts: Int = 0
        let createdAt = Date()
    }

    private var messageQueue: [PendingMessage] = []
    private let maxRetries = 3
    private let retryDelays: [TimeInterval] = [1, 2, 4]  // Exponential backoff
    private var retryTask: Task<Void, Never>?

    // Callbacks for streaming events
    var onText: ((String) -> Void)?
    var onTextCommit: ((String) -> Void)?  // Called when text segment is complete (before tool use)
    var onToolUse: ((String, String) -> Void)?
    var onToolResult: ((String) -> Void)?
    var onThinking: ((String) -> Void)?  // For reasoning/thinking blocks
    var onComplete: ((String?) -> Void)?  // sessionId
    var onAskUserQuestion: ((AskUserQuestionData) -> Void)?  // For interactive questions
    var onError: ((String) -> Void)?
    var onSessionCreated: ((String) -> Void)?
    var onModelChanged: ((ClaudeModel, String) -> Void)?  // (model enum, full model ID)
    var onAborted: (() -> Void)?  // Called when session is aborted
    var onSessionRecovered: (() -> Void)?  // Called when invalid session was cleared and new session started
    var onSessionAttached: (() -> Void)?  // Called when successfully attached to an active session
    var onApprovalRequest: ((ApprovalRequest) -> Void)?  // For permission approval requests

    /// Current pending approval request (only one at a time)
    @Published var pendingApproval: ApprovalRequest?

    /// Track if we're attempting to reattach to an active session
    @Published var isReattaching = false

    /// Initialize with optional settings. Call updateSettings() in onAppear with the EnvironmentObject.
    /// - Parameters:
    ///   - settings: Optional AppSettings. If nil, a temporary placeholder is created.
    ///   - parseSynchronously: If true, parse messages synchronously (for unit tests). Defaults to false.
    init(settings: AppSettings? = nil, parseSynchronously: Bool = false) {
        // Use provided settings or create temporary placeholder
        // The real settings should be provided via updateSettings() in onAppear
        self.settings = settings ?? AppSettings()
        self.parseSynchronously = parseSynchronously
    }

    /// Update settings reference (call from onAppear with actual EnvironmentObject)
    func updateSettings(_ newSettings: AppSettings) {
        self.settings = newSettings
    }

    // MARK: - Token Usage Polling

    /// Refresh token usage from API for the current session
    /// Call this when loading a session or periodically during active sessions
    func refreshTokenUsage(projectPath: String, sessionId: String) async {
        let projectName = projectPath.replacingOccurrences(of: "/", with: "-")
        let apiClient = APIClient(settings: settings)

        do {
            let usage = try await apiClient.fetchSessionTokenUsage(
                projectName: projectName,
                sessionId: sessionId
            )
            tokenUsage = TokenUsage(used: usage.used, total: usage.total)
        } catch {
            log.warning("Failed to refresh token usage: \(error.localizedDescription)")
        }
    }

    // MARK: - Session ID Validation

    /// Validates that a session ID is a properly formatted UUID
    /// Returns nil if invalid, the validated ID if valid
    nonisolated static func validateSessionId(_ sessionId: String?) -> String? {
        guard let id = sessionId, !id.isEmpty else { return nil }

        // Session IDs should be valid UUIDs (8-4-4-4-12 format)
        // e.g., "cbd6acb5-a212-4899-90c4-ab11937e21c0"
        let uuidRegex = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/
        guard id.wholeMatch(of: uuidRegex) != nil else {
            // Invalid session ID - caller should log if needed
            return nil
        }

        return id
    }

    /// Check if an error message indicates a session-related failure
    private func isSessionError(_ errorMessage: String) -> Bool {
        let sessionErrorPatterns = [
            "session",
            "Session not found",
            "Invalid session",
            "process exited with code 1",  // Often indicates session resume failure
            "failed to resume",
            "resume failed"
        ]
        let lowerError = errorMessage.lowercased()
        return sessionErrorPatterns.contains { lowerError.contains($0.lowercased()) }
    }

    /// Start or reset the processing timeout
    private func startProcessingTimeout() {
        processingTimeoutTask?.cancel()
        lastResponseTime = Date()

        processingTimeoutTask = Task { [weak self] in
            while !Task.isCancelled {
                // Check every 5 seconds for more responsive timeout detection
                try? await Task.sleep(nanoseconds: 5_000_000_000)

                guard !Task.isCancelled else { break }

                let shouldContinue = await MainActor.run { () -> Bool in
                    guard let self = self else { return false }

                    // If not processing anymore, stop monitoring
                    guard self.isProcessing else { return false }

                    // Check if we haven't received any response for 30+ seconds
                    guard let lastResponse = self.lastResponseTime else {
                        // No response time set - this shouldn't happen, but trigger timeout
                        log.warning("Processing timeout - lastResponseTime was nil")
                        self.isProcessing = false
                        self.lastActiveToolName = nil
                        self.lastError = "Request timed out - no response from server"
                        self.onError?("Request timed out")
                        ErrorStore.shared.post(.connectionFailed("Request timed out - no response from server"))
                        return false
                    }

                    let elapsed = Date().timeIntervalSince(lastResponse)
                    let timeoutSeconds = Double(self.settings.processingTimeout)
                    if elapsed >= timeoutSeconds {
                        let toolInfo = self.lastActiveToolName ?? "unknown"
                        let elapsedFormatted = elapsed >= 60 ? "\(Int(elapsed / 60))m \(Int(elapsed) % 60)s" : "\(Int(elapsed))s"
                        let errorMsg = "Processing timeout - no response for \(elapsedFormatted) (last tool: \(toolInfo))"
                        log.warning(errorMsg)
                        debugLog.logError(errorMsg, details: "Last response: \(lastResponse), Session: \(self.sessionId ?? "none"), Tool: \(toolInfo), Timeout: \(Int(timeoutSeconds))s")
                        self.isProcessing = false
                        self.lastActiveToolName = nil
                        self.lastError = "Request timed out after \(elapsedFormatted) - no response from server. Long operations may need increased timeout in Settings."
                        self.onError?("Request timed out")
                        ErrorStore.shared.post(.connectionFailed("Request timed out after \(elapsedFormatted)"))
                        return false
                    }

                    // Still processing with recent activity, continue monitoring
                    return true
                }

                if !shouldContinue { break }
            }
        }
    }

    /// Called when any response is received to reset the timeout
    private func resetProcessingTimeout() {
        lastResponseTime = Date()
    }

    /// Cancel the processing timeout
    private func cancelProcessingTimeout() {
        processingTimeoutTask?.cancel()
        processingTimeoutTask = nil
    }

    /// Send a local notification (only when app is backgrounded)
    func sendLocalNotification(title: String, body: String) {
        guard !isAppInForeground else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                log.error("Notification error: \(error)")
            }
        }
    }

    func connect() {
        guard let url = settings.webSocketURL else {
            lastError = "Invalid WebSocket URL"
            connectionState = .disconnected
            debugLog.logError("Invalid WebSocket URL")
            ErrorStore.shared.post(.serverUnreachable(settings.serverURL))
            return
        }

        // Cancel any pending reconnection
        reconnectTask?.cancel()
        reconnectTask = nil
        isReconnecting = false

        // Generate new connection ID to invalidate any stale receive callbacks
        connectionId = UUID()
        let currentConnectionId = connectionId

        // Clean up existing connection if any
        webSocket?.cancel(with: .goingAway, reason: nil)

        // Set connecting state (preserve reconnect attempt for UI if reconnecting)
        if case .reconnecting(let attempt) = connectionState {
            log.info("Reconnecting to: \(url) (attempt \(attempt))")
            debugLog.logConnection("Reconnecting to \(url) (attempt \(attempt))")
        } else {
            connectionState = .connecting
            log.info("Connecting to: \(url)")
            debugLog.logConnection("Connecting to \(url)")
        }

        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()

        lastError = nil

        // Send a ping to quickly confirm connection is alive
        webSocket?.sendPing { [weak self] error in
            Task { @MainActor in
                guard let self = self else { return }
                guard self.connectionId == currentConnectionId else { return }
                if error == nil && self.connectionState != .connected {
                    self.connectionState = .connected
                    self.reconnectAttempt = 0
                    debugLog.logConnection("Connected (confirmed by ping)")
                    self.completePendingRecovery()
                }
            }
        }

        // Note: reconnectAttempt is also reset in receiveMessage success as backup

        receiveMessage(forConnection: currentConnectionId)
    }

    /// Attempt to reattach to an active session that was processing when the app closed.
    /// This sends a lightweight "/status" command to the session which will trigger
    /// any pending output to be streamed back.
    func attachToSession(sessionId: String, projectPath: String) {
        guard connectionState == .connected || connectionState == .connecting else {
            log.warning("Cannot attach to session - not connected")
            return
        }

        guard let validatedId = Self.validateSessionId(sessionId) else {
            log.warning("Cannot attach to session - invalid session ID format")
            return
        }

        log.info("Attempting to reattach to session: \(validatedId.prefix(8))...")
        isReattaching = true
        isProcessing = true
        self.sessionId = validatedId
        startProcessingTimeout()

        // Send a /status command which is a no-op but will trigger the backend
        // to send any pending output for this session
        let command = WSClaudeCommand(
            command: "/status",
            options: WSCommandOptions(
                cwd: projectPath,
                sessionId: validatedId,
                model: nil,
                permissionMode: nil,
                images: nil
            )
        )

        do {
            let data = try JSONEncoder().encode(command)
            if let jsonString = String(data: data, encoding: .utf8) {
                debugLog.logSent(jsonString)
                webSocket?.send(.string(jsonString)) { [weak self] error in
                    Task { @MainActor in
                        if let error = error {
                            log.error("Attach request failed: \(error)")
                            self?.isReattaching = false
                            self?.isProcessing = false
                            self?.cancelProcessingTimeout()
                        }
                    }
                }
            }
        } catch {
            log.error("Failed to encode attach request: \(error)")
            isReattaching = false
            isProcessing = false
            cancelProcessingTimeout()
        }
    }

    /// Recover from background processing by reconnecting and reattaching to the session.
    /// Called when app returns to foreground after being backgrounded during processing.
    func recoverFromBackground(sessionId: String, projectPath: String) {
        log.info("Recovering from background - session: \(sessionId.prefix(8))...")

        // If already connected, just reattach
        if connectionState == .connected {
            attachToSession(sessionId: sessionId, projectPath: projectPath)
            return
        }

        // If not connected, need to connect first then attach
        // Store recovery info to use after connection
        pendingRecoverySessionId = sessionId
        pendingRecoveryProjectPath = projectPath

        // Connect (or reconnect)
        connect()
    }

    // Storage for pending recovery after reconnection
    private var pendingRecoverySessionId: String?
    private var pendingRecoveryProjectPath: String?

    /// Called after successful connection to complete recovery if needed
    private func completePendingRecovery() {
        guard let sessionId = pendingRecoverySessionId,
              let projectPath = pendingRecoveryProjectPath else {
            return
        }

        log.info("Completing pending recovery for session: \(sessionId.prefix(8))...")
        pendingRecoverySessionId = nil
        pendingRecoveryProjectPath = nil

        // Small delay to ensure connection is stable
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)  // 200ms
            await MainActor.run {
                self.attachToSession(sessionId: sessionId, projectPath: projectPath)
            }
        }
    }

    func disconnect() {
        // Cancel any pending reconnection
        reconnectTask?.cancel()
        reconnectTask = nil
        isReconnecting = false
        pendingRecoverySessionId = nil
        pendingRecoveryProjectPath = nil
        reconnectAttempt = 0
        cancelProcessingTimeout()

        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        connectionState = .disconnected
        isProcessing = false
        debugLog.logConnection("Disconnected")
    }

    /// Schedule a reconnection with exponential backoff
    private func scheduleReconnect() {
        guard !isReconnecting else { return }

        isReconnecting = true
        reconnectAttempt += 1

        // Update connection state to show reconnecting with attempt number
        connectionState = .reconnecting(attempt: reconnectAttempt)

        // Calculate delay with exponential backoff: 1s, 2s, 4s, 8s max
        let baseDelay: Double = 1.0
        let delay = baseDelay * pow(2.0, Double(min(reconnectAttempt - 1, maxReconnectAttempt - 1)))
        // Add jitter (0-500ms) to prevent thundering herd
        let jitter = Double.random(in: 0...0.5)
        let totalDelay = delay + jitter

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(totalDelay * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self = self else { return }
                self.isReconnecting = false
                if !self.connectionState.isConnected {
                    self.connect()
                }
            }
        }
    }

    func sendMessage(_ message: String, projectPath: String, resumeSessionId: String? = nil, permissionMode: String? = nil, imageData: Data? = nil, model: String? = nil) {
        // Add to message queue for potential retry
        let pending = PendingMessage(
            message: message,
            projectPath: projectPath,
            sessionId: resumeSessionId ?? sessionId,
            permissionMode: permissionMode,
            imageData: imageData,
            model: model
        )
        messageQueue.append(pending)

        // Process queue if this is the only message (not already processing)
        if messageQueue.count == 1 {
            sendNextMessage()
        }
    }

    private func sendNextMessage() {
        guard let pending = messageQueue.first else { return }

        // Allow sending when connected or connecting (WebSocket will queue if needed)
        let canSend = connectionState == .connected || connectionState == .connecting
        guard canSend else {
            connect()
            // Queue message after connection starts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                let canSendNow = self.connectionState == .connected || self.connectionState == .connecting
                if canSendNow {
                    self.sendNextMessage()
                } else {
                    self.handleSendFailure(AppError.connectionFailed("Not connected"))
                }
            }
            return
        }

        currentText = ""
        clearTextBuffer()  // Clear any leftover text from previous stream
        isProcessing = true
        lastError = nil
        startProcessingTimeout()

        // Convert image data to base64 WSImage if present
        var images: [WSImage]? = nil
        if let imageData = pending.imageData {
            let base64String = imageData.base64EncodedString()
            let mediaType = ImageUtilities.detectMediaType(from: imageData)
            images = [WSImage(mediaType: mediaType, base64Data: base64String)]
        }

        // Validate session ID format before sending
        let validatedSessionId = Self.validateSessionId(pending.sessionId)

        let command = WSClaudeCommand(
            command: pending.message,
            options: WSCommandOptions(
                cwd: pending.projectPath,
                sessionId: validatedSessionId,  // Use validated session ID
                model: pending.model,
                permissionMode: pending.permissionMode,
                images: images  // Images go inside options
            )
        )

        do {
            let data = try JSONEncoder().encode(command)
            if let jsonString = String(data: data, encoding: .utf8) {
                debugLog.logSent(jsonString)
                webSocket?.send(.string(jsonString)) { [weak self] error in
                    if let error = error {
                        Task { @MainActor in
                            debugLog.logError("Send failed: \(error.localizedDescription)")
                            self?.handleSendFailure(AppError.messageFailed(error.localizedDescription))
                        }
                    } else {
                        // Success - remove from queue and process next
                        Task { @MainActor in
                            guard let self = self else { return }
                            if !self.messageQueue.isEmpty {
                                self.messageQueue.removeFirst()
                            }
                            self.retryTask?.cancel()
                            // Note: Don't automatically send next - wait for response completion
                        }
                    }
                }
            }
        } catch {
            debugLog.logError("Encode failed: \(error.localizedDescription)")
            handleSendFailure(AppError.messageFailed(error.localizedDescription))
        }
    }

    /// Handle send failure with retry logic
    private func handleSendFailure(_ error: AppError) {
        guard !messageQueue.isEmpty else {
            lastError = error.localizedDescription
            isProcessing = false
            onError?(error.localizedDescription)
            return
        }

        messageQueue[0].attempts += 1
        let pending = messageQueue[0]

        if pending.attempts >= maxRetries {
            // Give up after max retries - remove from queue
            let errorMsg = "Message failed after \(maxRetries) attempts: \(error.localizedDescription)"
            log.error(errorMsg)
            debugLog.logError(errorMsg, details: "Message: \(pending.message.prefix(200))")
            lastError = "Message failed after \(maxRetries) attempts"
            isProcessing = false
            messageQueue.removeFirst()
            onError?("Message failed after \(maxRetries) attempts. Please try again.")
            // Try next message in queue if any
            sendNextMessage()
            return
        }

        // Schedule retry with exponential backoff
        let delayIndex = min(pending.attempts - 1, retryDelays.count - 1)
        let delay = retryDelays[delayIndex]

        // Update error message to show retry is happening
        lastError = "Retrying... (attempt \(pending.attempts + 1)/\(maxRetries))"

        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self = self else { return }
                // Reconnect if needed
                if !self.isConnected {
                    self.connect()
                }
                // Retry after brief delay for connection
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.sendNextMessage()
                }
            }
        }
    }

    /// Cancel any pending retry and clear the queue
    func cancelPendingRetry() {
        retryTask?.cancel()
        messageQueue.removeAll()
    }

    // Abort timeout task
    private var abortTimeoutTask: Task<Void, Never>?

    /// Abort the current session/task
    /// This sends an abort message to the server and resets local state
    func abortSession() {
        guard !isAborting else { return }

        guard let sid = sessionId, let validatedSid = Self.validateSessionId(sid) else {
            // Even without valid session ID, reset local state
            resetProcessingState()
            onAborted?()
            return
        }

        log.info("Aborting session: \(validatedSid)")
        isAborting = true

        let abort = WSAbortSession(sessionId: validatedSid)

        do {
            let data = try JSONEncoder().encode(abort)
            if let jsonString = String(data: data, encoding: .utf8) {
                webSocket?.send(.string(jsonString)) { [weak self] error in
                    if let error = error {
                        log.error("Failed to send abort: \(error)")
                        // Reset state on send failure
                        Task { @MainActor in
                            self?.resetProcessingState()
                            self?.onAborted?()
                        }
                    }
                    // Don't reset here - wait for session-aborted response or timeout
                }
            }
        } catch {
            log.error("Failed to encode abort: \(error)")
            resetProcessingState()
            onAborted?()
            return
        }

        // Set a timeout in case server doesn't respond
        abortTimeoutTask?.cancel()
        abortTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self = self, self.isAborting else { return }
                log.warning("Abort timeout - forcing state reset")
                self.resetProcessingState()
                self.onAborted?()
            }
        }
    }

    // MARK: - Permission Approval

    /// Send a response to a pending permission request
    /// - Parameters:
    ///   - requestId: The request ID from the permission request
    ///   - allow: Whether to allow the tool use
    ///   - alwaysAllow: Whether to remember this decision for the session
    func sendApprovalResponse(requestId: String, allow: Bool, alwaysAllow: Bool = false) {
        let response = ApprovalResponse(
            requestId: requestId,
            allow: allow,
            alwaysAllow: alwaysAllow
        )

        do {
            let data = try JSONEncoder().encode(response)
            if let jsonString = String(data: data, encoding: .utf8) {
                debugLog.logSent(jsonString)

                webSocket?.send(.string(jsonString)) { [weak self] error in
                    Task { @MainActor in
                        if let error = error {
                            log.error("Failed to send permission response: \(error)")
                            self?.lastError = "Failed to send permission response"
                        }
                        // Clear pending approval regardless of send result
                        self?.pendingApproval = nil
                    }
                }
            }
        } catch {
            log.error("Failed to encode permission response: \(error)")
            pendingApproval = nil
        }
    }

    /// Convenience method to approve the current pending request
    func approvePendingRequest(alwaysAllow: Bool = false) {
        guard let request = pendingApproval else {
            log.warning("No pending approval request to approve")
            return
        }
        sendApprovalResponse(requestId: request.id, allow: true, alwaysAllow: alwaysAllow)
    }

    /// Convenience method to deny the current pending request
    func denyPendingRequest() {
        guard let request = pendingApproval else {
            log.warning("No pending approval request to deny")
            return
        }
        sendApprovalResponse(requestId: request.id, allow: false, alwaysAllow: false)
    }

    /// Reset all processing-related state
    private func resetProcessingState() {
        isProcessing = false
        isAborting = false
        currentText = ""
        clearTextBuffer()  // Clear debounce buffer
        isSwitchingModel = false
        lastActiveToolName = nil
        cancelProcessingTimeout()
        cancelPendingRetry()
        pendingApproval = nil  // Clear any pending approval
        abortTimeoutTask?.cancel()
        abortTimeoutTask = nil
        lastError = nil
    }

    // Model switch timeout task
    private var modelSwitchTimeoutTask: Task<Void, Never>?

    /// Switch to a different Claude model
    /// - Parameters:
    ///   - model: The ClaudeModel preset to switch to
    ///   - customId: For custom models, the full model ID (e.g., "claude-opus-4-5-20251101")
    ///   - projectPath: The current project path for the session
    func switchModel(_ model: ClaudeModel, customId: String? = nil, projectPath: String) {
        let modelArg: String
        if model == .custom, let customId = customId, !customId.isEmpty {
            modelArg = customId
        } else if let alias = model.modelAlias {
            modelArg = alias
        } else {
            log.error("Cannot switch model: no alias or custom ID provided")
            return
        }

        isSwitchingModel = true

        // Set timeout to reset switching state after 5 seconds
        modelSwitchTimeoutTask?.cancel()
        modelSwitchTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if self?.isSwitchingModel == true {
                    log.warning("Model switch timed out")
                    self?.isSwitchingModel = false
                }
            }
        }

        // Send /model command as a regular message
        let command = "/model \(modelArg)"
        log.info("Switching model: \(command)")

        // Validate session ID if present
        let validatedSessionId = Self.validateSessionId(sessionId)

        // Send via WebSocket directly (not through sendMessage which adds to pending)
        let wsCommand = WSClaudeCommand(
            command: command,
            options: WSCommandOptions(
                cwd: projectPath,
                sessionId: validatedSessionId,
                model: nil,
                permissionMode: nil,
                images: nil
            )
        )

        do {
            let data = try JSONEncoder().encode(wsCommand)
            if let jsonString = String(data: data, encoding: .utf8) {
                debugLog.logSent(jsonString)
                webSocket?.send(.string(jsonString)) { [weak self] error in
                    Task { @MainActor in
                        if let error = error {
                            log.error("Model switch send failed: \(error)")
                            self?.isSwitchingModel = false
                            self?.modelSwitchTimeoutTask?.cancel()
                            self?.lastError = "Failed to switch model"
                        }
                    }
                }
            }
        } catch {
            log.error("Failed to encode model switch: \(error)")
            isSwitchingModel = false
            modelSwitchTimeoutTask?.cancel()
        }
    }

    /// Parse model from a model ID string (e.g., "claude-sonnet-4-5-20250929" -> .sonnet)
    private func parseModelFromId(_ modelId: String) -> ClaudeModel {
        let lowerId = modelId.lowercased()
        if lowerId.contains("opus") {
            return .opus
        } else if lowerId.contains("sonnet") {
            return .sonnet
        } else if lowerId.contains("haiku") {
            return .haiku
        } else {
            return .custom
        }
    }

    /// Parse model switch confirmation from response text
    /// Expected format: "Set model to sonnet (claude-sonnet-4-5-20250929)"
    private func parseModelSwitchResponse(_ text: String) {
        modelSwitchTimeoutTask?.cancel()  // Cancel timeout since we got a response

        // Extract model ID from parentheses: "(claude-sonnet-4-5-20250929)"
        if let openParen = text.firstIndex(of: "("),
           let closeParen = text.firstIndex(of: ")"),
           openParen < closeParen {
            let start = text.index(after: openParen)
            let modelId = String(text[start..<closeParen])

            let model = parseModelFromId(modelId)

            currentModel = model
            currentModelId = modelId
            isSwitchingModel = false
            onModelChanged?(model, modelId)
        } else {
            // Couldn't parse, but still mark as done
            log.warning("Could not parse model ID from: \(text)")
            isSwitchingModel = false
        }
    }

    private func receiveMessage(forConnection expectedConnectionId: UUID) {
        guard webSocket != nil, connectionState != .disconnected else { return }
        guard connectionId == expectedConnectionId else { return }

        webSocket?.receive { [weak self] result in
            // Check for completion message BEFORE MainActor dispatch
            // This ensures notifications are scheduled even if MainActor is suspended
            if case .success(let message) = result {
                self?.checkForCompletionAndNotify(message)
            }

            Task { @MainActor in
                guard let self = self, self.webSocket != nil else { return }
                guard self.connectionId == expectedConnectionId else { return }

                switch result {
                case .success(let message):
                    if self.connectionState != .connected {
                        self.connectionState = .connected
                        self.reconnectAttempt = 0
                        debugLog.logConnection("Connected (confirmed)")
                        self.completePendingRecovery()
                    }
                    self.handleMessage(message)
                    self.receiveMessage(forConnection: expectedConnectionId)

                case .failure(let error):
                    guard self.connectionState != .disconnected else { return }
                    guard self.connectionId == expectedConnectionId else { return }

                    log.error("Receive error: \(error)")
                    debugLog.logError("Receive error: \(error.localizedDescription)")
                    self.isConnected = false
                    self.isProcessing = false  // Reset processing state on disconnect
                    self.cancelProcessingTimeout()
                    self.lastError = error.localizedDescription

                    // Clear stale state on disconnect
                    self.currentText = ""
                    self.clearTextBuffer()

                    // Schedule reconnection with exponential backoff
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseMessage(text)
            }
        @unknown default:
            break
        }
    }

    /// Check for completion message and schedule notification immediately (from callback thread).
    /// This runs BEFORE MainActor dispatch to ensure notification is scheduled even when backgrounded.
    /// UNUserNotificationCenter.add() is thread-safe and can be called from any thread.
    /// NOTE: Cannot access @MainActor properties here - use generic message only.
    nonisolated private func checkForCompletionAndNotify(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8) else { return }

        // Quick check before full parse
        guard text.contains("claude-complete") else { return }

        do {
            let msg = try JSONDecoder().decode(WSMessage.self, from: data)
            guard msg.type == "claude-complete" else { return }

            log.info("[WebSocket] Completion received on callback thread, scheduling notification")

            // Schedule notification directly without MainActor
            // NOTE: Cannot access currentText or sessionId here (MainActor isolated)
            // Use generic message - detailed notification sent via MainActor path
            let content = UNMutableNotificationContent()
            content.title = "Task Complete"
            content.body = "Claude has finished processing."
            content.sound = .default
            content.categoryIdentifier = "completion"
            content.userInfo = ["type": "completion"]

            // Use a minimal time trigger - nil trigger may not work properly when backgrounded
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "completion-bg-\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    log.error("[Notification] Background schedule failed: \(error)")
                } else {
                    log.info("[Notification] Background notification scheduled")
                }
            }
        } catch {
            // Ignore parse errors - full parsing happens in handleMessage
        }
    }

    func processIncomingMessage(_ text: String) {
        parseMessage(text)
    }

    private func parseMessage(_ text: String) {
        debugLog.logReceived(text)

        // Reset timeout on any received message
        resetProcessingTimeout()

        guard let data = text.data(using: .utf8) else { return }

        if parseSynchronously {
            // Synchronous parsing for unit tests
            do {
                let msg = try JSONDecoder().decode(WSMessage.self, from: data)
                processDecodedMessage(msg, rawText: text)
            } catch {
                log.error("Parse error: \(error), text: \(text.prefix(200))")
                DebugLogStore.shared.logError("Parse error: \(error.localizedDescription)", details: text)
                lastError = "Message parse error: \(error.localizedDescription)"
            }
        } else {
            // Decode JSON on background thread to avoid blocking main thread during rapid streaming
            Task.detached(priority: .userInitiated) { [weak self] in
                do {
                    let msg = try JSONDecoder().decode(WSMessage.self, from: data)
                    await self?.processDecodedMessage(msg, rawText: text)
                } catch {
                    await MainActor.run { [weak self] in
                        log.error("Parse error: \(error), text: \(text.prefix(200))")
                        DebugLogStore.shared.logError("Parse error: \(error.localizedDescription)", details: text)
                        self?.lastError = "Message parse error: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    /// Process a decoded WebSocket message on the main actor
    private func processDecodedMessage(_ msg: WSMessage, rawText: String) {
        switch msg.type {
            case "session-created":
                if let sid = msg.sessionId {
                    sessionId = sid
                    onSessionCreated?(sid)
                }

            case "claude-response":
                if isReattaching {
                    isReattaching = false
                    onSessionAttached?()
                }

                if let responseData = msg.data?.dictValue {
                    let outerType = responseData["type"] as? String
                    if outerType == "assistant", let messageData = responseData["message"] as? [String: Any] {
                        processContent(messageData)
                    } else {
                        handleClaudeResponse(responseData)
                    }
                }

            case "token-budget":
                if let budgetData = msg.data?.dictValue,
                   let used = budgetData["used"] as? Int,
                   let total = budgetData["total"] as? Int {
                    tokenUsage = TokenUsage(used: used, total: total)
                }

            case "claude-complete":
                flushTextBuffer()

                if isReattaching {
                    isReattaching = false
                    onSessionAttached?()
                }

                isProcessing = false
                lastActiveToolName = nil
                cancelProcessingTimeout()
                if let sid = msg.sessionId {
                    sessionId = sid
                }

                // Check if this was a model switch that completed
                if isSwitchingModel {
                    modelSwitchTimeoutTask?.cancel()
                    // Try to parse model from accumulated text
                    if currentText.contains("Set model to") {
                        parseModelSwitchResponse(currentText)
                    } else {
                        // Timeout/fallback - reset switching state
                        log.warning("Model switch completed but no confirmation found in: \(currentText.prefix(200))")
                        isSwitchingModel = false
                    }
                }

                // Notification is sent via checkForCompletionAndNotify on callback thread
                // which works reliably when backgrounded. Clear processing state here.
                BackgroundManager.shared.clearProcessingState()

                onComplete?(msg.sessionId)

            case "claude-error":
                isProcessing = false
                isReattaching = false  // Reset on error
                lastActiveToolName = nil
                isSwitchingModel = false  // Reset on error
                clearTextBuffer()  // Clear debounce buffer on error
                cancelProcessingTimeout()
                let errorMsg = msg.error ?? "Unknown error"

                // Check if this is a session-related error that we can recover from
                if isSessionError(errorMsg) && sessionId != nil {
                    debugLog.logError("Session error (recovering): \(errorMsg)")
                    sessionId = nil
                    lastError = "Session expired, starting fresh..."
                    onSessionRecovered?()
                } else {
                    // Regular error - pass to UI
                    lastError = errorMsg
                    debugLog.logError("Claude error: \(errorMsg)")
                    onError?(errorMsg)
                }

            case "session-aborted":
                resetProcessingState()
                onAborted?()

            case "projects_updated":
                // Project list changed, could notify UI to refresh
                break

            case "sessions-updated":
                if let dataDict = msg.data?.value as? [String: Any],
                   let projectName = dataDict["projectName"] as? String,
                   let sessionId = dataDict["sessionId"] as? String,
                   let action = dataDict["action"] as? String {
                    Task {
                        await SessionStore.shared.handleSessionsUpdated(
                            projectName: projectName,
                            sessionId: sessionId,
                            action: action
                        )
                    }
                }

            case "permission-request":
                if let dataDict = msg.data?.value as? [String: Any],
                   let request = ApprovalRequest.from(dataDict) {
                    debugLog.log("Permission request: \(request.toolName)", type: .info)
                    pendingApproval = request

                    // Send approval notification for background
                    Task {
                        await NotificationManager.shared.sendApprovalNotification(
                            requestId: request.id,
                            toolName: request.toolName,
                            summary: request.displayDescription
                        )

                        // Update task state
                        if let sid = self.sessionId, let projectPath = BackgroundManager.shared.lastProjectPath {
                            var state = TaskState(sessionId: sid, projectPath: projectPath)
                            state.updateStatus(.awaitingApproval(request: BackgroundApprovalRequest(from: request)))
                            BackgroundManager.shared.updateTaskState(state)
                        }
                    }

                    onApprovalRequest?(request)
                }

        default:
            break
        }
    }

    private func handleClaudeResponse(_ data: [String: Any]) {
        let messageType = data["type"] as? String ?? data["role"] as? String

        guard let type = messageType else {
            if data["content"] != nil {
                processContent(data)
            }
            return
        }

        switch type {
        case "system":
            // System init message - contains session info and model
            // Note: session-created is already handled separately in parseMessage
            // Only update sessionId here if not already set (avoid duplicate notifications)
            if let subtype = data["subtype"] as? String, subtype == "init" {
                if let sid = data["session_id"] as? String, sessionId == nil {
                    sessionId = sid
                    // Don't call onSessionCreated here - it's handled by session-created message
                }
                if let modelId = data["model"] as? String {
                    currentModel = parseModelFromId(modelId)
                    currentModelId = modelId
                }
            }

        case "assistant":
            processContent(data)

        case "user":
            // User messages can contain tool results
            if let content = data["content"] as? [[String: Any]] {
                for part in content {
                    if let partType = part["type"] as? String, partType == "tool_result" {
                        if let resultContent = part["content"] as? String {
                            onToolResult?(resultContent)
                        } else if let resultParts = part["content"] as? [[String: Any]] {
                            // Tool result can have nested content
                            for resultPart in resultParts {
                                if let text = resultPart["text"] as? String {
                                    onToolResult?(text)
                                }
                            }
                        }
                    }
                }
            }

        case "result":
            break

        default:
            break
        }
    }

    // MARK: - Text Buffer Management (Debouncing)

    /// Accumulate text into buffer and schedule debounced flush
    private func appendToTextBuffer(_ text: String) {
        textBuffer += text

        if parseSynchronously {
            // Flush immediately in synchronous mode (for tests)
            flushTextBuffer()
        } else {
            // Cancel any pending flush
            textFlushTask?.cancel()

            // Schedule debounced flush
            textFlushTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: self.textFlushDelay)
                guard !Task.isCancelled else { return }
                self.flushTextBuffer()
            }
        }
    }

    /// Immediately flush buffer to currentText (called before tool use or on demand)
    private func flushTextBuffer() {
        textFlushTask?.cancel()
        guard !textBuffer.isEmpty else { return }

        currentText = textBuffer
        onText?(currentText)
    }

    /// Clear buffer and currentText (called when processing ends)
    private func clearTextBuffer() {
        textFlushTask?.cancel()
        textBuffer = ""
    }

    /// Process content from a message (handles both array and string content)
    private func processContent(_ data: [String: Any]) {
        // Handle content array
        if let content = data["content"] as? [[String: Any]] {
            for part in content {
                guard let partType = part["type"] as? String else { continue }

                switch partType {
                case "text":
                    if let text = part["text"] as? String, !text.isEmpty {
                        if isSwitchingModel, text.contains("Set model to") {
                            parseModelSwitchResponse(text)
                        }
                        appendToTextBuffer(text)
                    }

                case "tool_use":
                    // Flush buffer and commit text before tool use
                    flushTextBuffer()
                    if !currentText.isEmpty {
                        onTextCommit?(currentText)
                        currentText = ""
                        clearTextBuffer()
                    }
                    let name = part["name"] as? String ?? "tool"
                    let input = part["input"] as? [String: Any]

                    // Track tool name for timeout diagnostics
                    self.lastActiveToolName = name

                    // Check for AskUserQuestion tool - needs special handling
                    if name == "AskUserQuestion", let input = input,
                       let questionData = AskUserQuestionData.from(input) {
                        // Send question notification for background
                        if let firstQuestion = questionData.questions.first {
                            Task {
                                await NotificationManager.shared.sendQuestionNotification(
                                    questionId: UUID().uuidString,
                                    question: firstQuestion.question
                                )
                            }
                        }

                        onAskUserQuestion?(questionData)
                    } else {
                        // Regular tool use
                        // Use stringifyAnyValue to avoid "AnyCodable(value: ...)" in output
                        let inputStr = input.map { dict in
                            dict.map { "\($0.key): \(stringifyAnyValue($0.value))" }.joined(separator: ", ")
                        } ?? ""
                        onToolUse?(name, inputStr)
                    }

                case "thinking":
                    if let thinking = part["thinking"] as? String, !thinking.isEmpty {
                        onThinking?(thinking)
                    }

                default:
                    break
                }
            }
        }
        else if let content = data["content"] as? String, !content.isEmpty {
            appendToTextBuffer(content)
        }
        else if let message = data["message"] as? [String: Any], message["content"] != nil {
            processContent(message)
        }
    }
}
