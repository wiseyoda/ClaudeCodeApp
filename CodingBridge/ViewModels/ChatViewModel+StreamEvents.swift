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
                manager.clearCurrentText()
            }

        case .thinking(let content):
            let thinkingMsg = ChatMessage(
                role: .thinking,
                content: content,
                timestamp: Date()
            )
            messages.append(thinkingMsg)

        case .toolStart(_, let name, let inputDescription, let input):
            // Filter tools from subagent execution (except Task itself which we show)
            if manager.activeSubagent != nil && name != "Task" {
                log.debug("[ChatViewModel] Filtering subagent tool: \(name)")
                return
            }

            // Use typed inputDescription if available, otherwise fall back to JSON serialization
            let inputString = inputDescription ?? Self.toJSONString(input)
            let toolMsg = ChatMessage(
                role: .toolUse,
                content: "\(name)(\(inputString))",
                timestamp: Date()
            )
            messages.append(toolMsg)

            if name == "TodoWrite" {
                let content = "\(name)(\(inputString))"
                if let todos = TodoListView.parseTodoContent(content), !todos.isEmpty {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        self.currentTodos = todos
                        self.showTodoDrawer = true
                    }
                }
            }

        case .toolResult(_, let tool, let output, _):
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
                timestamp: Date()
            )
            messages.append(resultMsg)

        case .system(let content):
            // System messages with subtype "result" are final response messages from Claude
            // Skip if content matches the last assistant message (cli-bridge sends both)
            if let lastAssistant = messages.last(where: { $0.role == .assistant }) {
                if lastAssistant.content == content {
                    log.debug("[ChatViewModel] Skipping duplicate system/result message")
                    return
                }
            }
            // Display as assistant message if it differs
            let systemMsg = ChatMessage(
                role: .assistant,
                content: content,
                timestamp: Date()
            )
            messages.append(systemMsg)
            refreshDisplayMessagesCache()

        case .user:
            // User message echo - ignore (we already have it locally)
            break

        case .progress, .usage, .stateChanged:
            // These are handled via Combine observation on manager state
            break

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
        // Create assistant message from committed text
        if let text = committedText, !text.isEmpty {
            let executionTime: TimeInterval? = processingStartTime.map { Date().timeIntervalSince($0) }
            let tokenCount = manager.tokenUsage?.totalTokens

            let assistantMessage = ChatMessage(
                role: .assistant,
                content: text,
                timestamp: Date(),
                executionTime: executionTime,
                tokenCount: tokenCount
            )
            messages.append(assistantMessage)
        }
        committedText = nil
        processingStartTime = nil

        refreshGitStatus()

        cleanupAfterProcessingComplete()
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

        // Handle session-related errors specially
        switch error {
        case .sessionNotFound, .sessionInvalid, .sessionExpired:
            let recoveryMsg = ChatMessage(
                role: .system,
                content: "Previous session expired. Starting fresh session.",
                timestamp: Date()
            )
            messages.append(recoveryMsg)
            MessageStore.clearSessionId(for: project.path)

            // Reset selectedSession to ephemeral to prevent invalid-session-ID loop
            let ephemeralSession = ProjectSession(
                id: "new-session-\(UUID().uuidString)",
                summary: "New Session",
                lastActivity: CLIDateFormatter.string(from: Date()),
                messageCount: 0,
                lastUserMessage: nil,
                lastAssistantMessage: nil
            )
            selectedSession = ephemeralSession
            sessionStore.clearActiveSessionId(for: project.path)
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
