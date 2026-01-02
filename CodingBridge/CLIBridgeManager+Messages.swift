import Foundation

// MARK: - Message Sending
// Methods to send messages to the server

extension CLIBridgeManager {
    // MARK: - Message Sending (Implementations)

    /// Send user input implementation - called from main class
    func sendInputImpl(_ text: String, images: [CLIImageAttachment]? = nil, thinkingMode: String? = nil) async throws {
        let payload = InputMessage(text: text, images: images, thinkingMode: thinkingMode)
        try await send(.input(payload))
        if agentState == .idle {
            agentState = .thinking
        }
    }

    /// Interrupt implementation - called from main class
    func interruptImpl() async throws {
        try await send(.interrupt)
    }

    /// Stop the agent (end session)
    func stop() async throws {
        try await send(.stop)
    }

    /// Respond to permission implementation - called from main class
    func respondToPermissionImpl(id: String, choice: PermissionResponseMessage.Choice) async throws {
        let payload = PermissionResponseMessage(id: id, choice: choice)
        try await send(.permissionResponse(payload))
        pendingPermission = nil
    }

    /// Respond to question implementation - called from main class
    func respondToQuestionImpl(id: String, answers: [String: Any]) async throws {
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

    /// Change model implementation - called from main class
    func setModelImpl(_ model: String) async throws {
        try await send(.setModel(SetModelMessage(model: model)))
    }

    /// Set permission mode for the agent
    /// - Parameter mode: "default", "acceptEdits", or "bypassPermissions"
    func setPermissionMode(_ mode: CLIPermissionMode) async throws {
        let mappedMode = SetPermissionModeMessage.Mode(rawValue: mode.rawValue) ?? ._default
        try await send(.setPermissionMode(SetPermissionModeMessage(mode: mappedMode)))
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

    // MARK: - Text Handling

    /// Clear current text (call when starting new message)
    func clearCurrentText() {
        currentText = ""
    }
}
