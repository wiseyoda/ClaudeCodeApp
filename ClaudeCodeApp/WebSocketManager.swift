import Foundation
import UserNotifications

@MainActor
class WebSocketManager: ObservableObject {
    private var webSocket: URLSessionWebSocketTask?
    private var settings: AppSettings

    @Published var isConnected = false
    @Published var isProcessing = false
    @Published var currentText = ""
    @Published var lastError: String?
    @Published var sessionId: String?
    @Published var tokenUsage: TokenUsage?

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

    // Callbacks for streaming events
    var onText: ((String) -> Void)?
    var onToolUse: ((String, String) -> Void)?
    var onToolResult: ((String) -> Void)?
    var onThinking: ((String) -> Void)?  // For reasoning/thinking blocks
    var onComplete: ((String?) -> Void)?  // sessionId
    var onError: ((String) -> Void)?
    var onSessionCreated: ((String) -> Void)?

    init(settings: AppSettings) {
        self.settings = settings
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
                        print("[WS] Processing timeout - no response for 30s, resetting state")
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
            print("[WS] Skipping notification - app in foreground")
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
                print("[WS] Notification error: \(error)")
            }
        }
    }

    func connect() {
        guard let url = settings.webSocketURL else {
            lastError = "Invalid WebSocket URL"
            return
        }

        // Cancel any pending reconnection
        reconnectTask?.cancel()
        reconnectTask = nil
        isReconnecting = false

        // Clean up existing connection if any
        webSocket?.cancel(with: .goingAway, reason: nil)

        print("[WS] Connecting to: \(url)")

        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()

        isConnected = true
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
        isConnected = false
        isProcessing = false
    }

    /// Schedule a reconnection with exponential backoff
    private func scheduleReconnect() {
        guard !isReconnecting else {
            print("[WS] Reconnection already scheduled, skipping")
            return
        }

        isReconnecting = true

        // Calculate delay with exponential backoff: 1s, 2s, 4s, 8s max
        let baseDelay: Double = 1.0
        let delay = baseDelay * pow(2.0, Double(min(reconnectAttempt, maxReconnectAttempt - 1)))
        // Add jitter (0-500ms) to prevent thundering herd
        let jitter = Double.random(in: 0...0.5)
        let totalDelay = delay + jitter

        reconnectAttempt += 1
        print("[WS] Scheduling reconnect attempt \(reconnectAttempt) in \(String(format: "%.1f", totalDelay))s")

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(totalDelay * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self = self else { return }
                self.isReconnecting = false
                if !self.isConnected {
                    self.connect()
                }
            }
        }
    }

    func sendMessage(_ message: String, projectPath: String, resumeSessionId: String? = nil, permissionMode: String? = nil, imageData: Data? = nil) {
        guard isConnected else {
            connect()
            // Queue message after connection establishes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                if self.isConnected {
                    self.sendMessage(message, projectPath: projectPath, resumeSessionId: resumeSessionId, permissionMode: permissionMode, imageData: imageData)
                } else {
                    self.lastError = "Failed to connect to server"
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
        if let imageData = imageData {
            let base64String = imageData.base64EncodedString()
            // Detect image type from data header
            let mediaType = detectMediaType(from: imageData)
            images = [WSImage(mediaType: mediaType, data: base64String)]
            print("[WS] Attaching image: \(mediaType), \(base64String.count) chars base64")
        }

        let command = WSClaudeCommand(
            command: message,
            options: WSCommandOptions(
                cwd: projectPath,
                sessionId: resumeSessionId ?? sessionId,
                model: nil,
                permissionMode: permissionMode
            ),
            images: images
        )

        do {
            let data = try JSONEncoder().encode(command)
            if let jsonString = String(data: data, encoding: .utf8) {
                print("[WS] Sending with permissionMode=\(permissionMode ?? "nil"): \(jsonString.prefix(300))")
                webSocket?.send(.string(jsonString)) { [weak self] error in
                    if let error = error {
                        Task { @MainActor in
                            self?.lastError = error.localizedDescription
                            self?.isProcessing = false
                            // Connection may have dropped, trigger reconnect
                            self?.isConnected = false
                            self?.scheduleReconnect()
                        }
                    }
                }
            }
        } catch {
            lastError = error.localizedDescription
            isProcessing = false
        }
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
            print("[WS] Failed to encode abort: \(error)")
        }

        isProcessing = false
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let message):
                    self?.handleMessage(message)
                    self?.receiveMessage()  // Continue listening

                case .failure(let error):
                    print("[WS] Receive error: \(error)")
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
        print("[WS] Received: \(text.prefix(300))")

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
                    print("[WS] claude-response outer type: \(outerType ?? "nil")")

                    if outerType == "assistant", let messageData = responseData["message"] as? [String: Any] {
                        // For assistant messages, the content is in message.content
                        print("[WS] Processing assistant message wrapper")
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
                // Send notification when task completes (only if backgrounded)
                let preview = currentText.prefix(100)
                sendLocalNotification(
                    title: "Claude Code",
                    body: preview.isEmpty ? "Task completed" : String(preview)
                )
                onComplete?(msg.sessionId)

            case "claude-error":
                isProcessing = false
                cancelProcessingTimeout()
                let errorMsg = msg.error ?? "Unknown error"
                lastError = errorMsg
                onError?(errorMsg)

            case "session-aborted":
                isProcessing = false
                cancelProcessingTimeout()

            case "projects_updated":
                // Project list changed, could notify UI to refresh
                break

            default:
                print("[WS] Unknown message type: \(msg.type)")
            }

        } catch {
            print("[WS] Parse error: \(error), text: \(text.prefix(200))")
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
        print("[WS] handleClaudeResponse keys: \(data.keys.sorted())")
        if let type = data["type"] {
            print("[WS] handleClaudeResponse type: \(type)")
        }
        if let role = data["role"] {
            print("[WS] handleClaudeResponse role: \(role)")
        }
        if let content = data["content"] {
            print("[WS] handleClaudeResponse content type: \(Swift.type(of: content))")
        }

        // Check for type field (SDK format) or role field (API format)
        let messageType = data["type"] as? String ?? data["role"] as? String

        // If no type, but has content, process it directly (SDK sometimes omits type)
        if messageType == nil {
            if data["content"] != nil {
                print("[WS] No type but has content, processing directly")
                processContent(data)
                return
            }
            print("[WS] No type/role in claude-response: \(data.keys)")
            return
        }

        let type = messageType!

        switch type {
        case "system":
            // System init message - contains session info
            // Note: session-created is already handled separately in parseMessage
            // Only update sessionId here if not already set (avoid duplicate notifications)
            if let subtype = data["subtype"] as? String, subtype == "init" {
                if let sid = data["session_id"] as? String, sessionId == nil {
                    sessionId = sid
                    // Don't call onSessionCreated here - it's handled by session-created message
                }
            }

        case "assistant":
            // Assistant message with content array
            print("[WS] Processing assistant message")
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
            print("[WS] Unknown SDK message type: \(type)")
        }
    }

    /// Detect image media type from data header (magic bytes)
    private func detectMediaType(from data: Data) -> String {
        guard data.count >= 4 else { return "image/jpeg" }

        let bytes = [UInt8](data.prefix(4))

        // PNG: 89 50 4E 47
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "image/png"
        }
        // GIF: 47 49 46 38
        if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38 {
            return "image/gif"
        }
        // WebP: 52 49 46 46 ... 57 45 42 50
        if bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 {
            if data.count >= 12 {
                let webpBytes = [UInt8](data[8..<12])
                if webpBytes[0] == 0x57 && webpBytes[1] == 0x45 && webpBytes[2] == 0x42 && webpBytes[3] == 0x50 {
                    return "image/webp"
                }
            }
        }
        // Default to JPEG
        return "image/jpeg"
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
                        print("[WS] Found text in content array: \(text.prefix(100))")
                        currentText += text
                        onText?(currentText)
                    }

                case "tool_use":
                    let name = part["name"] as? String ?? "tool"
                    let input = part["input"] as? [String: Any]
                    let inputStr = input.map { dict in
                        dict.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
                    } ?? ""
                    onToolUse?(name, inputStr)

                case "thinking":
                    // Extended thinking/reasoning block
                    if let thinking = part["thinking"] as? String, !thinking.isEmpty {
                        print("[WS] Found thinking block: \(thinking.prefix(100))")
                        onThinking?(thinking)
                    }

                default:
                    print("[WS] Unknown content part type: \(partType)")
                }
            }
        }
        // Handle string content
        else if let content = data["content"] as? String, !content.isEmpty {
            print("[WS] Found string content: \(content.prefix(100))")
            currentText += content
            onText?(currentText)
        }
        // Handle message.content nested structure
        else if let message = data["message"] as? [String: Any],
                message["content"] != nil {
            print("[WS] Found nested message.content")
            processContent(message)
        }
    }
}
