import SwiftUI
import UIKit
import PhotosUI

struct ChatView: View {
    let project: Project
    let apiClient: APIClient
    @EnvironmentObject var settings: AppSettings
    @StateObject private var wsManager: WebSocketManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var selectedImage: Data?
    @State private var processingStartTime: Date?
    @State private var selectedSession: ProjectSession?
    @State private var isUploadingImage = false
    @State private var isLoadingHistory = false
    @State private var scrollToBottomTrigger = false
    @State private var pendingQuestions: AskUserQuestionData?  // For AskUserQuestion tool
    @State private var showingHelpSheet = false  // For /help command
    @State private var showingSessionPicker = false  // For /resume command
    @State private var localSessions: [ProjectSession]?  // Local copy for session management
    @StateObject private var sshManager = SSHManager()  // For session deletion
    @FocusState private var isInputFocused: Bool

    init(project: Project, apiClient: APIClient) {
        self.project = project
        self.apiClient = apiClient
        // Initialize WebSocketManager without settings - will be configured in onAppear
        _wsManager = StateObject(wrappedValue: WebSocketManager())
    }

    var body: some View {
        VStack(spacing: 0) {
            sessionPickerView
            messagesScrollView
            statusAndInputView
        }
        .background(CLITheme.background(for: colorScheme))
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CLITheme.secondaryBackground(for: colorScheme), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        messages = []
                        wsManager.sessionId = nil
                        selectedSession = nil
                        MessageStore.clearMessages(for: project.path)
                    } label: {
                        Label("New Chat", systemImage: "plus")
                    }

                    if wsManager.isProcessing {
                        Button(role: .destructive) {
                            wsManager.abortSession()
                        } label: {
                            Label("Abort", systemImage: "stop.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                }
                .accessibilityLabel("Chat options")
                .accessibilityHint("Open menu with new chat and abort options")
            }
        }
        .onAppear {
            // Update WebSocketManager with actual EnvironmentObject settings
            wsManager.updateSettings(settings)
            setupWebSocketCallbacks()
            wsManager.connect()

            // Load persisted messages
            let savedMessages = MessageStore.loadMessages(for: project.path)
            if !savedMessages.isEmpty {
                messages = savedMessages
                // Trigger scroll to bottom after loading persisted messages
                scrollToBottomTrigger = true
            }

            // Load draft input
            let savedDraft = MessageStore.loadDraft(for: project.path)
            if !savedDraft.isEmpty {
                inputText = savedDraft
            }

            // Auto-focus input field after view loads
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isInputFocused = true
            }
        }
        .onDisappear {
            wsManager.disconnect()
            // Save messages when leaving
            MessageStore.saveMessages(messages, for: project.path)
        }
        .onChange(of: messages) { _, newMessages in
            // Save messages whenever they change (debounced by iOS)
            MessageStore.saveMessages(newMessages, for: project.path)
        }
        .onChange(of: inputText) { _, newText in
            // Auto-save draft input
            MessageStore.saveDraft(newText, for: project.path)
        }
        .onChange(of: wsManager.isProcessing) { _, isProcessing in
            // Refocus input when processing completes
            if !isProcessing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInputFocused = true
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // App came to foreground
                wsManager.isAppInForeground = true
                // Reconnect if disconnected
                if !wsManager.isConnected {
                    print("[ChatView] App active - reconnecting WebSocket")
                    wsManager.connect()
                }
            case .inactive:
                // App is inactive (transitioning)
                break
            case .background:
                // App went to background
                wsManager.isAppInForeground = false
                print("[ChatView] App backgrounded")
            @unknown default:
                break
            }
        }
        .sheet(item: $pendingQuestions) { questionData in
            userQuestionsSheet(questionData)
        }
        .sheet(isPresented: $showingHelpSheet) {
            SlashCommandHelpSheet()
        }
        .sheet(isPresented: $showingSessionPicker) {
            SessionPickerSheet(
                project: project,
                sessions: localSessions ?? project.sessions ?? [],
                onSelect: { session in
                    showingSessionPicker = false
                    selectedSession = session
                    loadSessionHistory(session)
                },
                onCancel: {
                    showingSessionPicker = false
                },
                onDelete: { session in
                    Task { await deleteSession(session) }
                }
            )
        }
        .onAppear {
            // Initialize local sessions copy
            if localSessions == nil {
                localSessions = project.sessions
            }
        }
    }

    /// Sheet view for AskUserQuestion - extracted to help Swift compiler
    @ViewBuilder
    private func userQuestionsSheet(_ initialData: AskUserQuestionData) -> some View {
        UserQuestionsView(
            questionData: Binding(
                get: { pendingQuestions ?? initialData },
                set: { pendingQuestions = $0 }
            ),
            onSubmit: { answer in
                handleQuestionAnswer(answer)
            },
            onCancel: {
                handleQuestionCancel()
            }
        )
    }

    /// Handle submission of question answers
    private func handleQuestionAnswer(_ answer: String) {
        let answerMessage = ChatMessage(
            role: .user,
            content: answer,
            timestamp: Date()
        )
        messages.append(answerMessage)

        wsManager.sendMessage(
            answer,
            projectPath: project.path,
            resumeSessionId: selectedSession?.id,
            permissionMode: settings.effectivePermissionMode
        )
        processingStartTime = Date()
        pendingQuestions = nil
    }

    /// Handle cancellation of question dialog
    private func handleQuestionCancel() {
        wsManager.abortSession()
        pendingQuestions = nil
    }

    // MARK: - View Components (extracted to help Swift compiler)

    @ViewBuilder
    private var sessionPickerView: some View {
        if let sessions = project.sessions, !sessions.isEmpty {
            SessionPicker(sessions: sessions, selected: $selectedSession, isLoading: isLoadingHistory) { session in
                wsManager.sessionId = session.id
                loadSessionHistory(session)
            }
        }
    }

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                messagesListView
            }
            .background(CLITheme.background(for: colorScheme))
            .onChange(of: messages.count) { _, _ in
                guard settings.autoScrollEnabled else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo("bottomAnchor", anchor: .bottom)
                    }
                }
            }
            .onChange(of: wsManager.currentText) { _, _ in
                guard settings.autoScrollEnabled else { return }
                proxy.scrollTo("bottomAnchor", anchor: .bottom)
            }
            .onChange(of: wsManager.isProcessing) { _, _ in
                guard settings.autoScrollEnabled else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo("bottomAnchor", anchor: .bottom)
                    }
                }
            }
            .onChange(of: scrollToBottomTrigger) { _, shouldScroll in
                // Always honor explicit scroll triggers (e.g., loading history)
                if shouldScroll {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        proxy.scrollTo("bottomAnchor", anchor: .bottom)
                        scrollToBottomTrigger = false
                    }
                }
            }
            .onAppear {
                // Always scroll to bottom on initial appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    proxy.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }
        }
    }

    /// Messages filtered based on user settings (e.g., hide thinking blocks)
    private var displayMessages: [ChatMessage] {
        if settings.showThinkingBlocks {
            return messages
        } else {
            return messages.filter { $0.role != .thinking }
        }
    }

    private var messagesListView: some View {
        LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(displayMessages) { message in
                CLIMessageView(message: message)
                    .id(message.id)
            }

            if wsManager.isProcessing {
                streamingIndicatorView
            }

            // Invisible bottom anchor for reliable scrolling
            Color.clear
                .frame(height: 1)
                .id("bottomAnchor")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var streamingIndicatorView: some View {
        if wsManager.currentText.isEmpty {
            CLIProcessingView()
                .id("streaming")
        } else {
            CLIMessageView(message: ChatMessage(
                role: .assistant,
                content: wsManager.currentText,
                timestamp: Date(),
                isStreaming: true
            ))
            .id("streaming")
        }
    }

    private var statusAndInputView: some View {
        VStack(spacing: 0) {
            CLIStatusBar(
                isProcessing: wsManager.isProcessing,
                isUploadingImage: isUploadingImage,
                startTime: processingStartTime,
                tokenUsage: wsManager.tokenUsage
            )

            CLIInputView(
                text: $inputText,
                selectedImage: $selectedImage,
                isProcessing: wsManager.isProcessing,
                projectPath: project.path,
                isFocused: _isInputFocused,
                onSend: sendMessage,
                onAbort: { wsManager.abortSession() }
            )
            .id("input-view")

            CLIModeSelector()
        }
    }

    private func setupWebSocketCallbacks() {
        wsManager.onText = { text in
            // Text is accumulated in wsManager.currentText (shown in streaming view)
        }

        wsManager.onTextCommit = { text in
            // Text segment is complete (before a tool use) - add as message
            let assistantMsg = ChatMessage(
                role: .assistant,
                content: text,
                timestamp: Date()
            )
            messages.append(assistantMsg)
        }

        wsManager.onToolUse = { name, input in
            let toolMsg = ChatMessage(
                role: .toolUse,
                content: "\(name)(\(input))",
                timestamp: Date()
            )
            messages.append(toolMsg)
        }

        wsManager.onToolResult = { result in
            // Store full result - truncation is handled in display
            let resultMsg = ChatMessage(
                role: .toolResult,
                content: result,
                timestamp: Date()
            )
            messages.append(resultMsg)
        }

        wsManager.onThinking = { thinking in
            let thinkingMsg = ChatMessage(
                role: .thinking,
                content: thinking,
                timestamp: Date()
            )
            messages.append(thinkingMsg)
        }

        wsManager.onComplete = { _ in
            // Add final assistant message
            if !wsManager.currentText.isEmpty {
                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: wsManager.currentText,
                    timestamp: Date()
                )
                messages.append(assistantMessage)
            }
            processingStartTime = nil
        }

        wsManager.onError = { error in
            let errorMessage = ChatMessage(
                role: .error,
                content: "Error: \(error)",
                timestamp: Date()
            )
            messages.append(errorMessage)
            processingStartTime = nil
        }

        wsManager.onSessionCreated = { sessionId in
            // Session created notification
            let systemMsg = ChatMessage(
                role: .system,
                content: "Session: \(sessionId.prefix(8))...",
                timestamp: Date()
            )
            messages.append(systemMsg)
        }

        wsManager.onAskUserQuestion = { questionData in
            // Show the question UI sheet
            print("[ChatView] Received AskUserQuestion with \(questionData.questions.count) questions")
            pendingQuestions = questionData
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || selectedImage != nil else { return }

        // Check for slash commands (client-side handling)
        if text.hasPrefix("/") && selectedImage == nil {
            if handleSlashCommand(text) {
                inputText = ""
                return
            }
            // If command not handled, fall through to send to server
        }

        // Capture image before clearing
        let imageToSend = selectedImage

        // Add user message with optional image
        let userMessage = ChatMessage(
            role: .user,
            content: text.isEmpty ? "[Image attached]" : text,
            timestamp: Date(),
            imageData: imageToSend
        )
        messages.append(userMessage)

        inputText = ""
        selectedImage = nil
        processingStartTime = Date()

        // If we have an image, send it with the message
        if let imageData = imageToSend {
            // Send message with image data directly via WebSocket
            wsManager.sendMessage(
                text.isEmpty ? "What is this image?" : text,
                projectPath: project.path,
                resumeSessionId: selectedSession?.id,
                permissionMode: settings.effectivePermissionMode,
                imageData: imageData
            )
        } else {
            // No image - just send text
            wsManager.sendMessage(
                text,
                projectPath: project.path,
                resumeSessionId: selectedSession?.id,
                permissionMode: settings.effectivePermissionMode
            )
        }

        // Persist messages
        MessageStore.saveMessages(messages, for: project.path)
    }

    // MARK: - Slash Commands

    /// Handle slash commands, returns true if command was handled
    private func handleSlashCommand(_ command: String) -> Bool {
        let parts = command.lowercased().split(separator: " ", maxSplits: 1)
        let cmd = String(parts.first ?? "")

        switch cmd {
        case "/clear":
            handleClearCommand()
            return true

        case "/help":
            showingHelpSheet = true
            return true

        case "/exit":
            // Disconnect and go back
            wsManager.disconnect()
            dismiss()
            return true

        case "/init":
            // Pass to Claude to create/modify CLAUDE.md
            addSystemMessage("Initializing project with Claude...")
            return false  // Let it pass through to server

        case "/new":
            // Start a new session (local command)
            handleNewSessionCommand()
            return true

        case "/resume":
            // Show session picker
            showingSessionPicker = true
            return true

        case "/compact":
            // Send to server - this is handled server-side
            addSystemMessage("Sending compact request to server...")
            return false  // Let it pass through to server

        case "/status":
            // Show connection status
            showStatusInfo()
            return true

        default:
            // Unknown command - show hint and let it pass to server
            if cmd.hasPrefix("/") {
                addSystemMessage("Unknown command: \(cmd). Type /help for available commands.")
                return true
            }
            return false
        }
    }

    private func handleClearCommand() {
        // Add confirmation message, then clear
        messages.removeAll()
        wsManager.sessionId = nil
        selectedSession = nil
        addSystemMessage("Conversation cleared. Starting fresh.")
        MessageStore.clearMessages(for: project.path)
    }

    private func handleNewSessionCommand() {
        // Clear and start new session
        messages.removeAll()
        wsManager.sessionId = nil
        selectedSession = nil
        addSystemMessage("New session started.")
        MessageStore.clearMessages(for: project.path)
    }

    private func showStatusInfo() {
        var status = "Connection: \(wsManager.isConnected ? "Connected" : "Disconnected")"
        if let sessionId = wsManager.sessionId {
            status += "\nSession: \(sessionId.prefix(8))..."
        }
        if let usage = wsManager.tokenUsage {
            status += "\nTokens: \(usage.used)/\(usage.total)"
        }
        status += "\nProject: \(project.path)"
        addSystemMessage(status)
    }

    private func addSystemMessage(_ content: String) {
        let msg = ChatMessage(role: .system, content: content, timestamp: Date())
        messages.append(msg)
    }

    /// Load full session history via API
    private func loadSessionHistory(_ session: ProjectSession) {
        messages = []  // Clear current messages
        isLoadingHistory = true

        Task {
            do {
                print("[ChatView] Loading session history via API for: \(session.id)")

                // Fetch session messages via API (much simpler than SSH!)
                let sessionMessages = try await apiClient.fetchSessionMessages(
                    projectName: project.name,
                    sessionId: session.id
                )

                // Convert API messages to ChatMessages
                let historyMessages = sessionMessages.compactMap { $0.toChatMessage() }

                await MainActor.run {
                    isLoadingHistory = false
                    if historyMessages.isEmpty {
                        // Fallback to lastAssistantMessage if parsing failed
                        if let lastMsg = session.lastAssistantMessage {
                            messages.append(ChatMessage(role: .assistant, content: lastMsg, timestamp: Date()))
                        }
                    } else {
                        messages = historyMessages
                        print("[ChatView] Loaded \(historyMessages.count) messages from session history via API")
                    }
                    // Trigger scroll to bottom
                    scrollToBottomTrigger = true
                }
            } catch {
                print("[ChatView] Failed to load session history via API: \(error)")
                await MainActor.run {
                    isLoadingHistory = false
                    // Fallback to lastAssistantMessage
                    if let lastMsg = session.lastAssistantMessage {
                        messages.append(ChatMessage(role: .assistant, content: lastMsg, timestamp: Date()))
                    }
                    // Show error message
                    messages.append(ChatMessage(role: .system, content: "Could not load history: \(error.localizedDescription)", timestamp: Date()))
                    // Trigger scroll to bottom
                    scrollToBottomTrigger = true
                }
            }
        }
    }

    /// Delete a session from the server
    private func deleteSession(_ session: ProjectSession) async {
        // Session files are stored at: ~/.claude/projects/{encoded-path}/{session-id}.jsonl
        let encodedPath = project.path.replacingOccurrences(of: "/", with: "-")
        let sessionFile = "~/.claude/projects/\(encodedPath)/\(session.id).jsonl"

        do {
            let deleteCmd = "rm -f '\(sessionFile)'"
            _ = try await sshManager.executeCommandWithAutoConnect(deleteCmd, settings: settings)

            // Remove from local list
            await MainActor.run {
                localSessions?.removeAll { $0.id == session.id }

                // If we deleted the currently selected session, clear it
                if selectedSession?.id == session.id {
                    selectedSession = nil
                    messages.removeAll()
                    wsManager.sessionId = nil
                }
            }
        } catch {
            print("[ChatView] Failed to delete session: \(error)")
        }
    }
}

// MARK: - Slash Command Help Sheet

struct SlashCommandHelpSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Available Commands")
                        .font(.headline)
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))

                    VStack(alignment: .leading, spacing: 12) {
                        CommandRow(command: "/clear", description: "Clear conversation and start fresh")
                        CommandRow(command: "/new", description: "Start a new session")
                        CommandRow(command: "/init", description: "Create/modify CLAUDE.md (via Claude)")
                        CommandRow(command: "/resume", description: "Resume a previous session")
                        CommandRow(command: "/compact", description: "Compact conversation to save context")
                        CommandRow(command: "/status", description: "Show connection and session info")
                        CommandRow(command: "/exit", description: "Close chat and return to projects")
                        CommandRow(command: "/help", description: "Show this help")
                    }

                    Divider()
                        .padding(.vertical, 8)

                    Text("Claude Commands")
                        .font(.headline)
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))

                    Text("Other slash commands (like /review, /commit) are passed directly to Claude for handling.")
                        .font(.subheadline)
                        .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                }
                .padding()
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Commands")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CommandRow: View {
    let command: String
    let description: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(command)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(CLITheme.cyan(for: colorScheme))
                .frame(width: 100, alignment: .leading)

            Text(description)
                .font(.subheadline)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Placeholder Extension

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    let settings = AppSettings()
    return NavigationStack {
        ChatView(
            project: Project(
                name: "test-project",
                path: "/test/project",
                displayName: "Test Project",
                fullPath: "/test/project",
                sessions: nil
            ),
            apiClient: APIClient(settings: settings)
        )
    }
    .environmentObject(settings)
}
