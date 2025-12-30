import Foundation
import Network
import UIKit

// MARK: - CLI Bridge WebSocket Manager
// Manages WebSocket connection to cli-bridge server with robust lifecycle handling
// See: requirements/projects/cli-bridge-migration/PROTOCOL-MAPPING.md
// See: cli-bridge-upgrade-3.md for agent lifecycle specification

/// Connection state for cli-bridge WebSocket
enum CLIConnectionState: Equatable {
    case disconnected
    case connecting
    case connected(agentId: String)
    case reconnecting(attempt: Int)

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

    var agentId: String? {
        if case .connected(let id) = self { return id }
        return nil
    }
}

@MainActor
class CLIBridgeManager: ObservableObject {
    // MARK: - Published State

    @Published var connectionState: CLIConnectionState = .disconnected
    @Published var agentState: CLIAgentState = .idle
    @Published var sessionId: String?
    @Published var currentModel: String?
    @Published var protocolVersion: String?

    /// Current streaming text (accumulates during response)
    @Published var currentText: String = ""

    /// Token usage for current session
    @Published var tokenUsage: CLIUsageContent?

    /// Last error message
    @Published var lastError: String?

    /// Current pending permission request
    @Published var pendingPermission: CLIPermissionRequest?

    /// Current pending question
    @Published var pendingQuestion: CLIQuestionRequest?

    /// Input is queued (sent while agent was busy)
    @Published var isInputQueued: Bool = false
    @Published var queuePosition: Int = 0

    /// Active subagent (if any)
    @Published var activeSubagent: CLISubagentStartContent?

    /// Progress for long-running tool
    @Published var toolProgress: CLIProgressContent?

    // MARK: - Callbacks

    /// Called when streaming text arrives
    var onText: ((String, Bool) -> Void)?  // (content, isFinal)

    /// Called when thinking/reasoning block arrives
    var onThinking: ((String) -> Void)?

    /// Called when tool starts executing
    var onToolStart: ((String, String, [String: Any]) -> Void)?  // (id, tool, input)

    /// Called when tool completes
    var onToolResult: ((String, String, String, Bool) -> Void)?  // (id, tool, output, success)

    /// Called when agent stops
    var onStopped: ((String) -> Void)?  // reason

    /// Called on error
    var onError: ((CLIErrorPayload) -> Void)?

    /// Called when session is created/connected
    var onSessionConnected: ((String) -> Void)?  // sessionId

    /// Called when model changes
    var onModelChanged: ((String) -> Void)?

    /// Called when permission is needed
    var onPermissionRequest: ((CLIPermissionRequest) -> Void)?

    /// Called when question is asked
    var onQuestionRequest: ((CLIQuestionRequest) -> Void)?

    /// Called when permission mode changes (server confirmation)
    var onPermissionModeChanged: ((String) -> Void)?

    /// Called when session event occurs (for session list updates)
    var onSessionEvent: ((CLISessionEvent) -> Void)?

    /// Called when history is received (session resume)
    var onHistory: ((CLIHistoryPayload) -> Void)?

    /// Called when subagent starts
    var onSubagentStart: ((CLISubagentStartContent) -> Void)?

    /// Called when subagent completes
    var onSubagentComplete: ((CLISubagentCompleteContent) -> Void)?

    // MARK: - Private State

    private var webSocket: URLSessionWebSocketTask?
    private var serverURL: String
    private var reconnectAttempt = 0
    private var reconnectTask: Task<Void, Never>?
    private let maxReconnectAttempts = 5
    private var lastMessageId: String?
    private var currentAgentId: String?

    /// Buffer for text to reduce UI updates
    private var textBuffer: String = ""
    private var textFlushTask: Task<Void, Never>?
    private let textFlushDelay: UInt64 = 50_000_000  // 50ms

    /// Track receive loop to detect stale callbacks
    private var connectionId = UUID()

    /// Track if disconnect was intentional (user-initiated)
    private var isManualDisconnect = false

    /// Pending connection parameters for reconnection
    private var pendingProjectPath: String?
    private var pendingSessionId: String?
    private var pendingModel: String?
    private var pendingHelper: Bool = false

    // MARK: - Lifecycle State

    /// Background task identifier for keeping connection during brief backgrounding
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    /// Network path monitor for detecting connectivity changes
    private var networkMonitor: NWPathMonitor?
    private let networkQueue = DispatchQueue(label: "com.codingbridge.network")

    /// Whether network is currently available
    private var isNetworkAvailable = true

    /// Notification observers for lifecycle events
    private var lifecycleObservers: [NSObjectProtocol] = []

    // MARK: - Lifecycle Callbacks

    /// Called when connection is replaced by another client
    var onConnectionReplaced: (() -> Void)?

    /// Called when reconnection will be attempted
    var onReconnecting: ((Int, TimeInterval) -> Void)?  // (attempt, delay)

    /// Called when a connection error occurs
    var onConnectionError: ((ConnectionError) -> Void)?

    /// Called when network status changes
    var onNetworkStatusChanged: ((Bool) -> Void)?  // isAvailable

    // MARK: - Initialization

    init(serverURL: String = "") {
        self.serverURL = serverURL
        setupLifecycleObservers()
        setupNetworkMonitoring()
    }

    deinit {
        // Clean up lifecycle observers
        for observer in lifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }

        // Stop network monitoring
        networkMonitor?.cancel()

        // End any background task on main thread
        let task = backgroundTask
        if task != .invalid {
            Task { @MainActor in
                UIApplication.shared.endBackgroundTask(task)
            }
        }
    }

    func updateServerURL(_ url: String) {
        self.serverURL = url
    }

    // MARK: - Lifecycle Setup

    private func setupLifecycleObservers() {
        // App will resign active (going to background)
        let resignObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppWillResignActive()
            }
        }
        lifecycleObservers.append(resignObserver)

        // App did enter background
        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppDidEnterBackground()
            }
        }
        lifecycleObservers.append(backgroundObserver)

        // App did become active (returning from background)
        let activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppDidBecomeActive()
            }
        }
        lifecycleObservers.append(activeObserver)

        log.debug("[CLIBridge] Lifecycle observers set up")
    }

    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()

        networkMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                let wasAvailable = self.isNetworkAvailable
                self.isNetworkAvailable = path.status == .satisfied

                if self.isNetworkAvailable != wasAvailable {
                    log.debug("[CLIBridge] Network status changed: \(self.isNetworkAvailable ? "available" : "unavailable")")
                    self.onNetworkStatusChanged?(self.isNetworkAvailable)

                    // Network restored - attempt reconnect if we were disconnected
                    if self.isNetworkAvailable && !wasAvailable {
                        self.handleNetworkRestored()
                    }
                }
            }
        }

        networkMonitor?.start(queue: networkQueue)
        log.debug("[CLIBridge] Network monitoring started")
    }

    // MARK: - Lifecycle Handlers

    private func handleAppWillResignActive() {
        log.debug("[CLIBridge] App will resign active")
        // Don't disconnect yet - WebSocket may stay open briefly
    }

    private func handleAppDidEnterBackground() {
        log.debug("[CLIBridge] App entering background, state: \(agentState)")

        // Start background task to keep connection briefly
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // Time's up - clean disconnect but preserve session for reconnection
            log.debug("[CLIBridge] Background time expired")
            self?.disconnectForBackground()
            self?.endBackgroundTask()
        }

        // If agent is idle, we can safely disconnect - agent survives on server
        if agentState == .idle || agentState == .stopped {
            log.debug("[CLIBridge] Agent idle, disconnecting for background")
            disconnectForBackground()
            endBackgroundTask()
        }
        // If running, keep connection open for completion notification
        // iOS gives ~30 seconds max in background
    }

    private func handleAppDidBecomeActive() {
        log.debug("[CLIBridge] App became active")
        endBackgroundTask()

        // Reconnect if we were disconnected and have a session
        if webSocket == nil && sessionId != nil {
            log.debug("[CLIBridge] Reconnecting after foreground")
            reconnectWithExistingSession()
        }
    }

    private func handleNetworkRestored() {
        log.debug("[CLIBridge] Network restored")

        // Only reconnect if we were disconnected and have a session
        if webSocket == nil && sessionId != nil && !isManualDisconnect {
            log.debug("[CLIBridge] Attempting reconnect after network restore")
            reconnectWithExistingSession()
        }
    }

    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    private func reconnectWithExistingSession() {
        guard let projectPath = pendingProjectPath else { return }

        Task {
            await connect(
                projectPath: projectPath,
                sessionId: sessionId ?? pendingSessionId,
                model: pendingModel,
                helper: pendingHelper
            )
        }
    }

    // MARK: - Connection Management

    /// Connect to cli-bridge and start a new agent
    func connect(
        projectPath: String,
        sessionId: String? = nil,
        model: String? = nil,
        helper: Bool = false
    ) async {
        guard !connectionState.isConnected && !connectionState.isConnecting else {
            log.debug("Already connected or connecting")
            return
        }

        // Check network availability
        guard isNetworkAvailable else {
            log.warning("[CLIBridge] No network available")
            lastError = "No network connection"
            onConnectionError?(.networkUnavailable)
            return
        }

        // Reset manual disconnect flag
        isManualDisconnect = false

        // Store for reconnection
        pendingProjectPath = projectPath
        pendingSessionId = sessionId
        pendingModel = model
        pendingHelper = helper

        connectionState = .connecting
        agentState = .starting
        lastError = nil

        // Build WebSocket URL
        guard let wsURL = buildWebSocketURL() else {
            lastError = "Invalid server URL"
            connectionState = .disconnected
            agentState = .stopped
            onConnectionError?(.invalidServerURL)
            return
        }

        // Create WebSocket connection
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: wsURL)
        webSocket?.resume()

        // Start receive loop
        let currentConnectionId = UUID()
        self.connectionId = currentConnectionId
        startReceiveLoop(connectionId: currentConnectionId)

        // Send start message
        let startPayload = CLIStartPayload(
            projectPath: projectPath,
            sessionId: sessionId,
            model: model,
            helper: helper
        )

        do {
            try await send(.start(startPayload))
            reconnectAttempt = 0
        } catch {
            log.error("Failed to send start message: \(error)")
            lastError = error.localizedDescription
            connectionState = .disconnected
            agentState = .stopped
        }
    }

    /// Reconnect to an existing agent
    func reconnect(agentId: String, lastMessageId: String? = nil) async {
        guard !connectionState.isConnected else {
            log.debug("Already connected")
            return
        }

        connectionState = .reconnecting(attempt: reconnectAttempt + 1)

        guard let wsURL = buildWebSocketURL() else {
            lastError = "Invalid server URL"
            connectionState = .disconnected
            return
        }

        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: wsURL)
        webSocket?.resume()

        let currentConnectionId = UUID()
        self.connectionId = currentConnectionId
        startReceiveLoop(connectionId: currentConnectionId)

        // TODO: Send reconnect message when cli-bridge supports it
        // For now, we'll need to start a new session
    }

    /// Disconnect from the server
    /// - Parameter preserveSession: If true, keeps sessionId for reconnection (default: false)
    func disconnect(preserveSession: Bool = false) {
        isManualDisconnect = true

        reconnectTask?.cancel()
        reconnectTask = nil
        textFlushTask?.cancel()
        textFlushTask = nil

        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil

        connectionState = .disconnected
        agentState = .stopped
        currentAgentId = nil

        if !preserveSession {
            sessionId = nil
            pendingSessionId = nil
        }

        currentText = ""
        pendingPermission = nil
        pendingQuestion = nil
        isInputQueued = false
        activeSubagent = nil
        toolProgress = nil

        log.debug("[CLIBridge] Disconnected (preserveSession: \(preserveSession))")
    }

    /// Disconnect but preserve session for later reconnection
    /// Use this when going to background or network drops
    func disconnectForBackground() {
        log.debug("[CLIBridge] Disconnecting for background, preserving session")

        isManualDisconnect = false  // Allow auto-reconnect

        reconnectTask?.cancel()
        reconnectTask = nil
        textFlushTask?.cancel()
        textFlushTask = nil

        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil

        // Preserve session info but update state
        connectionState = .disconnected
        // Don't change agent state - it may still be running on server
    }

    // MARK: - Message Sending

    /// Send user input to the agent
    func sendInput(_ text: String, images: [CLIImageAttachment]? = nil, thinkingMode: String? = nil) async throws {
        let payload = CLIInputPayload(text: text, images: images, thinkingMode: thinkingMode)
        try await send(.input(payload))
    }

    /// Interrupt the current operation (pause without ending)
    func interrupt() async throws {
        try await send(.interrupt)
    }

    /// Stop the agent (end session)
    func stop() async throws {
        try await send(.stop)
    }

    /// Respond to a permission request
    func respondToPermission(id: String, choice: CLIPermissionResponsePayload.CLIPermissionChoice) async throws {
        let payload = CLIPermissionResponsePayload(id: id, choice: choice)
        try await send(.permissionResponse(payload))
        pendingPermission = nil
    }

    /// Respond to a question
    func respondToQuestion(id: String, answers: [String: Any]) async throws {
        let payload = CLIQuestionResponsePayload(
            id: id,
            answers: answers.mapValues { AnyCodableValue($0) }
        )
        try await send(.questionResponse(payload))
        pendingQuestion = nil
    }

    /// Subscribe to session events for a project
    func subscribeToSessions(projectPath: String? = nil) async throws {
        let payload = CLISubscribeSessionsPayload(projectPath: projectPath)
        try await send(.subscribeSessions(payload))
    }

    /// Change the model mid-session
    func setModel(_ model: String) async throws {
        try await send(.setModel(CLISetModelPayload(model: model)))
    }

    /// Set permission mode for the agent
    /// - Parameter mode: "default", "acceptEdits", or "bypassPermissions"
    func setPermissionMode(_ mode: CLISetPermissionModePayload.CLIPermissionMode) async throws {
        try await send(.setPermissionMode(CLISetPermissionModePayload(mode: mode)))
    }

    /// Cancel queued input
    func cancelQueuedInput() async throws {
        try await send(.cancelQueued)
    }

    /// Retry a failed message
    func retry(messageId: String) async throws {
        let payload = CLIRetryPayload(messageId: messageId)
        try await send(.retry(payload))
    }

    /// Send ping for keepalive
    func ping() async throws {
        try await send(.ping)
    }

    // MARK: - Private Methods

    private func buildWebSocketURL() -> URL? {
        var urlString = serverURL
        if urlString.isEmpty { return nil }

        // Ensure we have ws:// or wss://
        if urlString.hasPrefix("http://") {
            urlString = "ws://" + urlString.dropFirst("http://".count)
        } else if urlString.hasPrefix("https://") {
            urlString = "wss://" + urlString.dropFirst("https://".count)
        } else if !urlString.hasPrefix("ws://") && !urlString.hasPrefix("wss://") {
            urlString = "ws://" + urlString
        }

        // Remove trailing slash and add /ws endpoint
        if urlString.hasSuffix("/") {
            urlString = String(urlString.dropLast())
        }
        urlString += "/ws"

        return URL(string: urlString)
    }

    private func send(_ message: CLIClientMessage) async throws {
        guard let webSocket = webSocket else {
            throw CLIBridgeError.notConnected
        }

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)

        // Convert to string for WebSocket text message (cli-bridge expects text, not binary)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw CLIBridgeError.encodingError
        }

        log.debug("[WS] → Sending: \(jsonString.prefix(500))")

        // Send as text message, not binary data
        try await webSocket.send(.string(jsonString))
    }

    private func startReceiveLoop(connectionId: UUID) {
        Task { [weak self] in
            guard let self = self else { return }

            while self.connectionId == connectionId {
                do {
                    guard let message = try await self.webSocket?.receive() else {
                        break
                    }

                    // Ensure we're still on the same connection
                    guard self.connectionId == connectionId else { break }

                    await self.handleMessage(message)
                } catch {
                    // Check if this is our current connection
                    guard self.connectionId == connectionId else { break }

                    log.error("WebSocket receive error: \(error)")
                    await self.handleDisconnect(error: error)
                    break
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        let data: Data
        switch message {
        case .data(let d):
            data = d
        case .string(let s):
            data = Data(s.utf8)
        @unknown default:
            return
        }

        // Debug: Log raw incoming message
        if let jsonString = String(data: data, encoding: .utf8) {
            log.debug("[WS] ← Received: \(jsonString.prefix(500))")
        }

        do {
            let serverMessage = try JSONDecoder().decode(CLIServerMessage.self, from: data)
            await processServerMessage(serverMessage)
        } catch {
            log.error("[WS] Failed to decode server message: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                log.error("[WS] Raw message that failed: \(jsonString.prefix(1000))")
            }
        }
    }

    private func processServerMessage(_ message: CLIServerMessage) async {
        switch message {
        case .connected(let payload):
            handleConnected(payload)

        case .stream(let streamMessage):
            handleStreamMessage(streamMessage.message)

        case .permission(let request):
            handlePermissionRequest(request)

        case .question(let request):
            handleQuestionRequest(request)

        case .sessionEvent(let event):
            onSessionEvent?(event)

        case .history(let payload):
            onHistory?(payload)

        case .modelChanged(let payload):
            currentModel = payload.model
            onModelChanged?(payload.model)

        case .permissionModeChanged(let payload):
            log.debug("Permission mode changed to: \(payload.mode)")
            onPermissionModeChanged?(payload.mode)

        case .queued(let payload):
            isInputQueued = true
            queuePosition = payload.position

        case .queueCleared:
            isInputQueued = false
            queuePosition = 0

        case .error(let payload):
            handleError(payload)

        case .pong:
            // Keepalive response - no action needed
            log.debug("Received pong from server")

        // Top-level control messages (not inside stream)
        case .stopped(let payload):
            agentState = .idle
            flushTextBuffer()
            onStopped?(payload.reason)

        case .interrupted:
            agentState = .idle
            flushTextBuffer()
            onStopped?("interrupted")
        }
    }

    private func handleConnected(_ payload: CLIConnectedPayload) {
        currentAgentId = payload.agentId
        sessionId = payload.sessionId
        currentModel = payload.model
        protocolVersion = payload.protocolVersion
        connectionState = .connected(agentId: payload.agentId)
        agentState = .idle

        onSessionConnected?(payload.sessionId)
        log.info("Connected to cli-bridge: agent=\(payload.agentId), session=\(payload.sessionId), model=\(payload.model)")
    }

    private func handleStreamMessage(_ content: CLIStreamContent) {
        switch content {
        case .assistant(let assistantContent):
            // Note: assistant messages don't have 'id' in cli-bridge
            appendText(assistantContent.content, isFinal: assistantContent.isFinal)

        case .user:
            // User message echo - ignore (we already have it locally)
            break

        case .system:
            // System messages - could log or display as system info
            break

        case .thinking(let thinkingContent):
            onThinking?(thinkingContent.content)

        case .toolUse(let toolContent):
            lastMessageId = toolContent.id
            agentState = .executing
            toolProgress = nil
            let input = toolContent.input.mapValues { $0.value }
            onToolStart?(toolContent.id, toolContent.name, input)

        case .toolResult(let resultContent):
            lastMessageId = resultContent.id
            agentState = .thinking
            toolProgress = nil
            onToolResult?(resultContent.id, resultContent.tool, resultContent.output, resultContent.success)

        case .progress(let progressContent):
            // Only update progress if NOT waiting for user input or permission approval
            // (server continues sending progress while waiting, but we want to hide the banner)
            if agentState != .waitingInput && agentState != .waitingPermission {
                toolProgress = progressContent
            }

        case .usage(let usageContent):
            tokenUsage = usageContent

        case .state(let stateContent):
            agentState = stateContent.state

        case .subagentStart(let subagentContent):
            activeSubagent = subagentContent
            onSubagentStart?(subagentContent)

        case .subagentComplete(let subagentContent):
            activeSubagent = nil
            onSubagentComplete?(subagentContent)

        case .question(let request):
            // Question came via stream wrapper - handle same as top-level
            handleQuestionRequest(request)

        case .permission(let request):
            // Permission came via stream wrapper - handle same as top-level
            handlePermissionRequest(request)
        }
    }

    private func handlePermissionRequest(_ request: CLIPermissionRequest) {
        pendingPermission = request
        agentState = .waitingPermission
        toolProgress = nil  // Clear progress - tool is waiting for approval, not running
        onPermissionRequest?(request)
    }

    private func handleQuestionRequest(_ request: CLIQuestionRequest) {
        pendingQuestion = request
        agentState = .waitingInput
        toolProgress = nil  // Clear progress - tool is waiting for input, not running
        onQuestionRequest?(request)
    }

    private func handleError(_ payload: CLIErrorPayload) {
        lastError = payload.message
        onError?(payload)

        // Create typed connection error
        let connectionError = ConnectionError.from(payload)

        // Handle specific error codes
        if let code = payload.errorCode {
            switch code {
            case .connectionReplaced:
                log.warning("[CLIBridge] Connection replaced by another client")
                onConnectionReplaced?()
                onConnectionError?(connectionError)
                // Don't auto-reconnect - let user decide
                disconnect(preserveSession: true)

            case .agentNotFound:
                log.info("[CLIBridge] Agent not found (timed out), can reconnect with sessionId")
                currentAgentId = nil
                agentState = .stopped
                onConnectionError?(connectionError)
                // Agent timed out but session still exists on disk
                // User can reconnect with same sessionId to continue

            case .sessionNotFound, .sessionInvalid:
                // Session is gone or corrupted, reset everything
                log.warning("[CLIBridge] Session not found or invalid")
                currentAgentId = nil
                sessionId = nil
                pendingSessionId = nil
                agentState = .stopped
                onConnectionError?(connectionError)

            case .rateLimited:
                log.warning("[CLIBridge] Rate limited, retry after \(payload.retryAfter ?? 60)s")
                onConnectionError?(connectionError)
                // Schedule retry if we have a session
                if let retryAfter = payload.retryAfter {
                    scheduleRetry(after: TimeInterval(retryAfter))
                }

            case .maxAgentsReached:
                log.warning("[CLIBridge] Server at capacity")
                onConnectionError?(connectionError)

            case .queueFull:
                isInputQueued = false
                onConnectionError?(connectionError)

            default:
                onConnectionError?(connectionError)
            }
        }
    }

    private func scheduleRetry(after seconds: TimeInterval) {
        reconnectTask?.cancel()
        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            reconnectWithExistingSession()
        }
    }

    private func handleDisconnect(error: Error) async {
        // Don't handle if already disconnected or manual disconnect
        guard connectionState.isConnected || connectionState.isConnecting else { return }
        guard !isManualDisconnect else {
            log.debug("[CLIBridge] Manual disconnect, not reconnecting")
            return
        }

        log.warning("[CLIBridge] Disconnected unexpectedly: \(error.localizedDescription)")
        connectionState = .disconnected

        // Update agent state if it was processing
        if agentState != .stopped && agentState != .idle {
            agentState = .recovering
        }

        webSocket = nil

        // Check network availability
        guard isNetworkAvailable else {
            log.debug("[CLIBridge] No network, will reconnect when restored")
            onConnectionError?(.networkUnavailable)
            return
        }

        // Attempt reconnection if we have a session
        if sessionId != nil || pendingSessionId != nil {
            if reconnectAttempt < maxReconnectAttempts {
                await attemptReconnect()
            } else {
                log.error("[CLIBridge] Max reconnection attempts reached")
                agentState = .stopped
                onConnectionError?(.reconnectFailed)
            }
        }
    }

    private func attemptReconnect() async {
        reconnectAttempt += 1
        connectionState = .reconnecting(attempt: reconnectAttempt)

        // Exponential backoff: 1s, 2s, 4s, 8s, 16s (capped at 16s)
        let baseDelay = pow(2.0, Double(reconnectAttempt - 1))
        let jitter = Double.random(in: 0...0.5)
        let delay = min(baseDelay + jitter, 16.0)

        log.info("[CLIBridge] Reconnecting in \(String(format: "%.1f", delay))s (attempt \(reconnectAttempt)/\(maxReconnectAttempts))")

        // Notify delegate
        onReconnecting?(reconnectAttempt, delay)

        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            guard !Task.isCancelled else { return }

            // Reconnect with existing session
            reconnectWithExistingSession()
        }
    }

    // MARK: - Text Buffering

    private func appendText(_ text: String, isFinal: Bool) {
        if isFinal {
            // cli-bridge sends delta=false with the COMPLETE accumulated text (not a delta)
            // Clear buffer since the final message has the complete text
            textBuffer = ""
            textFlushTask?.cancel()
            textFlushTask = nil
            currentText = text  // SET to complete text (replaces any accumulated text)
            onText?(text, true)
        } else {
            // Delta message - append to buffer for UI display
            textBuffer += text

            // Debounce UI updates
            textFlushTask?.cancel()
            textFlushTask = Task {
                try? await Task.sleep(nanoseconds: textFlushDelay)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.flushTextBuffer()
                }
            }
            onText?(text, false)
        }
    }

    private func flushTextBuffer() {
        guard !textBuffer.isEmpty else { return }
        currentText += textBuffer
        textBuffer = ""
        textFlushTask?.cancel()
        textFlushTask = nil
    }

    /// Clear accumulated text (call when starting new message)
    func clearCurrentText() {
        currentText = ""
        textBuffer = ""
    }
}

// MARK: - Errors

enum CLIBridgeError: LocalizedError {
    case notConnected
    case invalidURL
    case encodingError
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to server"
        case .invalidURL:
            return "Invalid server URL"
        case .encodingError:
            return "Failed to encode message"
        case .serverError(let message):
            return message
        }
    }
}

// Note: Uses global 'log' from Logger.swift
