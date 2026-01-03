import Foundation

// MARK: - Connection Management
// Connect, reconnect, disconnect, and reconnection logic

extension CLIBridgeManager {
    // MARK: - Connection Management

    /// Connect implementation - called from main class
    func connectImpl(
        projectPath: String,
        sessionId: String? = nil,
        model: String? = nil,
        helper: Bool = false
    ) async {
        guard !connectionState.isConnected && !connectionState.isConnecting else {
            log.debug("Already connected or connecting")
            return
        }

        clearBackgroundDisconnecting()
        // Check network availability
        guard getIsNetworkAvailable() else {
            log.warning("[CLIBridge] No network available")
            lastError = "No network connection"
            emit(.connectionError(.networkUnavailable))
            return
        }

        // Reset manual disconnect flag
        setIsManualDisconnect(false)

        // Store for reconnection
        storePendingConnection(projectPath: projectPath, sessionId: sessionId, model: model, helper: helper)

        connectionState = .connecting
        agentState = .starting
        lastError = nil

        // Build WebSocket URL
        guard let wsURL = buildWebSocketURL() else {
            lastError = "Invalid server URL"
            connectionState = .disconnected
            agentState = .stopped
            clearPendingConnection()
            emit(.connectionError(.invalidServerURL))
            return
        }

        // Create WebSocket connection
        createWebSocket(with: wsURL)

        // Start receive loop
        let currentConnectionId = resetConnectionId()
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
            resetReconnectAttempt()
        } catch {
            log.error("Failed to send start message: \(error)")
            lastError = error.localizedDescription
            connectionState = .disconnected
            agentState = .stopped
            clearPendingConnection()
            closeWebSocket()
            emit(.connectionError(.connectionFailed(error.localizedDescription)))
        }
    }

    /// Reconnect to an existing agent with history recovery
    /// Sends lastMessageId so server can replay any missed messages
    func reconnect(agentId: String, lastMessageId: String? = nil) async {
        guard !connectionState.isConnected else {
            log.debug("Already connected")
            return
        }

        connectionState = .reconnecting(attempt: getReconnectAttempt() + 1)

        guard let wsURL = buildWebSocketURL() else {
            lastError = "Invalid server URL"
            connectionState = .disconnected
            return
        }

        createWebSocket(with: wsURL)

        let currentConnectionId = resetConnectionId()
        startReceiveLoop(connectionId: currentConnectionId)

        // Send reconnect message with lastMessageId for history recovery
        // Server will replay any messages missed since lastMessageId
        let messageId = lastMessageId ?? getLastMessageId()
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

    /// Disconnect implementation - called from main class
    /// - Parameter preserveSession: If true, keeps sessionId for reconnection (default: false)
    func disconnectImpl(preserveSession: Bool = false) {
        setIsManualDisconnect(true)
        clearBackgroundDisconnecting()
        HealthMonitorService.shared.setWebSocketActive(false)

        cancelReconnectTask()
        closeWebSocket()

        connectionState = .disconnected
        agentState = .stopped
        clearCurrentAgentId()

        if !preserveSession {
            sessionId = nil
            clearPendingSessionId()
        }

        resetStreamingText()
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

        setIsManualDisconnect(false)  // Allow auto-reconnect
        markBackgroundDisconnecting()
        HealthMonitorService.shared.setWebSocketActive(false)

        cancelReconnectTask()
        closeWebSocket()

        // Preserve session info but update state
        connectionState = .disconnected
        // Don't change agent state - it may still be running on server
    }

    // MARK: - Reconnection Logic

    func reconnectWithExistingSession() {
        guard let projectPath = getPendingProjectPath() else { return }

        Task {
            await connect(
                projectPath: projectPath,
                sessionId: sessionId ?? getPendingSessionId(),
                model: getPendingModel(),
                helper: getPendingHelper()
            )
        }
    }

    func handleDisconnect(error: Error) async {
        // Don't handle if already disconnected or manual disconnect
        guard connectionState.isConnected || connectionState.isConnecting else { return }
        guard !getIsManualDisconnect() else {
            log.debug("[CLIBridge] Manual disconnect, not reconnecting")
            return
        }

        HealthMonitorService.shared.setWebSocketActive(false)
        clearBackgroundDisconnecting()
        log.warning("[CLIBridge] Disconnected unexpectedly: \(error.localizedDescription)")
        connectionState = .disconnected

        // Update agent state if it was processing
        if agentState != .stopped && agentState != .idle {
            agentState = .recovering
        }

        clearWebSocket()

        // Check network availability
        guard getIsNetworkAvailable() else {
            log.debug("[CLIBridge] No network, will reconnect when restored")
            emit(.connectionError(.networkUnavailable))
            return
        }

        // Attempt reconnection if we have a session
        if sessionId != nil || getPendingSessionId() != nil {
            if getReconnectAttempt() < getMaxReconnectAttempts() {
                await attemptReconnect()
            } else {
                log.error("[CLIBridge] Max reconnection attempts reached")
                agentState = .stopped
                emit(.connectionError(.reconnectFailed))
            }
        }
    }

    func attemptReconnect() async {
        incrementReconnectAttempt()
        let attempt = getReconnectAttempt()
        connectionState = .reconnecting(attempt: attempt)

        // Exponential backoff: 1s, 2s, 4s, 8s, 16s (capped at 16s)
        let baseDelay = pow(2.0, Double(attempt - 1))
        let jitter = Double.random(in: 0...0.5)
        let delay = min(baseDelay + jitter, 16.0)

        log.info("[CLIBridge] Reconnecting in \(String(format: "%.1f", delay))s (attempt \(attempt)/\(getMaxReconnectAttempts()))")

        // Notify delegate
        emit(.reconnecting(attempt: attempt, delay: delay))

        scheduleReconnectTask(delay: delay)
    }

    func scheduleRetry(after seconds: TimeInterval) {
        cancelReconnectTask()
        setReconnectTask(Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            reconnectWithExistingSession()
        })
    }
}
