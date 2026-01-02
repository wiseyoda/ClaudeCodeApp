import SwiftUI

/// Session management extension for ChatViewModel
/// Handles session selection, loading history, and session lifecycle operations
extension ChatViewModel {
    // MARK: - Session Properties

    var localSessions: [ProjectSession] {
        sessionStore.sessions(for: project.path)
    }

    var localSessionsBinding: Binding<[ProjectSession]> {
        Binding(
            get: { [weak self] in self?.sessionStore.sessions(for: self?.project.path ?? "") ?? [] },
            set: { _ in }
        )
    }

    var sessions: [ProjectSession] {
        let activeId = manager.sessionId
        if sessionStore.hasLoaded(for: project.path) {
            return localSessions.filterForDisplay(projectPath: project.path, activeSessionId: activeId)
        }
        let baseSessions = localSessions.isEmpty ? (project.sessions ?? []) : localSessions
        return baseSessions.filterForDisplay(projectPath: project.path, activeSessionId: activeId)
    }

    // MARK: - Session Actions

    func startNewSession() {
        log.debug("[ChatViewModel] Starting new session - clearing state and reconnecting")

        // Clear UI state
        messages = []
        MessageStore.clearMessages(for: project.path)
        MessageStore.clearSessionId(for: project.path)
        sessionStore.clearActiveSessionId(for: project.path)

        // Create ephemeral session placeholder
        let ephemeralSession = ProjectSession(
            id: "new-session-\(UUID().uuidString)",
            summary: "New Session",
            lastActivity: CLIDateFormatter.string(from: Date()),
            messageCount: 0,
            lastUserMessage: nil,
            lastAssistantMessage: nil
        )
        selectedSession = ephemeralSession

        // CRITICAL: Disconnect and reconnect WebSocket WITHOUT a sessionId
        // This ensures the backend creates a new session when the user sends their first message
        manager.disconnect()
        manager.sessionId = nil
        log.debug("[ChatViewModel] Reconnecting WebSocket without sessionId for fresh session")
        Task {
            await manager.connect(projectPath: project.path, sessionId: nil)
        }

        let welcomeMessage = ChatMessage(
            role: .system,
            content: "New session started. How can I help you?",
            timestamp: Date()
        )
        messages.append(welcomeMessage)
        refreshDisplayMessagesCache()
    }

    func selectInitialSession() {
        if let preSelectedId = sessionStore.loadActiveSessionId(for: project.path) {
            if let preSelectedSession = sessionStore.sessions(for: project.path).first(where: { $0.id == preSelectedId }) {
                log.debug("[ChatViewModel] Using pre-selected session: \(preSelectedId.prefix(8))...")
                selectedSession = preSelectedSession
            } else {
                log.debug("[ChatViewModel] Pre-selected session \(preSelectedId.prefix(8)) not in list, creating ephemeral...")
                let ephemeralSession = ProjectSession(
                    id: preSelectedId,
                    summary: nil,
                    lastActivity: nil,
                    messageCount: nil,
                    lastUserMessage: nil,
                    lastAssistantMessage: nil
                )
                selectedSession = ephemeralSession
            }
            sessionStore.clearActiveSessionId(for: project.path)
        } else {
            autoSelectMostRecentSession()
        }
    }

    func autoSelectMostRecentSession() {
        let storeSessions = sessionStore.displaySessions(for: project.path)
        if !storeSessions.isEmpty {
            if let mostRecent = storeSessions.first, (mostRecent.messageCount ?? 0) > 0 {
                selectedSession = mostRecent
                return
            }
        }

        guard let sessions = project.sessions else { return }
        let filteredSessions = sessions.filterAndSortForDisplay(projectPath: project.path, activeSessionId: nil)
        guard let mostRecent = filteredSessions.first,
              (mostRecent.messageCount ?? 0) > 0 else { return }

        selectedSession = mostRecent
    }

    func selectMostRecentSession(from sessions: [ProjectSession]) {
        guard let mostRecent = sessions.first else { return }

        log.debug("[ChatViewModel] Selecting most recent session: \(mostRecent.id.prefix(8))...")
        manager.sessionId = mostRecent.id
        selectedSession = mostRecent
        MessageStore.saveSessionId(mostRecent.id, for: project.path)

        if messages.isEmpty {
            loadSessionHistory(mostRecent)
        }
    }

    func attemptSessionReattachment(sessionId: String) {
        Task {
            var attempts = 0
            while !manager.connectionState.isConnected && attempts < 20 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                attempts += 1
            }

            if manager.connectionState.isConnected {
                log.debug("[ChatViewModel] Reattaching to session: \(sessionId.prefix(8))...")
                attachToSession(sessionId: sessionId, projectPath: project.path)
            } else {
                log.debug("[ChatViewModel] Could not reattach - WebSocket not connected after wait")
                MessageStore.clearProcessingState(for: project.path)
            }
        }
    }

    func selectSession(_ session: ProjectSession) {
        selectedSession = session
        // Must attach to session (reconnect WebSocket), not just set sessionId property
        // Otherwise messages go to whatever session the WebSocket was previously connected to
        attachToSession(sessionId: session.id, projectPath: project.path)
        MessageStore.saveSessionId(session.id, for: project.path)
        loadSessionHistory(session)
    }

    func loadSessionHistory(_ session: ProjectSession) {
        // Cancel any existing history load to prevent race conditions when switching sessions rapidly
        historyLoadTask?.cancel()

        messages = []
        isLoadingHistory = true

        // Capture session ID to check for staleness after async operations
        let targetSessionId = session.id

        historyLoadTask = Task {
            do {
                let limit = settings.historyLimit.rawValue
                log.debug("[ChatViewModel] Loading session history via unified API for: \(session.id) (limit: \(limit))")

                let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)

                // Use the paginated messages endpoint with unified StoredMessage format
                let response = try await apiClient.fetchInitialMessages(
                    projectPath: project.path,
                    sessionId: session.id,
                    limit: limit
                )

                // Check if task was cancelled or session changed while loading
                guard !Task.isCancelled, selectedSession?.id == targetSessionId else {
                    log.debug("[ChatViewModel] History load cancelled or session changed, discarding results")
                    return
                }

                // Token usage is tracked via StreamEvents when messages arrive

                // Convert StoredMessages to ChatMessages using unified helper
                // Response is in "desc" order (newest first), reverse for chronological display
                let historyMessages = Array(response.toChatMessages().reversed())

                if historyMessages.isEmpty {
                    if let lastMsg = session.lastAssistantMessage {
                        messages.append(ChatMessage(role: .assistant, content: lastMsg, timestamp: Date()))
                    }
                } else {
                    messages = historyMessages
                    log.debug("[ChatViewModel] Loaded \(historyMessages.count) messages via unified API (total: \(response.total), hasMore: \(response.hasMore))")
                }
                isLoadingHistory = false
                refreshDisplayMessagesCache()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.scrollToBottomTrigger = true
                }
            } catch {
                // Check if cancelled before showing error
                guard !Task.isCancelled else { return }
                log.debug("[ChatViewModel] Failed to load session history: \(error)")
                if let lastMsg = session.lastAssistantMessage {
                    messages.append(ChatMessage(role: .assistant, content: lastMsg, timestamp: Date()))
                }
                messages.append(ChatMessage(role: .system, content: "Could not load history: \(error.localizedDescription)", timestamp: Date()))
                isLoadingHistory = false
                refreshDisplayMessagesCache()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.scrollToBottomTrigger = true
                }
            }
        }
    }

    func deleteSession(_ session: ProjectSession) async {
        log.debug("[ChatViewModel] Deleting session: \(session.id)")

        let success = await sessionStore.deleteSession(session, for: project.path)

        if success {
            if selectedSession?.id == session.id {
                selectedSession = nil
                messages.removeAll()
                manager.sessionId = nil
                MessageStore.clearSessionId(for: project.path)
            }
            onSessionsChanged?()
        } else {
            log.debug("[ChatViewModel] Failed to delete session: \(session.id)")
        }
    }
}
