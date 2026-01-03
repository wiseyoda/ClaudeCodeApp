import SwiftUI

/// Stream event handling extension for ChatViewModel
/// Handles all WebSocket events from CLIBridgeManager
extension ChatViewModel {
    // MARK: - Event Handler Setup

    /// Setup unified StreamEvent handler - replaces individual callbacks
    func setupStreamEventHandler() {
        manager.onEvent = { [weak self] event in
            guard let self = self else { return }
            self.handleStreamEvent(event)
        }
    }

    // MARK: - Main Event Handler

    /// Handle all stream events from CLIBridgeManager
    func handleStreamEvent(_ event: StreamEvent) {
        switch event {
        // MARK: Content Events
        case .text(let content, let isFinal):
            // Text is accumulated in manager.currentText
            if isFinal {
                // Capture committed text - message created in handleStopped with full metadata
                committedText = content
            }

        case .thinking(let content):
            let thinkingMsg = ChatMessage(
                role: .thinking,
                content: content,
                timestamp: Date()
            )
            messages.append(thinkingMsg)

        case .toolStart(_, let name, _, let input, let timestamp):
            // Filter tools from subagent execution (except Task itself which we show)
            if manager.activeSubagent != nil && name != "Task" {
                log.debug("[ChatViewModel] Filtering subagent tool: \(name)")
                return
            }

            // Flush any pending streaming text BEFORE appending tool message
            // This ensures correct ordering: assistant text -> tool -> tool result
            flushPendingStreamingText()

            // Always include JSON input for proper parsing by ToolParser
            // inputDescription is human-readable but ToolParser.extractParam needs JSON format
            let jsonInput = Self.toJSONString(input)
            let toolMsg = ChatMessage(
                role: .toolUse,
                content: "\(name)(\(jsonInput))",
                timestamp: timestamp
            )
            messages.append(toolMsg)
            refreshDisplayMessagesCache()

            if name == "TodoWrite" {
                let content = "\(name)(\(jsonInput))"
                if let todos = TodoListView.parseTodoContent(content), !todos.isEmpty {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        self.currentTodos = todos
                        self.showTodoDrawer = true
                    }
                }
            }

        case .toolResult(_, let tool, let output, _, let timestamp):
            let toolName = tool
            // Filter tool results from subagent execution and Task tool itself
            if manager.activeSubagent != nil && toolName != "Task" {
                log.debug("[ChatViewModel] Filtering subagent tool result: \(toolName)")
                return
            }

            if toolName == "Task" {
                log.debug("[ChatViewModel] Filtering Task tool result")
                return
            }

            let resultMsg = ChatMessage(
                role: .toolResult,
                content: output,
                timestamp: timestamp
            )
            messages.append(resultMsg)
            refreshDisplayMessagesCache()

        case .system(let content):
            handleSystemResultMessage(content)

        case .user:
            // User message echo - ignore (we already have it locally)
            break

        case .progress, .usage:
            // These are handled via Combine observation on manager state
            break
        case .stateChanged(let newState):
            if newState.isProcessing {
                hasFinalizedCurrentResponse = false
                flushedTextLength = 0
            }
            if newState == .idle {
                finalizeStreamingMessageIfNeeded()
            }

        // MARK: Agent State Events
        case .stopped:
            handleStopped()

        case .modelChanged:
            // Model changes are tracked via manager.$currentModel
            break

        case .permissionModeChanged(let mode):
            if let permMode = PermissionMode(rawValue: mode) {
                sessionPermissionMode = permMode
                log.debug("[ChatViewModel] Permission mode changed: \(mode)")
            }

        // MARK: Session Events
        case .connected(let sessionIdValue, _, _):
            handleSessionConnected(sessionId: sessionIdValue)

        case .sessionEvent(let event):
            Task { @MainActor in
                await sessionStore.handleCLISessionEvent(event)
            }

        case .history(let payload):
            handleHistoryPayload(payload)

        // MARK: Interactive Events
        case .permissionRequest(let request):
            // Convert to ApprovalRequest for UI
            let approval = ApprovalRequest(
                id: request.id,
                toolName: request.tool,
                input: request.input.mapValues { $0.value },
                receivedAt: Date()
            )
            pendingApprovalRequest = approval

        case .questionRequest(let request):
            // Convert to AskUserQuestionData for UI
            let questions = request.questions.map { q in
                UserQuestion(
                    question: q.question,
                    header: q.header,
                    options: q.options.map { QuestionOption(label: $0.label, description: $0.description) },
                    multiSelect: q.multiSelect
                )
            }
            pendingQuestionData = AskUserQuestionData(requestId: request.id, questions: questions)

        // MARK: Subagent Events
        case .subagentStart, .subagentComplete:
            // Subagent state tracked via manager.activeSubagent
            break

        // MARK: Queue Events
        case .inputQueued, .queueCleared:
            // Queue state tracked via manager.isInputQueued / queuePosition
            break

        // MARK: Connection Events
        case .connectionReplaced:
            log.warning("[ChatViewModel] Connection replaced by another client")

        case .reconnecting(let attempt, let delay):
            log.info("[ChatViewModel] Reconnecting: attempt \(attempt), delay \(delay)s")

        case .reconnectComplete:
            let attachMsg = ChatMessage(
                role: .system,
                content: "Reconnected to active session",
                timestamp: Date()
            )
            messages.append(attachMsg)
            log.debug("[ChatViewModel] Successfully reconnected to session")

        case .connectionError(let error):
            handleConnectionError(error)

        case .networkStatusChanged(let isOnline):
            log.debug("[ChatViewModel] Network status: \(isOnline ? "online" : "offline")")

        case .cursorEvicted, .cursorInvalid:
            // Cursor issues handled at manager level with reconnect
            break

        // MARK: Error Events
        case .error(let payload):
            HapticManager.error()
            let errorMessage = ChatMessage(
                role: .error,
                content: "Error: \(payload.message)",
                timestamp: Date()
            )
            messages.append(errorMessage)
            processingStartTime = nil
        }
    }

    // MARK: - Event Handlers

    func handleStopped() {
        finalizeStreamingMessageIfNeeded()
    }

    private func finalizeStreamingMessageIfNeeded() {
        guard !hasFinalizedCurrentResponse else { return }

        let finalText = committedText ?? manager.currentText
        guard !finalText.isEmpty else { return }

        let executionTime: TimeInterval? = processingStartTime.map { Date().timeIntervalSince($0) }
        let tokenCount = manager.tokenUsage?.totalTokens

        if let index = lastAssistantMessageIndexForCurrentResponse() {
            // Update existing message (may have been created by flushPendingStreamingText)
            let existing = messages[index]
            messages[index] = ChatMessage(
                id: existing.id,
                role: existing.role,
                content: finalText,
                timestamp: existing.timestamp,
                isStreaming: false,  // Mark as finalized, not streaming
                imageData: existing.imageData,
                imagePath: existing.imagePath,
                executionTime: executionTime ?? existing.executionTime,
                tokenCount: tokenCount ?? existing.tokenCount
            )
            // Force cache invalidation since we updated a message in-place
            displayCacheVersion += 1
        } else {
            let assistantMessage = ChatMessage(
                role: .assistant,
                content: finalText,
                timestamp: Date(),
                executionTime: executionTime,
                tokenCount: tokenCount
            )
            messages.append(assistantMessage)
        }

        committedText = nil
        processingStartTime = nil
        hasFinalizedCurrentResponse = true

        refreshDisplayMessagesCache()
        refreshGitStatus()
        cleanupAfterProcessingComplete()
    }

    private func handleSystemResultMessage(_ content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let index = lastAssistantMessageIndexForCurrentResponse() {
            // Update existing message with final content and mark as not streaming
            let existing = messages[index]
            if messages[index].content == content && !existing.isStreaming {
                log.debug("[ChatViewModel] Skipping duplicate system/result message")
            } else {
                messages[index] = ChatMessage(
                    id: existing.id,
                    role: existing.role,
                    content: content,
                    timestamp: existing.timestamp,
                    isStreaming: false,  // Mark as finalized
                    imageData: existing.imageData,
                    imagePath: existing.imagePath,
                    executionTime: existing.executionTime,
                    tokenCount: existing.tokenCount
                )
                // Force cache invalidation since we updated a message in-place
                displayCacheVersion += 1
            }
        } else if let lastAssistantIndex = messages.lastIndex(where: { $0.role == .assistant }) {
            let lastAssistant = messages[lastAssistantIndex]
            if lastAssistant.content == content && !lastAssistant.isStreaming {
                log.debug("[ChatViewModel] Skipping duplicate system/result message")
            } else {
                // Update the last assistant message with final content
                messages[lastAssistantIndex] = ChatMessage(
                    id: lastAssistant.id,
                    role: lastAssistant.role,
                    content: content,
                    timestamp: lastAssistant.timestamp,
                    isStreaming: false,
                    imageData: lastAssistant.imageData,
                    imagePath: lastAssistant.imagePath,
                    executionTime: lastAssistant.executionTime,
                    tokenCount: lastAssistant.tokenCount
                )
                // Force cache invalidation since we updated a message in-place
                displayCacheVersion += 1
            }
        } else {
            let systemMsg = ChatMessage(
                role: .assistant,
                content: content,
                timestamp: Date()
            )
            messages.append(systemMsg)
        }

        committedText = content
        // Mark as finalized to prevent duplicate from handleStopped (GH#6 fix)
        hasFinalizedCurrentResponse = true
        refreshDisplayMessagesCache()
    }

    private func lastAssistantMessageIndexForCurrentResponse() -> Int? {
        guard let start = processingStartTime else { return nil }
        return messages.lastIndex { message in
            message.role == .assistant && message.timestamp >= start
        }
    }

    /// Flush any pending streaming text to a message before tool events
    /// This ensures assistant text appears BEFORE tools in the message list
    private func flushPendingStreamingText() {
        let currentText = manager.currentText
        guard currentText.count > flushedTextLength else { return }

        // Get only the new text since last flush
        let pendingText = String(currentText.dropFirst(flushedTextLength))
        guard !pendingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Create or update assistant message with pending text
        let didAppend: Bool
        if let index = lastAssistantMessageIndexForCurrentResponse() {
            // Update existing message with accumulated text
            let existing = messages[index]
            messages[index] = updatedMessage(existing, content: currentText)
            // Force cache invalidation since we updated a message in-place
            displayCacheVersion += 1
            didAppend = false
        } else {
            // Create new assistant message
            let assistantMsg = ChatMessage(
                role: .assistant,
                content: currentText,
                timestamp: streamingMessageTimestamp,
                isStreaming: true
            )
            messages.append(assistantMsg)
            didAppend = true
        }

        flushedTextLength = currentText.count

        // Only refresh cache manually for updates (appends trigger onChange which refreshes)
        if !didAppend {
            refreshDisplayMessagesCache()
        }
    }

    private func updatedMessage(
        _ message: ChatMessage,
        content: String? = nil,
        executionTime: TimeInterval? = nil,
        tokenCount: Int? = nil
    ) -> ChatMessage {
        ChatMessage(
            id: message.id,
            role: message.role,
            content: content ?? message.content,
            timestamp: message.timestamp,
            isStreaming: message.isStreaming,
            imageData: message.imageData,
            imagePath: message.imagePath,
            executionTime: executionTime ?? message.executionTime,
            tokenCount: tokenCount ?? message.tokenCount
        )
    }

    func handleSessionConnected(sessionId: String) {
        let existingSession = sessionStore.sessions(for: project.path).first { $0.id == sessionId }
        if let existing = existingSession {
            if selectedSession?.id != sessionId || selectedSession?.summary == nil {
                selectedSession = existing
            }
            MessageStore.saveSessionId(sessionId, for: project.path)
            sessionStore.setActiveSession(sessionId, for: project.path)
            return
        }

        MessageStore.saveSessionId(sessionId, for: project.path)

        let summary = messages.first { $0.role == .user }?.content.prefix(50).description

        let newSession = ProjectSession(
            id: sessionId,
            summary: summary,
            lastActivity: CLIDateFormatter.string(from: Date()),
            messageCount: 1,
            lastUserMessage: summary,
            lastAssistantMessage: nil
        )

        sessionStore.addSession(newSession, for: project.path)
        sessionStore.setActiveSession(sessionId, for: project.path)
        selectedSession = newSession
    }

    func handleHistoryPayload(_ payload: CLIHistoryPayload) {
        // Use unified toChatMessages() which handles denormalized tool_use and filters ephemeral
        let historyMessages = payload.toChatMessages()
        if !historyMessages.isEmpty {
            messages.insert(contentsOf: historyMessages, at: 0)
            refreshDisplayMessagesCache()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.scrollToBottomTrigger = true
            }
        }
        log.debug("[ChatViewModel] Loaded \(historyMessages.count) history messages, hasMore: \(payload.hasMore)")
    }

    func handleConnectionError(_ error: ConnectionError) {
        HapticManager.error()

        // Handle session-related errors with full state reset
        switch error {
        case .sessionNotFound, .sessionInvalid, .sessionExpired:
            log.warning("[ChatViewModel] Session error: \(error)")

            // Show user-facing error banner
            ErrorStore.shared.post(AppError.sessionExpired)

            // Full state reset - clear everything related to the session
            selectedSession = nil
            MessageStore.clearSessionId(for: project.path)
            sessionStore.clearActiveSessionId(for: project.path)

            // Add system message for context
            let recoveryMsg = ChatMessage(
                role: .system,
                content: "Previous session is no longer available. Your next message will start a new session.",
                timestamp: Date()
            )
            messages.append(recoveryMsg)

            // Clear processing state
            cleanupAfterProcessingComplete()
            processingStartTime = nil
            return
        default:
            break
        }

        // Convert ConnectionError to AppError and post to ErrorStore for user-facing banner
        let appError = mapConnectionError(error)
        ErrorStore.shared.post(appError) { [weak self] in
            // Retry action: attempt to reconnect
            guard let self = self else { return }
            Task {
                await self.manager.connect(
                    projectPath: self.project.path,
                    sessionId: self.manager.sessionId
                )
            }
        }
    }

    // MARK: - JSON Serialization Helper

    static func toJSONString(_ value: [String: JSONValue]) -> String {
        toJSONString(value.mapValues { $0.value })
    }

    static func toJSONString(_ value: [String: Any]) -> String {
        let sanitized = sanitizeForJSON(value)
        if let data = try? JSONSerialization.data(withJSONObject: sanitized),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    private static func sanitizeForJSON(_ value: Any) -> Any {
        switch value {
        case let array as [Any]:
            return array.map { sanitizeForJSON($0) }
        case let dict as [String: Any]:
            return dict.mapValues { sanitizeForJSON($0) }
        case let string as String:
            return string
        case let number as NSNumber:
            return number
        case let bool as Bool:
            return bool
        case let int as Int:
            return int
        case let double as Double:
            return double
        case is NSNull:
            return NSNull()
        default:
            return String(describing: value)
        }
    }
}
