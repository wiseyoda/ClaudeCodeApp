import SwiftUI

/// Manager state and actions extension for ChatViewModel
/// Exposes CLIBridgeManager properties and provides action methods
extension ChatViewModel {
    // MARK: - Manager State Accessors
    // These expose manager properties to avoid nested ObservableObject observation
    // which can cause unnecessary SwiftUI re-renders

    var isProcessing: Bool { manager.agentState.isProcessing }
    // Aborting state is transient - tracks whether an interrupt was requested but not yet complete
    // For now, we don't have explicit abort tracking, so this is always false
    var isAborting: Bool { false }
    var isConnected: Bool { manager.connectionState.isConnected }
    var isReattaching: Bool { isReattachingSession }
    var currentStreamingText: String { manager.currentText }
    var tokenUsage: TokenUsage? {
        guard let usage = manager.tokenUsage else { return nil }
        return TokenUsage(
            used: usage.contextUsed ?? usage.totalTokens,
            total: usage.contextLimit ?? 200_000
        )
    }
    var pendingApproval: ApprovalRequest? { pendingApprovalRequest }
    var pendingQuestion: AskUserQuestionData? { pendingQuestionData }
    var isInputQueued: Bool { manager.isInputQueued }
    var queuePosition: Int { manager.queuePosition }
    var activeSubagent: CLISubagentStartContent? { manager.activeSubagent }
    var toolProgress: CLIProgressContent? { manager.toolProgress }
    var activeSessionId: String? { manager.sessionId }

    // MARK: - Session Actions

    func abortSession() {
        Task {
            do {
                try await manager.interrupt()
                let abortMsg = ChatMessage(
                    role: .system,
                    content: "Task aborted",
                    timestamp: Date()
                )
                messages.append(abortMsg)
                processingStartTime = nil
            } catch {
                log.error("[ChatViewModel] Failed to abort: \(error)")
            }
        }
    }

    // MARK: - Permission Actions

    func approvePendingRequest(alwaysAllow: Bool) {
        guard let approval = pendingApprovalRequest else { return }
        let choice: CLIPermissionChoice = alwaysAllow ? .always : .allow
        Task {
            do {
                try await manager.respondToPermission(id: approval.id, choice: choice)
                pendingApprovalRequest = nil
            } catch {
                log.error("[ChatViewModel] Failed to approve: \(error)")
            }
        }
    }

    func denyPendingRequest() {
        guard let approval = pendingApprovalRequest else { return }
        Task {
            do {
                try await manager.respondToPermission(id: approval.id, choice: .deny)
                pendingApprovalRequest = nil
            } catch {
                log.error("[ChatViewModel] Failed to deny: \(error)")
            }
        }
    }

    // MARK: - Queue Actions

    func cancelQueuedInput() {
        guard manager.isInputQueued else { return }
        Task {
            do {
                try await manager.cancelQueuedInput()
            } catch {
                log.error("[ChatViewModel] Failed to cancel queued input: \(error)")
            }
        }
    }

    // MARK: - Question Actions

    func handleQuestionAnswer(_ questionData: AskUserQuestionData) {
        let answerMessage = ChatMessage(
            role: .user,
            content: questionData.formatAnswers(),
            timestamp: Date()
        )
        messages.append(answerMessage)

        Task {
            do {
                try await manager.respondToQuestion(
                    id: questionData.requestId,
                    answers: questionData.answersDict()
                )
                pendingQuestionData = nil
            } catch {
                log.error("[ChatViewModel] Failed to respond to question: \(error)")
            }
        }
        processingStartTime = Date()
    }

    func handleQuestionCancel() {
        abortSession()
        clearPendingQuestion()
    }

    func clearPendingQuestion() {
        pendingQuestionData = nil
    }

    // MARK: - State Cleanup

    func clearActiveSubagent() { manager.activeSubagent = nil }
    func clearToolProgress() { manager.toolProgress = nil }

    // MARK: - Message Sending Helpers

    /// Send a message to the manager, handling connection if needed
    func sendToManager(
        _ message: String,
        projectPath: String,
        resumeSessionId: String?,
        permissionMode: String?,
        images: [ImageAttachment]?,
        model: String?
    ) {
        Task {
            do {
                // Ensure connected to the right project/session
                await manager.connect(
                    projectPath: projectPath,
                    sessionId: resumeSessionId,
                    model: model
                )

                // Set permission mode if specified
                if let mode = permissionMode, let cliMode = CLIPermissionMode(rawValue: mode) {
                    try await manager.setPermissionMode(cliMode)
                }

                // Convert images to CLIImageAttachment if present
                var cliImages: [CLIImageAttachment]?
                if let images = images, !images.isEmpty {
                    cliImages = images.map { attachment in
                        let base64 = attachment.dataForSending.base64EncodedString()
                        return CLIImageAttachment(
                            type: .base64,
                            data: base64,
                            mimeType: attachment.mimeType
                        )
                    }
                }

                // Get thinking mode if active (not normal)
                let thinkingMode = settings.thinkingMode == .normal ? nil : settings.thinkingMode.rawValue

                // Send the message
                try await manager.sendInput(message, images: cliImages, thinkingMode: thinkingMode)
            } catch {
                log.error("[ChatViewModel] Failed to send message: \(error)")
                let errorMessage = ChatMessage(
                    role: .error,
                    content: "Failed to send message: \(error.localizedDescription)",
                    timestamp: Date()
                )
                messages.append(errorMessage)
                processingStartTime = nil
            }
        }
    }

    /// Attach to an existing session (for session picker selection)
    func attachToSession(sessionId: String, projectPath: String) {
        isReattachingSession = true
        Task {
            await manager.connect(
                projectPath: projectPath,
                sessionId: sessionId
            )
            isReattachingSession = false
        }
    }

    // MARK: - Model Selection

    func switchToModel(_ model: ClaudeModel, customId: String? = nil) {
        currentModel = model
        if model == .custom, let customId = customId {
            self.customModelId = customId
            settings.customModelId = customId
        }
    }

    var effectiveModelId: String? {
        let model = currentModel ?? settings.defaultModel
        if model == .custom {
            return customModelId.isEmpty ? nil : customModelId
        }
        return model.modelId
    }

    /// Unified permission resolution using PermissionManager pipeline.
    /// Resolution order (highest to lowest priority):
    /// 1. Session override (per-session UI override)
    /// 2. Local project override (iOS ProjectSettingsStore)
    /// 3. Server project config (cli-bridge settings)
    /// 4. Global app setting (iOS AppSettings)
    /// 5. Server global default (cli-bridge config)
    var effectivePermissionModeValue: PermissionMode {
        PermissionManager.shared.resolvePermissionMode(
            for: project.path,
            sessionOverride: sessionPermissionMode,
            localProjectOverride: projectSettingsStore.permissionModeOverride(for: project.path),
            globalAppSetting: settings.globalPermissionMode
        )
    }

    // MARK: - Change Handlers

    func handleMessagesChange() {
        // Debounce both save and display cache refresh to avoid rapid updates during streaming
        saveDebounceTask?.cancel()
        let projectPath = project.path
        let maxMessages = settings.historyLimit.rawValue
        saveDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            MessageStore.saveMessages(messages, for: projectPath, maxMessages: maxMessages)
        }
        // Cache refresh is guarded by invalidation key, so call is cheap if key unchanged
        // But we still want to refresh to pick up new messages for display
        refreshDisplayMessagesCache()
    }

    /// Cleanup transient state after a processing cycle completes.
    /// Called from onComplete to prevent accumulation of lingering tasks/state.
    func cleanupAfterProcessingComplete() {
        // Ensure streaming state is reset
        manager.clearCurrentText()
    }

    func handleInputTextChange(_ newText: String) {
        draftDebounceTask?.cancel()
        let projectPath = project.path
        draftDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            MessageStore.saveDraft(newText, for: projectPath)
        }
    }

    func handleProcessingChange(oldValue: Bool, isProcessing: Bool) {
        MessageStore.saveProcessingState(isProcessing, for: project.path)
        // Note: streamingMessageId is now a stable constant, and streamingMessageTimestamp
        // is derived from processingStartTime, so no manual reset is needed here
    }

    func handleModelChange(oldModel: ClaudeModel, newModel: ClaudeModel) {
        guard oldModel != newModel else { return }
        guard manager.connectionState.isConnected else { return }
        guard let modelId = newModel.modelId else {
            log.debug("[ChatViewModel] Model \(newModel.shortName) has no modelId, skipping switch")
            return
        }
        log.debug("[ChatViewModel] Model changed from \(oldModel.shortName) to \(newModel.shortName) - calling setModel")
        Task {
            do {
                try await manager.setModel(modelId)
            } catch {
                log.error("[ChatViewModel] Failed to switch model: \(error)")
            }
        }
    }

    // MARK: - Error Mapping

    /// Convert ConnectionError to AppError for user-facing display via ErrorStore
    func mapConnectionError(_ error: ConnectionError) -> AppError {
        switch error {
        case .networkUnavailable:
            return .networkUnavailable
        case .serverAtCapacity, .queueFull:
            return .serverUnreachable("Server is at capacity")
        case .reconnectFailed:
            return .connectionFailed("Failed to reconnect after multiple attempts")
        case .invalidServerURL:
            return .connectionFailed("Invalid server URL")
        case .agentTimedOut:
            return .sessionExpired
        case .connectionReplaced:
            return .connectionFailed("Session opened on another device")
        case .sessionNotFound, .sessionInvalid, .sessionExpired:
            return .sessionExpired
        case .rateLimited(let retryAfter):
            return .connectionFailed("Rate limited, retry in \(retryAfter)s")
        case .serverError(_, let message, _):
            return .connectionFailed(message)
        case .authenticationFailed:
            return .connectionFailed("Authentication failed")
        case .connectionFailed(let msg):
            return .connectionFailed(msg)
        case .protocolError(let msg):
            return .connectionFailed("Protocol error: \(msg)")
        case .unknown(let msg):
            return .connectionFailed(msg)
        }
    }
}
