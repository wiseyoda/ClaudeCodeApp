import SwiftUI

/// Slash command handling extension for ChatViewModel
/// Provides the command registry and individual command handlers
extension ChatViewModel {
    // MARK: - Slash Command Types

    /// Slash command handler closure type
    /// - Parameters:
    ///   - arg: Optional argument string (text after command)
    /// - Returns: true if command was fully handled, false to pass through to server
    typealias SlashCommandHandler = (_ arg: String?) -> Bool

    // MARK: - Command Registry

    /// Registry of slash commands mapping command name to handler
    var slashCommandRegistry: [String: SlashCommandHandler] {
        [
            "/clear": { [weak self] _ in
                self?.handleClearCommand()
                return true
            },
            "/help": { [weak self] _ in
                self?.showingHelpSheet = true
                return true
            },
            "/exit": { [weak self] _ in
                self?.manager.disconnect()
                return true
            },
            "/init": { [weak self] _ in
                self?.addSystemMessage("Initializing project with Claude...")
                return false
            },
            "/new": { [weak self] _ in
                self?.handleNewSessionCommand()
                return true
            },
            "/resume": { [weak self] arg in
                self?.handleResumeCommand(arg: arg) ?? true
            },
            "/model": { [weak self] arg in
                self?.handleModelCommand(arg: arg) ?? true
            },
            "/compact": { [weak self] _ in
                self?.addSystemMessage("Sending compact request to server...")
                return false
            },
            "/status": { [weak self] _ in
                self?.showStatusInfo()
                return true
            },
        ]
    }

    // MARK: - Command Dispatch

    func handleSlashCommand(_ command: String) -> Bool {
        let parts = command.split(separator: " ", maxSplits: 1)
        let cmd = String(parts.first ?? "").lowercased()
        let arg = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : nil

        if let handler = slashCommandRegistry[cmd] {
            return handler(arg)
        }

        // Unknown command starting with /
        if cmd.hasPrefix("/") {
            addSystemMessage("Unknown command: \(cmd). Type /help for available commands.")
            return true
        }
        return false
    }

    // MARK: - Command Handlers

    /// Handle /resume command with optional session ID argument
    /// Usage: /resume [session-id]
    func handleResumeCommand(arg: String?) -> Bool {
        guard let sessionId = arg, !sessionId.isEmpty else {
            // No argument - show picker
            showingSessionPicker = true
            return true
        }

        // Validate session ID format (should be UUID)
        let cleanedId = sessionId.trimmingCharacters(in: .whitespaces)
        guard UUID(uuidString: cleanedId) != nil else {
            addSystemMessage("Invalid session ID format. Expected UUID (e.g., 550e8400-e29b-41d4-a716-446655440000).")
            return true
        }

        // Find session in local list or create ephemeral reference
        if let existingSession = localSessions.first(where: { $0.id == cleanedId }) {
            selectSession(existingSession)
            addSystemMessage("Resumed session: \(existingSession.summary ?? cleanedId.prefix(8).description)...")
        } else {
            // Create ephemeral session for the ID
            let ephemeralSession = ProjectSession(
                id: cleanedId,
                summary: nil,
                lastActivity: nil,
                messageCount: nil,
                lastUserMessage: nil,
                lastAssistantMessage: nil
            )
            selectSession(ephemeralSession)
            addSystemMessage("Resuming session: \(cleanedId.prefix(8))...")
        }
        return true
    }

    /// Handle /model command with model name argument
    /// Usage: /model <opus|sonnet|haiku|custom-model-id>
    func handleModelCommand(arg: String?) -> Bool {
        guard let modelArg = arg, !modelArg.isEmpty else {
            // No argument - show current model and usage
            let current = currentModel ?? settings.defaultModel
            addSystemMessage("Current model: \(current.displayName)\nUsage: /model <opus|sonnet|haiku|model-id>")
            return true
        }

        let cleanedArg = modelArg.lowercased().trimmingCharacters(in: .whitespaces)

        // Check for standard model names
        switch cleanedArg {
        case "opus", "opus4.5", "claude-opus":
            switchToModel(.opus)
            settings.defaultModel = .opus
            addSystemMessage("Switched to Opus 4.5")
            return true

        case "sonnet", "sonnet4.5", "claude-sonnet":
            switchToModel(.sonnet)
            settings.defaultModel = .sonnet
            addSystemMessage("Switched to Sonnet 4.5")
            return true

        case "haiku", "haiku4.5", "claude-haiku":
            switchToModel(.haiku)
            settings.defaultModel = .haiku
            addSystemMessage("Switched to Haiku 4.5")
            return true

        default:
            // Validate custom model ID format (should contain hyphen or be claude-like)
            // Valid formats: claude-3-opus-20240229, anthropic.claude-v2, etc.
            let isValidCustomId = cleanedArg.contains("-") ||
                                  cleanedArg.contains(".") ||
                                  cleanedArg.hasPrefix("claude")

            if isValidCustomId {
                switchToModel(.custom, customId: modelArg)  // Use original case
                settings.defaultModel = .custom
                settings.customModelId = modelArg
                addSystemMessage("Switched to custom model: \(modelArg)")
            } else {
                addSystemMessage("Invalid model: '\(modelArg)'. Use opus, sonnet, haiku, or a valid model ID.")
            }
        }
        return true
    }

    func handleClearCommand() {
        log.debug("[ChatViewModel] /clear command - clearing state and reconnecting")

        // Clear UI state
        messages = []
        MessageStore.clearMessages(for: project.path)
        MessageStore.clearSessionId(for: project.path)
        sessionStore.clearActiveSessionId(for: project.path)

        // Create ephemeral session placeholder to prevent nil selectedSession issues
        let ephemeralSession = ProjectSession(
            id: "new-session-\(UUID().uuidString)",
            summary: "New Session",
            lastActivity: CLIDateFormatter.string(from: Date()),
            messageCount: 0,
            lastUserMessage: nil,
            lastAssistantMessage: nil
        )
        selectedSession = ephemeralSession

        // Disconnect and reconnect WebSocket without sessionId
        manager.disconnect()
        manager.sessionId = nil
        Task {
            await manager.connect(projectPath: project.path, sessionId: nil)
        }

        addSystemMessage("Conversation cleared. Starting fresh.")
        refreshDisplayMessagesCache()
    }

    func handleNewSessionCommand() {
        log.debug("[ChatViewModel] /new command - starting new session")

        // Clear UI state
        messages = []
        MessageStore.clearMessages(for: project.path)
        MessageStore.clearSessionId(for: project.path)
        sessionStore.clearActiveSessionId(for: project.path)

        // Create ephemeral session placeholder to prevent nil selectedSession issues
        let ephemeralSession = ProjectSession(
            id: "new-session-\(UUID().uuidString)",
            summary: "New Session",
            lastActivity: CLIDateFormatter.string(from: Date()),
            messageCount: 0,
            lastUserMessage: nil,
            lastAssistantMessage: nil
        )
        selectedSession = ephemeralSession

        // Disconnect and reconnect WebSocket without sessionId
        manager.disconnect()
        manager.sessionId = nil
        Task {
            await manager.connect(projectPath: project.path, sessionId: nil)
        }

        addSystemMessage("New session started.")
        refreshDisplayMessagesCache()
    }

    func showStatusInfo() {
        var status = "Connection: \(manager.connectionState.isConnected ? "Connected" : "Disconnected")"
        if let sessionId = manager.sessionId {
            status += "\nSession: \(sessionId.prefix(8))..."
        }
        if let usage = tokenUsage {
            status += "\nTokens: \(usage.used)/\(usage.total)"
        }
        status += "\nProject: \(project.path)"
        addSystemMessage(status)
    }
}
