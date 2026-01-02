import Foundation
import Network
import UIKit

protocol WebSocketTasking: AnyObject {
    func resume()
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
    func send(_ message: URLSessionWebSocketTask.Message) async throws
    func receive() async throws -> URLSessionWebSocketTask.Message
}

protocol WebSocketSessioning {
    func makeWebSocketTask(with url: URL) -> WebSocketTasking
}

extension URLSessionWebSocketTask: WebSocketTasking {}

extension URLSession: WebSocketSessioning {
    func makeWebSocketTask(with url: URL) -> WebSocketTasking {
        webSocketTask(with: url)
    }
}

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

    var accessibilityLabel: String {
        switch self {
        case .disconnected: return "Disconnected from server"
        case .connecting: return "Connecting to server"
        case .connected: return "Connected to server"
        case .reconnecting(let attempt): return "Reconnecting, attempt \(attempt)"
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
    @Published var currentTool: String?  // Tool name when agentState is .executing
    @Published var sessionId: String?
    @Published var currentModel: String?
    @Published var protocolVersion: String?

    /// Current streaming text (accumulates during response)
    @Published var currentText: String = ""

    /// Token usage for current session
    @Published var tokenUsage: UsageStreamMessage?

    /// Last error message
    @Published var lastError: String?

    /// Current pending permission request
    @Published var pendingPermission: PermissionRequestMessage?

    /// Current pending question
    @Published var pendingQuestion: QuestionMessage?

    /// Input is queued (sent while agent was busy)
    @Published var isInputQueued: Bool = false
    @Published var queuePosition: Int = 0

    /// Active subagent (if any)
    @Published var activeSubagent: SubagentStartStreamMessage?

    /// Progress for long-running tool
    @Published var toolProgress: ProgressStreamMessage?

    // MARK: - Unified Event Callback
    //
    // Single callback that emits all stream events via StreamEvent enum.
    // Consumers switch on StreamEvent cases.

    /// Unified event callback - emits all stream events
    var onEvent: ((StreamEvent) -> Void)?

    // MARK: - Private State

    private var webSocket: WebSocketTasking?
    private var serverURL: String
    private let webSocketSession: WebSocketSessioning
    private var reconnectAttempt = 0
    private var reconnectTask: Task<Void, Never>?
    private let maxReconnectAttempts = 5
    private var lastMessageId: String?
    private var currentAgentId: String?

    /// Track receive loop to detect stale callbacks
    private var connectionId = UUID()

    /// Track if disconnect was intentional (user-initiated)
    private var isManualDisconnect = false

    /// Pending connection parameters for reconnection
    private var pendingProjectPath: String?
    private var pendingSessionId: String?
    private var pendingModel: String?
    private var pendingHelper: Bool = false

    // MARK: - History Hardening: Message Deduplication

    /// Set of received message IDs for deduplication (prevents duplicate processing on reconnect)
    /// Cap at 1000 entries to limit memory usage, evicting oldest on overflow
    private var receivedMessageIds: Set<String> = []
    private let maxDeduplicationEntries = 1000

    /// UserDefaults key prefix for lastMessageId persistence
    private static let lastMessageIdPrefix = "cli_bridge_last_message_"

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

    // MARK: - Initialization

    init(serverURL: String = "", webSocketSession: WebSocketSessioning = URLSession(configuration: .default)) {
        self.serverURL = serverURL
        self.webSocketSession = webSocketSession
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
                    self.emit(.networkStatusChanged(isOnline: self.isNetworkAvailable))

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
            emit(.connectionError(.networkUnavailable))
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
            emit(.connectionError(.invalidServerURL))
            return
        }

        // Create WebSocket connection
        webSocket = webSocketSession.makeWebSocketTask(with: wsURL)
        webSocket?.resume()

        // Start receive loop
        let currentConnectionId = UUID()
        self.connectionId = currentConnectionId
        startReceiveLoop(connectionId: currentConnectionId)

        // Send start message
        let startPayload = StartMessage(
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

    /// Reconnect to an existing agent with history recovery
    /// Sends lastMessageId so server can replay any missed messages
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

        webSocket = webSocketSession.makeWebSocketTask(with: wsURL)
        webSocket?.resume()

        let currentConnectionId = UUID()
        self.connectionId = currentConnectionId
        startReceiveLoop(connectionId: currentConnectionId)

        // Send reconnect message with lastMessageId for history recovery
        // Server will replay any messages missed since lastMessageId
        let messageId = lastMessageId ?? self.lastMessageId
        let reconnectPayload = ReconnectMessage(agentId: agentId, lastMessageId: messageId)

        do {
            try await send(.reconnect(reconnectPayload))
            log.info("[CLIBridge] Reconnecting to agent \(agentId) with lastMessageId: \(messageId ?? "none")")
        } catch {
            log.error("Failed to send reconnect message: \(error)")
            lastError = error.localizedDescription
            connectionState = .disconnected
        }
    }

    /// Disconnect from the server
    /// - Parameter preserveSession: If true, keeps sessionId for reconnection (default: false)
    func disconnect(preserveSession: Bool = false) {
        isManualDisconnect = true

        reconnectTask?.cancel()
        reconnectTask = nil

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

        // Clear callbacks to break potential retain cycles
        clearCallbacks()

        log.debug("[CLIBridge] Disconnected (preserveSession: \(preserveSession))")
    }

    /// Clear all callbacks to prevent retain cycles
    private func clearCallbacks() {
        onEvent = nil
    }

    /// Disconnect but preserve session for later reconnection
    /// Use this when going to background or network drops
    func disconnectForBackground() {
        log.debug("[CLIBridge] Disconnecting for background, preserving session")

        isManualDisconnect = false  // Allow auto-reconnect

        reconnectTask?.cancel()
        reconnectTask = nil

        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil

        // Preserve session info but update state
        connectionState = .disconnected
        // Don't change agent state - it may still be running on server
    }

    // MARK: - Message Sending

    /// Send user input to the agent
    func sendInput(_ text: String, images: [APIImageAttachment]? = nil, thinkingMode: String? = nil) async throws {
        let payload = InputMessage(text: text, images: images, thinkingMode: thinkingMode)
        try await send(.input(payload))
        if agentState == .idle {
            agentState = .thinking
        }
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
    func respondToPermission(id: String, choice: PermissionResponseMessage.Choice) async throws {
        let payload = PermissionResponseMessage(id: id, choice: choice)
        try await send(.permissionResponse(payload))
        pendingPermission = nil
    }

    /// Respond to a question
    func respondToQuestion(id: String, answers: [String: Any]) async throws {
        let payload = QuestionResponseMessage(
            id: id,
            answers: answers.mapValues { QuestionResponseMessageAnswersValue(AnyCodableValue($0)) }
        )
        try await send(.questionResponse(payload))
        pendingQuestion = nil
    }

    /// Subscribe to session events for a project
    func subscribeToSessions(projectPath: String? = nil) async throws {
        let payload = SubscribeSessionsMessage(projectPath: projectPath)
        try await send(.subscribeSessions(payload))
    }

    /// Change the model mid-session
    func setModel(_ model: String) async throws {
        try await send(.setModel(SetModelMessage(model: model)))
    }

    /// Set permission mode for the agent
    /// - Parameter mode: "default", "acceptEdits", or "bypassPermissions"
    func setPermissionMode(_ mode: SetPermissionModeMessage.Mode) async throws {
        try await send(.setPermissionMode(SetPermissionModeMessage(mode: mode)))
    }

    /// Cancel queued input
    func cancelQueuedInput() async throws {
        try await send(.cancelQueued)
    }

    /// Retry a failed message
    func retry(messageId: String) async throws {
        let payload = RetryMessage(messageId: messageId)
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

    private func send(_ message: ClientMessage) async throws {
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

                    // Only log errors for unexpected disconnects
                    // Manual disconnects will naturally throw "Socket is not connected"
                    if !self.isManualDisconnect {
                        log.error("WebSocket receive error: \(error)")
                        await self.handleDisconnect(error: error)
                    }
                    break
                }
            }
        }
    }

    private static func makeServerMessageDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let dateString = try? container.decode(String.self),
               let date = CLIDateFormatter.parseDate(dateString) {
                return date
            }
            if let timeInterval = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timeInterval)
            }
            if let timeInterval = try? container.decode(Int.self) {
                return Date(timeIntervalSince1970: Double(timeInterval))
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format"
            )
        }
        return decoder
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
            let decoder = Self.makeServerMessageDecoder()
            let serverMessage = try decoder.decode(ServerMessage.self, from: data)
            await processServerMessage(serverMessage)
        } catch {
            log.error("[WS] Failed to decode server message: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                log.error("[WS] Raw message that failed: \(jsonString.prefix(1000))")
            }
        }
    }

    /// Send pong response to server ping for keepalive
    private func sendPong() {
        Task {
            guard let webSocket = webSocket else { return }
            do {
                try await webSocket.send(.string("{\"type\":\"pong\"}"))
                log.debug("[WS] → Sent pong")
            } catch {
                log.error("[WS] Failed to send pong: \(error)")
            }
        }
    }

    private func processServerMessage(_ message: ServerMessage) async {
        switch message {
        case .typeConnectedMessage(let payload):
            handleConnected(payload)

        case .typeStreamServerMessage(let streamMessage):
            // Convert to unified CLIStoredMessage format and track ID
            let stored = streamMessage.toStoredMessage()
            lastMessageId = stored.idString
            handleStreamMessage(stored)

        case .typePermissionRequestMessage(let request):
            handlePermissionRequest(request)

        case .typeQuestionMessage(let request):
            handleQuestionRequest(request)

        case .typeSessionEventMessage(let event):
            emit(.sessionEvent(event))

        case .typeHistoryMessage(let payload):
            emit(.history(payload))

        case .typeModelChangedMessage(let payload):
            currentModel = payload.model
            emit(.modelChanged(model: payload.model))

        case .typePermissionModeChangedMessage(let payload):
            log.debug("Permission mode changed to: \(payload.mode)")
            emit(.permissionModeChanged(mode: payload.mode.rawValue))

        case .typeQueuedMessage(let payload):
            isInputQueued = true
            queuePosition = payload.position
            emit(.inputQueued(position: payload.position))

        case .typeQueueClearedMessage:
            isInputQueued = false
            queuePosition = 0
            emit(.queueCleared)

        case .typeErrorMessage(let payload):
            handleError(WsErrorMessage(from: payload))

        case .typePongMessage:
            // Keepalive response - no action needed
            log.debug("Received pong from server")

        case .typeServerPingMessage:
            // Server ping - respond with pong for keepalive
            log.debug("Received ping from server (via ServerMessage)")
            sendPong()

        // Top-level control messages (not inside stream)
        case .typeStoppedMessage(let payload):
            agentState = .idle
            activeSubagent = nil  // Clear in case subagent_complete wasn't received
            toolProgress = nil
            emit(.stopped(reason: payload.reason.rawValue))

        case .typeInterruptedMessage:
            agentState = .idle
            activeSubagent = nil  // Clear in case subagent_complete wasn't received
            toolProgress = nil
            emit(.stopped(reason: "interrupted"))

        // History hardening: cursor/reconnect messages
        case .typeCursorEvictedMessage(let payload):
            log.warning("[CLIBridge] Cursor evicted, lastMessageId=\(payload.lastMessageId), recommendation=\(payload.recommendation)")
            emit(.cursorEvicted(payload))

        case .typeCursorInvalidMessage(let payload):
            log.warning("[CLIBridge] Invalid cursor, lastMessageId=\(payload.lastMessageId), recommendation=\(payload.recommendation)")
            emit(.cursorInvalid(payload))

        case .typeReconnectCompleteMessage(let payload):
            log.info("[CLIBridge] Reconnect complete: \(payload.missedCount) messages replayed from \(payload.fromMessageId)")
            reconnectAttempt = 0  // Reset on successful reconnect
            emit(.reconnectComplete(payload))
        }
    }

    private func handleConnected(_ payload: ConnectedMessage) {
        let sessionIdStr = payload.sessionId.uuidString
        currentAgentId = payload.agentId
        sessionId = sessionIdStr
        currentModel = payload.model
        protocolVersion = payload.protocolVersion.rawValue
        connectionState = .connected(agentId: payload.agentId)
        agentState = .idle

        // History hardening: Load persisted lastMessageId for this session
        lastMessageId = loadLastMessageId(for: sessionIdStr)
        if lastMessageId != nil {
            log.debug("[CLIBridge] Loaded lastMessageId: \(lastMessageId!)")
        }

        emit(.connected(sessionId: sessionIdStr, agentId: payload.agentId, model: payload.model))
        log.info("Connected to cli-bridge: agent=\(payload.agentId), session=\(sessionIdStr), model=\(payload.model)")
    }

    // MARK: - History Hardening: LastMessageId Persistence

    /// Persist lastMessageId to UserDefaults for reconnection
    private func persistLastMessageId(_ id: String) {
        guard let session = sessionId else { return }
        let key = Self.lastMessageIdPrefix + session
        UserDefaults.standard.set(id, forKey: key)
        lastMessageId = id
    }

    /// Load lastMessageId from UserDefaults
    private func loadLastMessageId(for session: String) -> String? {
        let key = Self.lastMessageIdPrefix + session
        return UserDefaults.standard.string(forKey: key)
    }

    /// Clear persisted lastMessageId for a session
    func clearLastMessageId(for session: String? = nil) {
        let sessionToUse = session ?? sessionId
        guard let session = sessionToUse else { return }
        let key = Self.lastMessageIdPrefix + session
        UserDefaults.standard.removeObject(forKey: key)
        if session == sessionId {
            lastMessageId = nil
        }
    }

    /// Clear deduplication cache (call when starting new session)
    func clearDeduplicationCache() {
        receivedMessageIds.removeAll()
    }

    private func handleStreamMessage(_ stored: CLIStoredMessage) {
        let idString = stored.idString

        // History hardening: Deduplication - skip if we've already processed this message
        if receivedMessageIds.contains(idString) {
            log.debug("[CLIBridge] Skipping duplicate message: \(idString)")
            return
        }

        // Add to deduplication set (with size limit)
        if receivedMessageIds.count >= maxDeduplicationEntries {
            // Remove oldest entry (simple eviction - Set doesn't preserve order, so just remove one)
            if let first = receivedMessageIds.first {
                receivedMessageIds.remove(first)
            }
        }
        receivedMessageIds.insert(idString)

        // Persist lastMessageId for reconnection
        persistLastMessageId(idString)

        log.debug("[CLIBridge] Processing stream message type: \(String(describing: stored.message))")

        switch stored.message {
        case .typeAssistantStreamMessage(let assistantContent):
            log.debug("[CLIBridge] Assistant message: isFinal=\(assistantContent.isFinal), content=\(assistantContent.content.prefix(100))")
            appendText(assistantContent.content, isFinal: assistantContent.isFinal)

        case .typeUserStreamMessage:
            // User message echo - ignore (we already have it locally)
            log.debug("[CLIBridge] User message echo - ignoring")
            break

        case .typeSystemStreamMessage(let systemContent):
            log.debug("[CLIBridge] System message: subtype=\(String(describing: systemContent.subtype))")
            // System messages with subtype "result" are displayable (e.g., greeting messages)
            if systemContent.subtype == SystemStreamMessage.Subtype.result {
                emit(.system(systemContent.content))
            }
            // "init" and "progress" subtypes are internal status updates - ignore

        case .typeThinkingStreamMessage(let thinkingContent):
            // Use thinking property for compatibility, fall back to content
            let content = thinkingContent.thinking ?? thinkingContent.content
            emit(.thinking(content))

        case .typeToolUseStreamMessage(let toolContent):
            lastMessageId = toolContent.id
            agentState = .executing
            toolProgress = nil
            let input = toolContent.input.mapValues { $0.value }
            emit(.toolStart(id: toolContent.id, name: toolContent.name, input: input))

        case .typeToolResultStreamMessage(let resultContent):
            lastMessageId = resultContent.id
            agentState = .thinking
            toolProgress = nil
            emit(.toolResult(id: resultContent.id, name: resultContent.tool, output: resultContent.output, isError: !resultContent.success))

        case .typeProgressStreamMessage(let progressContent):
            // Only update progress if NOT waiting for user input or permission approval
            // (server continues sending progress while waiting, but we want to hide the banner)
            if agentState != .waitingInput && agentState != .waitingPermission {
                toolProgress = progressContent
                emit(.progress(progressContent))
            }

        case .typeUsageStreamMessage(let usageContent):
            tokenUsage = usageContent
            emit(.usage(usageContent))

        case .typeStateStreamMessage(let stateContent):
            let newState = CLIAgentState(from: stateContent.state)
            // Skip duplicate state updates (cli-bridge may send idle twice at end of turn)
            if agentState == newState && currentTool == stateContent.tool {
                log.debug("[CLIBridge] Skipping duplicate state: \(stateContent.state)")
                return
            }
            agentState = newState
            currentTool = stateContent.tool  // Track tool name for StatusBubbleView
            emit(.stateChanged(newState))

        case .typeSubagentStartStreamMessage(let subagentContent):
            activeSubagent = subagentContent
            emit(.subagentStart(subagentContent))

        case .typeSubagentCompleteStreamMessage(let subagentContent):
            activeSubagent = nil
            emit(.subagentComplete(subagentContent))

        case .typeQuestionMessage(let request):
            // Question came via stream wrapper - handle same as top-level
            handleQuestionRequest(request)

        case .typePermissionRequestMessage(let request):
            // Permission came via stream wrapper - handle same as top-level
            handlePermissionRequest(request)
        }
    }

    private func handlePermissionRequest(_ request: PermissionRequestMessage) {
        pendingPermission = request
        agentState = .waitingPermission
        toolProgress = nil  // Clear progress - tool is waiting for approval, not running
        emit(.permissionRequest(request))
    }

    private func handleQuestionRequest(_ request: QuestionMessage) {
        pendingQuestion = request
        agentState = .waitingInput
        toolProgress = nil  // Clear progress - tool is waiting for input, not running
        emit(.questionRequest(request))
    }

    private func handleError(_ payload: WsErrorMessage) {
        lastError = payload.message
        emit(.error(payload))

        // Create typed connection error
        let connectionError = ConnectionError.from(payload)

        // Handle specific error codes
        if let code = payload.errorCode {
            switch code {
            case .connectionReplaced:
                log.warning("[CLIBridge] Connection replaced by another client")
                emit(.connectionReplaced)
                emit(.connectionError(connectionError))
                // Don't auto-reconnect - let user decide
                disconnect(preserveSession: true)

            case .agentNotFound:
                log.info("[CLIBridge] Agent not found (timed out), can reconnect with sessionId")
                currentAgentId = nil
                agentState = .stopped
                emit(.connectionError(connectionError))
                // Agent timed out but session still exists on disk
                // User can reconnect with same sessionId to continue

            case .sessionNotFound, .sessionInvalid:
                // Session is gone or corrupted, reset everything
                log.warning("[CLIBridge] Session not found or invalid")
                currentAgentId = nil
                sessionId = nil
                pendingSessionId = nil
                agentState = .stopped
                emit(.connectionError(connectionError))

            case .rateLimited:
                log.warning("[CLIBridge] Rate limited, retry after \(payload.retryAfter ?? 60)s")
                emit(.connectionError(connectionError))
                // Schedule retry if we have a session
                if let retryAfter = payload.retryAfter {
                    scheduleRetry(after: TimeInterval(retryAfter))
                }

            case .maxAgentsReached:
                log.warning("[CLIBridge] Server at capacity")
                emit(.connectionError(connectionError))

            case .queueFull:
                isInputQueued = false
                emit(.connectionError(connectionError))

            default:
                emit(.connectionError(connectionError))
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
            emit(.connectionError(.networkUnavailable))
            return
        }

        // Attempt reconnection if we have a session
        if sessionId != nil || pendingSessionId != nil {
            if reconnectAttempt < maxReconnectAttempts {
                await attemptReconnect()
            } else {
                log.error("[CLIBridge] Max reconnection attempts reached")
                agentState = .stopped
                emit(.connectionError(.reconnectFailed))
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
        emit(.reconnecting(attempt: reconnectAttempt, delay: delay))

        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            guard !Task.isCancelled else { return }

            // Reconnect with existing session
            reconnectWithExistingSession()
        }
    }

    // MARK: - Event Emission
    //
    // Helper to emit StreamEvent via unified callback

    /// Emit a StreamEvent to the unified callback
    @inline(__always)
    private func emit(_ event: StreamEvent) {
        onEvent?(event)
    }

    // MARK: - Text Handling

    /// Process assistant text message
    /// Note: cli-bridge server filters deltas, so we only receive complete messages (delta=false)
    private func appendText(_ text: String, isFinal: Bool) {
        // Server sends complete text (delta=false), just set it directly
        currentText = text
        emit(.text(text, isFinal: isFinal))
    }

    /// Clear current text (call when starting new message)
    func clearCurrentText() {
        currentText = ""
    }
}

#if DEBUG
extension CLIBridgeManager {
    func test_setWebSocket(_ socket: WebSocketTasking?) {
        webSocket = socket
    }

    func test_handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        await handleMessage(message)
    }

    func test_processServerMessage(_ message: ServerMessage) async {
        await processServerMessage(message)
    }

    func test_handleStreamMessage(_ stored: StoredMessage) {
        handleStreamMessage(stored.toCLIStoredMessage())
    }

    func test_handleStreamMessage(_ stored: CLIStoredMessage) {
        handleStreamMessage(stored)
    }

    func test_handleDisconnect(error: Error) async {
        await handleDisconnect(error: error)
    }

    func test_attemptReconnect() async {
        await attemptReconnect()
    }

    func test_reconnectWithExistingSession() {
        reconnectWithExistingSession()
    }

    func test_handleNetworkRestored() {
        handleNetworkRestored()
    }

    func test_setNetworkAvailable(_ available: Bool) {
        isNetworkAvailable = available
    }

    func test_setPendingConnection(projectPath: String?, sessionId: String?, model: String?, helper: Bool) {
        pendingProjectPath = projectPath
        pendingSessionId = sessionId
        pendingModel = model
        pendingHelper = helper
    }

    var test_reconnectAttempt: Int {
        get { reconnectAttempt }
        set { reconnectAttempt = newValue }
    }

    var test_isManualDisconnect: Bool {
        get { isManualDisconnect }
        set { isManualDisconnect = newValue }
    }
}
#endif

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
