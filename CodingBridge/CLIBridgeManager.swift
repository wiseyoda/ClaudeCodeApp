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

    /// Unified event callback - emits all stream events
    var onEvent: ((StreamEvent) -> Void)?

    // MARK: - Internal State (accessible to extensions)

    private(set) var webSocket: WebSocketTasking?
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

    // MARK: - Internal Accessors for Extensions

    // WebSocket
    var hasActiveWebSocket: Bool { webSocket != nil }

    func createWebSocket(with url: URL) {
        webSocket = webSocketSession.makeWebSocketTask(with: url)
        webSocket?.resume()
    }

    func closeWebSocket() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }

    func clearWebSocket() {
        webSocket = nil
    }

    func receiveFromWebSocket() async throws -> URLSessionWebSocketTask.Message? {
        try await webSocket?.receive()
    }

    func sendRawString(_ string: String) async throws {
        try await webSocket?.send(.string(string))
    }

    // Connection ID
    func isCurrentConnection(_ id: UUID) -> Bool {
        connectionId == id
    }

    func resetConnectionId() -> UUID {
        let newId = UUID()
        connectionId = newId
        return newId
    }

    // Reconnect state
    func getReconnectAttempt() -> Int { reconnectAttempt }
    func resetReconnectAttempt() { reconnectAttempt = 0 }
    func incrementReconnectAttempt() { reconnectAttempt += 1 }
    func getMaxReconnectAttempts() -> Int { maxReconnectAttempts }

    func cancelReconnectTask() {
        reconnectTask?.cancel()
        reconnectTask = nil
    }

    func setReconnectTask(_ task: Task<Void, Never>) {
        reconnectTask = task
    }

    func scheduleReconnectTask(delay: TimeInterval) {
        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            reconnectWithExistingSession()
        }
    }

    // Manual disconnect flag
    func getIsManualDisconnect() -> Bool { isManualDisconnect }
    func setIsManualDisconnect(_ value: Bool) { isManualDisconnect = value }

    // Pending connection
    func getPendingProjectPath() -> String? { pendingProjectPath }
    func getPendingSessionId() -> String? { pendingSessionId }
    func getPendingModel() -> String? { pendingModel }
    func getPendingHelper() -> Bool { pendingHelper }
    func clearPendingSessionId() { pendingSessionId = nil }

    func storePendingConnection(projectPath: String, sessionId: String?, model: String?, helper: Bool) {
        pendingProjectPath = projectPath
        pendingSessionId = sessionId
        pendingModel = model
        pendingHelper = helper
    }

    // Agent ID
    func setCurrentAgentId(_ id: String) { currentAgentId = id }
    func clearCurrentAgentId() { currentAgentId = nil }

    // Network availability
    func getIsNetworkAvailable() -> Bool { isNetworkAvailable }
    func setIsNetworkAvailable(_ value: Bool) { isNetworkAvailable = value }

    // Lifecycle observers
    func appendLifecycleObserver(_ observer: NSObjectProtocol) {
        lifecycleObservers.append(observer)
    }

    // Network monitor
    func initializeNetworkMonitor() {
        networkMonitor = NWPathMonitor()
    }

    func setNetworkPathUpdateHandler(_ handler: @escaping (NWPath) -> Void) {
        networkMonitor?.pathUpdateHandler = handler
    }

    func startNetworkMonitor() {
        networkMonitor?.start(queue: networkQueue)
    }

    // Background task
    func beginBackgroundTask(expirationHandler: @escaping () -> Void) {
        backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: expirationHandler)
    }

    func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    // Last message ID
    func getLastMessageId() -> String? { lastMessageId }
    func setLastMessageId(_ id: String) { lastMessageId = id }

    // LastMessageId persistence
    func persistLastMessageId(_ id: String) {
        guard let session = sessionId else { return }
        let key = Self.lastMessageIdPrefix + session
        UserDefaults.standard.set(id, forKey: key)
        lastMessageId = id
    }

    func loadLastMessageId(for session: String) -> String? {
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

    // Callbacks
    func clearCallbacks() {
        onEvent = nil
    }

    // MARK: - URL Building

    func buildWebSocketURL() -> URL? {
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

    // MARK: - Message Sending (Internal)

    func send(_ message: ClientMessage) async throws {
        guard let webSocket = webSocket else {
            throw CLIBridgeError.notConnected
        }

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)

        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw CLIBridgeError.encodingError
        }

        log.debug("[WS] -> Sending: \(jsonString.prefix(500))")
        try await webSocket.send(.string(jsonString))
    }

    // MARK: - Event Emission

    /// Emit a StreamEvent to the unified callback
    @inline(__always)
    func emit(_ event: StreamEvent) {
        onEvent?(event)
    }

    // MARK: - Testable Methods (can be overridden in test subclasses)
    // These methods are defined here rather than in extensions to allow override in tests

    /// Connect to cli-bridge - implementation in CLIBridgeManager+Connection.swift
    func connect(
        projectPath: String,
        sessionId: String? = nil,
        model: String? = nil,
        helper: Bool = false
    ) async {
        await connectImpl(projectPath: projectPath, sessionId: sessionId, model: model, helper: helper)
    }

    /// Disconnect from cli-bridge - implementation in CLIBridgeManager+Connection.swift
    func disconnect(preserveSession: Bool = false) {
        disconnectImpl(preserveSession: preserveSession)
    }

    /// Send input message - implementation in CLIBridgeManager+Messages.swift
    func sendInput(_ text: String, images: [CLIImageAttachment]? = nil, thinkingMode: String? = nil) async throws {
        try await sendInputImpl(text, images: images, thinkingMode: thinkingMode)
    }

    /// Set model - implementation in CLIBridgeManager+Messages.swift
    func setModel(_ model: String) async throws {
        try await setModelImpl(model)
    }

    /// Interrupt current operation - implementation in CLIBridgeManager+Messages.swift
    func interrupt() async throws {
        try await interruptImpl()
    }

    /// Respond to permission request - implementation in CLIBridgeManager+Messages.swift
    func respondToPermission(id: String, choice: CLIPermissionChoice) async throws {
        try await respondToPermissionImpl(id: id, choice: choice)
    }

    /// Respond to question - implementation in CLIBridgeManager+Messages.swift
    func respondToQuestion(id: String, answers: [String: Any]) async throws {
        try await respondToQuestionImpl(id: id, answers: answers)
    }
}

// MARK: - DEBUG Test Helpers

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
