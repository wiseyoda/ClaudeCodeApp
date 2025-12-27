import Foundation
import UserNotifications

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
    @Published var currentText = ""
    @Published var lastError: String?
    @Published var sessionId: String?
    @Published var tokenUsage: TokenUsage?
    @Published var currentModel: ClaudeModel?
    @Published var currentModelId: String?  // The full model ID (e.g., "claude-sonnet-4-5-20250929")
    @Published var isSwitchingModel = false

    /// Track whether app is in foreground - set by ChatView
    var isAppInForeground = true

    // Reconnection state
    private var isReconnecting = false
    private var reconnectAttempt = 0
    private var reconnectTask: Task<Void, Never>?
    private let maxReconnectAttempt = 4  // 1s, 2s, 4s, 8s max

    // Processing timeout - reset if no response for 30 seconds
    private var processingTimeoutTask: Task<Void, Never>?
    private var lastResponseTime: Date?

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

    private var pendingMessage: PendingMessage?
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

    /// Initialize with optional settings. Call updateSettings() in onAppear with the EnvironmentObject.
    init(settings: AppSettings? = nil) {
        // Use provided settings or create temporary placeholder
        // The real settings should be provided via updateSettings() in onAppear
        self.settings = settings ?? AppSettings()
    }

    /// Update settings reference (call from onAppear with actual EnvironmentObject)
    func updateSettings(_ newSettings: AppSettings) {
        self.settings = newSettings
    }

    /// Start or reset the processing timeout
    private func startProcessingTimeout() {
        processingTimeoutTask?.cancel()
        lastResponseTime = Date()

        processingTimeoutTask = Task { [weak self] in
            // Wait 30 seconds
            try? await Task.sleep(nanoseconds: 30_000_000_000)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self = self else { return }
                // Check if we're still processing and haven't received any response
                if self.isProcessing {
                    if let lastResponse = self.lastResponseTime,
                       Date().timeIntervalSince(lastResponse) >= 30 {
                        log.warning("Processing timeout - no response for 30s, resetting state")
                        self.isProcessing = false
                        self.lastError = "Request timed out - no response from server"
                        self.onError?("Request timed out")
                    }
                }
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
        guard !isAppInForeground else {
            log.debug("Skipping notification - app in foreground")
            return
        }

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
            return
        }

        // Cancel any pending reconnection
        reconnectTask?.cancel()
        reconnectTask = nil
        isReconnecting = false

        // Clean up existing connection if any
        webSocket?.cancel(with: .goingAway, reason: nil)

        // Set connecting state (preserve reconnect attempt for UI if reconnecting)
        if case .reconnecting(let attempt) = connectionState {
            log.info("Reconnecting to: \(url) (attempt \(attempt))")
        } else {
            connectionState = .connecting
            log.info("Connecting to: \(url)")
        }

        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()

        connectionState = .connected
        lastError = nil

        // Reset reconnection counter on successful connect
        reconnectAttempt = 0

        receiveMessage()
    }

    func disconnect() {
        // Cancel any pending reconnection
        reconnectTask?.cancel()
        reconnectTask = nil
        isReconnecting = false
        reconnectAttempt = 0
        cancelProcessingTimeout()

        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        connectionState = .disconnected
        isProcessing = false
    }

    /// Schedule a reconnection with exponential backoff
    private func scheduleReconnect() {
        guard !isReconnecting else {
            log.debug("Reconnection already scheduled, skipping")
            return
        }

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

        log.info("Scheduling reconnect attempt \(reconnectAttempt) in \(String(format: "%.1f", totalDelay))s")

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
        // Store as pending message for potential retry
        pendingMessage = PendingMessage(
            message: message,
            projectPath: projectPath,
            sessionId: resumeSessionId ?? sessionId,
            permissionMode: permissionMode,
            imageData: imageData,
            model: model
        )

        sendPendingMessage()
    }

    private func sendPendingMessage() {
        guard let pending = pendingMessage else { return }

        guard isConnected else {
            connect()
            // Queue message after connection establishes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                if self.isConnected {
                    self.sendPendingMessage()
                } else {
                    self.handleSendFailure(AppError.connectionFailed("Not connected"))
                }
            }
            return
        }

        currentText = ""
        isProcessing = true
        lastError = nil
        startProcessingTimeout()

        // Convert image data to base64 WSImage if present
        var images: [WSImage]? = nil
        if let imageData = pending.imageData {
            let base64String = imageData.base64EncodedString()
            // Detect image type from data header
            let mediaType = ImageUtilities.detectMediaType(from: imageData)
            images = [WSImage(mediaType: mediaType, base64Data: base64String)]
            log.debug("Attaching image: \(mediaType), \(base64String.count) chars base64")
        }

        let command = WSClaudeCommand(
            command: pending.message,
            options: WSCommandOptions(
                cwd: pending.projectPath,
                sessionId: pending.sessionId,
                model: pending.model,
                permissionMode: pending.permissionMode,
                images: images  // Images go inside options
            )
        )

        do {
            let data = try JSONEncoder().encode(command)
            if let jsonString = String(data: data, encoding: .utf8) {
                log.debug("Sending (attempt \(pending.attempts + 1)): \(jsonString.prefix(300))")
                webSocket?.send(.string(jsonString)) { [weak self] error in
                    if let error = error {
                        Task { @MainActor in
                            self?.handleSendFailure(AppError.messageFailed(error.localizedDescription))
                        }
                    } else {
                        // Success - clear pending message
                        Task { @MainActor in
                            self?.pendingMessage = nil
                            self?.retryTask?.cancel()
                        }
                    }
                }
            }
        } catch {
            handleSendFailure(AppError.messageFailed(error.localizedDescription))
        }
    }

    /// Handle send failure with retry logic
    private func handleSendFailure(_ error: AppError) {
        guard var pending = pendingMessage else {
            lastError = error.localizedDescription
            isProcessing = false
            onError?(error.localizedDescription)
            return
        }

        pending.attempts += 1
        pendingMessage = pending

        if pending.attempts >= maxRetries {
            // Give up after max retries
            log.error("Message failed after \(maxRetries) attempts: \(error.localizedDescription)")
            lastError = "Message failed after \(maxRetries) attempts"
            isProcessing = false
            pendingMessage = nil
            onError?("Message failed after \(maxRetries) attempts. Please try again.")
            return
        }

        // Schedule retry with exponential backoff
        let delayIndex = min(pending.attempts - 1, retryDelays.count - 1)
        let delay = retryDelays[delayIndex]

        log.info("Retrying message in \(delay)s (attempt \(pending.attempts + 1)/\(maxRetries))")

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
                    self.sendPendingMessage()
                }
            }
        }
    }

    /// Cancel any pending retry
    func cancelPendingRetry() {
        retryTask?.cancel()
        pendingMessage = nil
    }

    func abortSession() {
        guard let sid = sessionId else { return }

        let abort = WSAbortSession(sessionId: sid)

        do {
            let data = try JSONEncoder().encode(abort)
            if let jsonString = String(data: data, encoding: .utf8) {
                webSocket?.send(.string(jsonString)) { _ in }
            }
        } catch {
            log.error("Failed to encode abort: \(error)")
        }

        isProcessing = false
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

        // Send via WebSocket directly (not through sendMessage which adds to pending)
        let wsCommand = WSClaudeCommand(
            command: command,
            options: WSCommandOptions(
                cwd: projectPath,
                sessionId: sessionId,
                model: nil,
                permissionMode: nil,
                images: nil
            )
        )

        do {
            let data = try JSONEncoder().encode(wsCommand)
            if let jsonString = String(data: data, encoding: .utf8) {
                log.debug("Sending model switch: \(jsonString)")
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
            log.info("Model switch confirmed: \(model.displayName) (\(modelId))")

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

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let message):
                    self?.handleMessage(message)
                    self?.receiveMessage()  // Continue listening

                case .failure(let error):
                    log.error("Receive error: \(error)")
                    self?.isConnected = false
                    self?.isProcessing = false  // Reset processing state on disconnect
                    self?.cancelProcessingTimeout()
                    self?.lastError = error.localizedDescription

                    // Clear stale state on disconnect
                    self?.currentText = ""

                    // Schedule reconnection with exponential backoff
                    self?.scheduleReconnect()
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

    private func parseMessage(_ text: String) {
        log.debug("Received: \(text.prefix(300))")

        // Reset timeout on any received message
        resetProcessingTimeout()

        guard let data = text.data(using: .utf8) else { return }

        do {
            let msg = try JSONDecoder().decode(WSMessage.self, from: data)

            switch msg.type {
            case "session-created":
                if let sid = msg.sessionId {
                    sessionId = sid
                    onSessionCreated?(sid)
                }

            case "claude-response":
                if let responseData = msg.data?.dictValue {
                    // SDK sends different message formats:
                    // 1. System init: {type: "system", subtype: "init", session_id: ...}
                    // 2. Assistant: {type: "assistant", message: {role: "assistant", content: [...]}}
                    // 3. Result: {type: "result", ...}

                    let outerType = responseData["type"] as? String
                    log.debug("claude-response outer type: \(outerType ?? "nil")")

                    if outerType == "assistant", let messageData = responseData["message"] as? [String: Any] {
                        // For assistant messages, the content is in message.content
                        log.debug("Processing assistant message wrapper")
                        processContent(messageData)
                    } else {
                        // For system, result, and other types
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
                isProcessing = false
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

                // Send notification when task completes (only if backgrounded)
                let preview = currentText.prefix(100)
                sendLocalNotification(
                    title: "Claude Code",
                    body: preview.isEmpty ? "Task completed" : String(preview)
                )
                onComplete?(msg.sessionId)

            case "claude-error":
                isProcessing = false
                isSwitchingModel = false  // Reset on error
                cancelProcessingTimeout()
                let errorMsg = msg.error ?? "Unknown error"
                lastError = errorMsg
                onError?(errorMsg)

            case "session-aborted":
                isProcessing = false
                isSwitchingModel = false  // Reset on abort
                cancelProcessingTimeout()

            case "projects_updated":
                // Project list changed, could notify UI to refresh
                break

            default:
                log.debug("Unknown message type: \(msg.type)")
            }

        } catch {
            log.error("Parse error: \(error), text: \(text.prefix(200))")
            // Notify UI of parse errors (but don't stop processing - could be non-critical)
            lastError = "Message parse error: \(error.localizedDescription)"
        }
    }

    private func handleClaudeResponse(_ data: [String: Any]) {
        // The SDK sends messages with different top-level types:
        // - type: "system" (with subtype: "init", session_id, model, tools)
        // - type: "assistant" (with content array)
        // - type: "user" (with tool results)
        // - type: "result" (final summary with modelUsage)

        // Debug: log all keys and type
        log.debug("handleClaudeResponse keys: \(data.keys.sorted())")
        if let type = data["type"] {
            log.debug("handleClaudeResponse type: \(type)")
        }
        if let role = data["role"] {
            log.debug("handleClaudeResponse role: \(role)")
        }
        if let content = data["content"] {
            log.debug("handleClaudeResponse content type: \(Swift.type(of: content))")
        }

        // Check for type field (SDK format) or role field (API format)
        let messageType = data["type"] as? String ?? data["role"] as? String

        // If no type, but has content, process it directly (SDK sometimes omits type)
        if messageType == nil {
            if data["content"] != nil {
                log.debug("No type but has content, processing directly")
                processContent(data)
                return
            }
            log.debug("No type/role in claude-response: \(data.keys)")
            return
        }

        let type = messageType!

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
                // Capture the model from system init
                if let modelId = data["model"] as? String {
                    let model = parseModelFromId(modelId)
                    log.info("Session model from init: \(model.displayName) (\(modelId))")
                    currentModel = model
                    currentModelId = modelId
                }
            }

        case "assistant":
            // Assistant message with content array
            log.debug("Processing assistant message")
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
            // Final result message - contains modelUsage for token tracking
            // Token budget is handled separately via token-budget message
            break

        default:
            log.debug("Unknown SDK message type: \(type)")
        }
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
                        log.debug("Found text in content array: \(text.prefix(100))")

                        // Check for model switch confirmation: "Set model to sonnet (claude-sonnet-4-5-20250929)"
                        if isSwitchingModel, text.contains("Set model to") {
                            parseModelSwitchResponse(text)
                        }

                        currentText += text
                        onText?(currentText)
                    }

                case "tool_use":
                    // Commit any accumulated text before the tool use
                    if !currentText.isEmpty {
                        onTextCommit?(currentText)
                        currentText = ""
                    }
                    let name = part["name"] as? String ?? "tool"
                    let input = part["input"] as? [String: Any]

                    // Check for AskUserQuestion tool - needs special handling
                    if name == "AskUserQuestion", let input = input,
                       let questionData = AskUserQuestionData.from(input) {
                        log.debug("Detected AskUserQuestion tool with \(questionData.questions.count) questions")
                        onAskUserQuestion?(questionData)
                    } else {
                        // Regular tool use
                        let inputStr = input.map { dict in
                            dict.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
                        } ?? ""
                        onToolUse?(name, inputStr)
                    }

                case "thinking":
                    // Extended thinking/reasoning block
                    if let thinking = part["thinking"] as? String, !thinking.isEmpty {
                        log.debug("Found thinking block: \(thinking.prefix(100))")
                        onThinking?(thinking)
                    }

                default:
                    log.debug("Unknown content part type: \(partType)")
                }
            }
        }
        // Handle string content
        else if let content = data["content"] as? String, !content.isEmpty {
            log.debug("Found string content: \(content.prefix(100))")
            currentText += content
            onText?(currentText)
        }
        // Handle message.content nested structure
        else if let message = data["message"] as? [String: Any],
                message["content"] != nil {
            log.debug("Found nested message.content")
            processContent(message)
        }
    }
}
