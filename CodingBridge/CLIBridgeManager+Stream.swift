import Foundation

// MARK: - Stream Handling
// WebSocket message receiving, parsing, and event dispatch

extension CLIBridgeManager {
    // MARK: - Receive Loop

    func startReceiveLoop(connectionId: UUID) {
        Task { [weak self] in
            guard let self = self else { return }

            while self.isCurrentConnection(connectionId) {
                do {
                    guard let message = try await self.receiveFromWebSocket() else {
                        break
                    }

                    // Ensure we're still on the same connection
                    guard self.isCurrentConnection(connectionId) else { break }

                    await self.handleMessage(message)
                } catch {
                    // Check if this is our current connection
                    guard self.isCurrentConnection(connectionId) else { break }

                    // Only log errors for unexpected disconnects
                    // Manual disconnects will naturally throw "Socket is not connected"
                    if !self.getIsManualDisconnect() {
                        log.error("WebSocket receive error: \(error)")
                        await self.handleDisconnect(error: error)
                    }
                    break
                }
            }
        }
    }

    // MARK: - Message Handling

    func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
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
            log.debug("[WS] <- Received: \(jsonString.prefix(500))")
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

    static func makeServerMessageDecoder() -> JSONDecoder {
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

    // MARK: - Server Message Processing

    func processServerMessage(_ message: ServerMessage) async {
        switch message {
        case .typeConnectedMessage(let payload):
            handleConnected(payload)

        case .typeStreamServerMessage(let streamMessage):
            // Convert to unified CLIStoredMessage format and track ID
            let stored = streamMessage.toStoredMessage()
            setLastMessageId(stored.idString)
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
            resetReconnectAttempt()  // Reset on successful reconnect
            emit(.reconnectComplete(payload))
        }
    }

    // MARK: - Stream Message Handling

    func handleStreamMessage(_ stored: CLIStoredMessage) {
        let idString = stored.idString

        // History hardening: Deduplication - skip if we've already processed this message
        if hasReceivedMessage(idString) {
            log.debug("[CLIBridge] Skipping duplicate message: \(idString)")
            return
        }

        // Add to deduplication set (with size limit)
        addReceivedMessage(idString)

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
            setLastMessageId(toolContent.id)
            agentState = .executing
            toolProgress = nil
            emit(.toolStart(id: toolContent.id, name: toolContent.name, input: toolContent.input))

        case .typeToolResultStreamMessage(let resultContent):
            setLastMessageId(resultContent.id)
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

    // MARK: - Specific Message Handlers

    func handleConnected(_ payload: ConnectedMessage) {
        let sessionIdStr = payload.sessionId.uuidString
        let modelValue = payload.modelAlias ?? payload.model
        setCurrentAgentId(payload.agentId)
        sessionId = sessionIdStr
        currentModel = modelValue
        protocolVersion = payload.protocolVersion.rawValue
        connectionState = .connected(agentId: payload.agentId)
        agentState = .idle

        // History hardening: Load persisted lastMessageId for this session
        let loadedMessageId = loadLastMessageId(for: sessionIdStr)
        if let loadedId = loadedMessageId {
            setLastMessageId(loadedId)
            log.debug("[CLIBridge] Loaded lastMessageId: \(loadedId)")
        }

        emit(.connected(sessionId: sessionIdStr, agentId: payload.agentId, model: modelValue))
        log.info("Connected to cli-bridge: agent=\(payload.agentId), session=\(sessionIdStr), model=\(modelValue)")
    }

    func handlePermissionRequest(_ request: PermissionRequestMessage) {
        pendingPermission = request
        agentState = .waitingPermission
        toolProgress = nil  // Clear progress - tool is waiting for approval, not running
        emit(.permissionRequest(request))
    }

    func handleQuestionRequest(_ request: QuestionMessage) {
        pendingQuestion = request
        agentState = .waitingInput
        toolProgress = nil  // Clear progress - tool is waiting for input, not running
        emit(.questionRequest(request))
    }

    func handleError(_ payload: WsErrorMessage) {
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
                clearCurrentAgentId()
                agentState = .stopped
                emit(.connectionError(connectionError))
                // Agent timed out but session still exists on disk
                // User can reconnect with same sessionId to continue

            case .sessionNotFound, .sessionInvalid:
                // Session is gone or corrupted, reset everything
                log.warning("[CLIBridge] Session not found or invalid")
                clearCurrentAgentId()
                sessionId = nil
                clearPendingSessionId()
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

    // MARK: - Pong Response

    /// Send pong response to server ping for keepalive
    func sendPong() {
        Task {
            guard hasActiveWebSocket else { return }
            do {
                try await sendRawString("{\"type\":\"pong\"}")
                log.debug("[WS] -> Sent pong")
            } catch {
                log.error("[WS] Failed to send pong: \(error)")
            }
        }
    }

    // MARK: - Text Handling

    /// Process assistant text message
    /// Note: cli-bridge server filters deltas, so we only receive complete messages (delta=false)
    func appendText(_ text: String, isFinal: Bool) {
        // Server sends complete text (delta=false), just set it directly
        currentText = text
        emit(.text(text, isFinal: isFinal))
    }
}
