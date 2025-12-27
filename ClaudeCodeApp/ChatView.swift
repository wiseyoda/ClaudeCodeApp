import SwiftUI
import UIKit
import PhotosUI

struct ChatView: View {
    let project: Project
    let apiClient: APIClient
    let initialGitStatus: GitStatus
    @EnvironmentObject var settings: AppSettings
    @StateObject private var wsManager: WebSocketManager
    @StateObject private var claudeHelper: ClaudeHelper
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
    @State private var showingBookmarks = false  // For bookmarks view

    // Search and filter state
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var messageFilter: MessageFilter = .all
    @State private var localSessions: [ProjectSession]?  // Local copy for session management
    @StateObject private var sshManager = SSHManager()  // For session deletion
    @FocusState private var isInputFocused: Bool

    // Git sync state
    @State private var gitStatus: GitStatus = .unknown
    @State private var isAutoPulling = false
    @State private var showGitBanner = true
    @State private var hasPromptedCleanup = false

    // Model selection state
    @State private var showingModelPicker = false
    @State private var currentModel: ClaudeModel?
    @State private var customModelId = ""

    // Quick settings sheet
    @State private var showQuickSettings = false

    init(project: Project, apiClient: APIClient, initialGitStatus: GitStatus = .unknown) {
        self.project = project
        self.apiClient = apiClient
        self.initialGitStatus = initialGitStatus
        // Initialize WebSocketManager without settings - will be configured in onAppear
        _wsManager = StateObject(wrappedValue: WebSocketManager())
        _claudeHelper = StateObject(wrappedValue: ClaudeHelper(settings: AppSettings()))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar (when searching)
            if isSearching {
                ChatSearchBar(
                    searchText: $searchText,
                    isSearching: $isSearching,
                    selectedFilter: $messageFilter
                )

                // Result count
                SearchResultCount(count: displayMessages.count, searchText: searchText)
            }

            // Git status banner (when there are local changes)
            gitStatusBannerView

            sessionPickerView
            messagesScrollView
            statusAndInputView
        }
        .background(CLITheme.background(for: colorScheme))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CLITheme.secondaryBackground(for: colorScheme), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            // Custom title with git status
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Text(project.title)
                        .font(.headline)
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))

                    // Tappable git status indicator
                    Button {
                        refreshGitStatus()
                    } label: {
                        GitStatusIndicator(status: gitStatus)
                    }
                    .buttonStyle(.plain)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // Search button
                    Button {
                        withAnimation {
                            isSearching.toggle()
                            if !isSearching {
                                searchText = ""
                                messageFilter = .all
                            }
                        }
                    } label: {
                        Image(systemName: isSearching ? "magnifyingglass.circle.fill" : "magnifyingglass")
                            .foregroundColor(isSearching ? CLITheme.blue(for: colorScheme) : CLITheme.secondaryText(for: colorScheme))
                    }
                    .accessibilityLabel(isSearching ? "Close search" : "Search messages")

                    // More options menu
                    Menu {
                        Button {
                            messages = []
                            wsManager.sessionId = nil
                            selectedSession = nil
                            MessageStore.clearMessages(for: project.path)
                        } label: {
                            Label("New Chat", systemImage: "plus")
                        }

                        Button {
                            showingBookmarks = true
                        } label: {
                            Label("Bookmarks", systemImage: "bookmark")
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
                    .accessibilityHint("Open menu with new chat, bookmarks, and abort options")
                }
            }
        }
        .onAppear {
            // Update managers with actual EnvironmentObject settings
            wsManager.updateSettings(settings)
            claudeHelper.updateSettings(settings)
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

            // Handle git status from ContentView
            gitStatus = initialGitStatus
            handleGitStatusOnLoad()

            // Initialize model state
            customModelId = settings.customModelId
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

            // Clear suggestions when user starts typing
            if !newText.isEmpty {
                claudeHelper.clearSuggestions()
            }
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
        .sheet(isPresented: $showingModelPicker) {
            CustomModelPickerSheet(
                customModelId: $customModelId,
                onConfirm: { modelId in
                    showingModelPicker = false
                    switchToModel(.custom, customId: modelId)
                    // Save custom model ID to settings
                    settings.customModelId = modelId
                },
                onCancel: {
                    showingModelPicker = false
                }
            )
        }
        .sheet(isPresented: $showingBookmarks) {
            BookmarksView()
                .environmentObject(settings)
        }
        .onAppear {
            // Initialize local sessions copy
            if localSessions == nil {
                localSessions = project.sessions
            }
        }
        // MARK: - Keyboard Shortcuts (iPad)
        .background {
            keyboardShortcutButtons
        }
    }

    // MARK: - Keyboard Shortcut Buttons

    /// Hidden buttons that respond to keyboard shortcuts on iPad
    @ViewBuilder
    private var keyboardShortcutButtons: some View {
        // Cmd+Return: Send message
        Button("") {
            sendMessage()
        }
        .keyboardShortcut(.return, modifiers: .command)
        .hidden()

        // Cmd+K: Clear conversation
        Button("") {
            handleClearCommand()
        }
        .keyboardShortcut("k", modifiers: .command)
        .hidden()

        // Cmd+N: New session
        Button("") {
            handleNewSessionCommand()
        }
        .keyboardShortcut("n", modifiers: .command)
        .hidden()

        // Cmd+.: Abort current request
        Button("") {
            if wsManager.isProcessing {
                wsManager.abortSession()
            }
        }
        .keyboardShortcut(".", modifiers: .command)
        .hidden()

        // Cmd+/: Show help
        Button("") {
            showingHelpSheet = true
        }
        .keyboardShortcut("/", modifiers: .command)
        .hidden()

        // Cmd+R: Resume session picker
        Button("") {
            showingSessionPicker = true
        }
        .keyboardShortcut("r", modifiers: .command)
        .hidden()
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
            permissionMode: settings.effectivePermissionMode,
            model: effectiveModelId
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

    @ViewBuilder
    private var gitStatusBannerView: some View {
        if showGitBanner {
            switch gitStatus {
            case .dirty, .dirtyAndAhead, .diverged:
                // Warning banner for local changes
                GitSyncBanner(
                    status: gitStatus,
                    isAutoPulling: false,
                    isRefreshing: gitStatus == .checking,
                    onDismiss: { showGitBanner = false },
                    onRefresh: { refreshGitStatus() },
                    onPull: nil,
                    onAskClaude: { promptClaudeForCleanup() }
                )

            case .behind:
                // Auto-pull in progress or behind indicator
                GitSyncBanner(
                    status: gitStatus,
                    isAutoPulling: isAutoPulling,
                    isRefreshing: gitStatus == .checking,
                    onDismiss: { showGitBanner = false },
                    onRefresh: { refreshGitStatus() },
                    onPull: { Task { await performAutoPull() } },
                    onAskClaude: nil
                )

            case .ahead:
                // Unpushed commits indicator
                GitSyncBanner(
                    status: gitStatus,
                    isAutoPulling: false,
                    isRefreshing: gitStatus == .checking,
                    onDismiss: { showGitBanner = false },
                    onRefresh: { refreshGitStatus() },
                    onPull: nil,
                    onAskClaude: { promptClaudeForCleanup() }
                )

            default:
                EmptyView()
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

    /// Messages filtered based on search, filter, and user settings
    private var displayMessages: [ChatMessage] {
        var filtered = messages

        // Apply thinking block visibility setting
        if !settings.showThinkingBlocks {
            filtered = filtered.filter { $0.role != .thinking }
        }

        // Apply message type filter
        if messageFilter != .all {
            filtered = filtered.filter { messageFilter.matches($0.role) }
        }

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }

        return filtered
    }

    private var messagesListView: some View {
        LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(displayMessages) { message in
                CLIMessageView(
                    message: message,
                    projectPath: project.path,
                    projectTitle: project.title
                )
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
            CLIMessageView(
                message: ChatMessage(
                    role: .assistant,
                    content: wsManager.currentText,
                    timestamp: Date(),
                    isStreaming: true
                ),
                projectPath: project.path,
                projectTitle: project.title
            )
            .id("streaming")
        }
    }

    private var statusAndInputView: some View {
        VStack(spacing: 0) {
            // Unified status bar with quick settings access
            UnifiedStatusBar(
                isProcessing: wsManager.isProcessing,
                isConnected: wsManager.isConnected,
                tokenUsage: wsManager.tokenUsage,
                showQuickSettings: $showQuickSettings
            )

            // AI-powered suggestion chips (shown when not processing and not typing)
            if !wsManager.isProcessing && inputText.isEmpty && !claudeHelper.suggestedActions.isEmpty {
                SuggestionChipsView(
                    suggestions: claudeHelper.suggestedActions,
                    isLoading: claudeHelper.isLoading,
                    onSelect: { suggestion in
                        // Insert the prompt and send immediately
                        inputText = suggestion.prompt
                        sendMessage()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            CLIInputView(
                text: $inputText,
                selectedImage: $selectedImage,
                isProcessing: wsManager.isProcessing,
                projectPath: project.path,
                isFocused: _isInputFocused,
                onSend: sendMessage,
                onAbort: { wsManager.abortSession() },
                recentMessages: messages,
                claudeHelper: claudeHelper
            )
            .id("input-view")
        }
        .sheet(isPresented: $showQuickSettings) {
            QuickSettingsSheet(
                tokenUsage: wsManager.tokenUsage.map { (current: $0.used, max: $0.total) }
            )
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

            // Generate AI-powered suggestions for next actions
            Task {
                await claudeHelper.generateSuggestions(
                    recentMessages: messages,
                    projectPath: project.path
                )
            }
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

        // Apply thinking mode suffix (silently - not shown in UI)
        let messageToSend = text.isEmpty ? text : settings.applyThinkingMode(to: text)

        // If we have an image, send it with the message
        if let imageData = imageToSend {
            // Send message with image data directly via WebSocket
            wsManager.sendMessage(
                text.isEmpty ? "What is this image?" : messageToSend,
                projectPath: project.path,
                resumeSessionId: selectedSession?.id,
                permissionMode: settings.effectivePermissionMode,
                imageData: imageData,
                model: effectiveModelId
            )
        } else {
            // No image - just send text
            wsManager.sendMessage(
                messageToSend,
                projectPath: project.path,
                resumeSessionId: selectedSession?.id,
                permissionMode: settings.effectivePermissionMode,
                model: effectiveModelId
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

    // MARK: - Git Sync Handling

    /// Handle git status when view loads
    private func handleGitStatusOnLoad() {
        Task {
            switch gitStatus {
            case .behind:
                // Auto-pull for clean projects that are behind
                await performAutoPull()

            case .dirty, .dirtyAndAhead, .diverged:
                // Show banner and optionally auto-prompt Claude
                if !hasPromptedCleanup && messages.isEmpty {
                    // Only auto-prompt if this is a fresh session
                    // User can tap the banner to ask Claude later
                }

            default:
                // Hide banner for clean/unknown/notGitRepo
                if gitStatus == .clean || gitStatus == .notGitRepo {
                    showGitBanner = false
                }
            }
        }
    }

    /// Refresh git status for this project
    private func refreshGitStatus() {
        Task {
            gitStatus = .checking
            let newStatus = await sshManager.checkGitStatusWithAutoConnect(
                project.path,
                settings: settings
            )
            await MainActor.run {
                gitStatus = newStatus

                // Hide banner if now clean
                if newStatus == .clean || newStatus == .notGitRepo {
                    showGitBanner = false
                } else {
                    // Show banner for any actionable status
                    showGitBanner = true
                }
            }
        }
    }

    /// Perform auto-pull for projects that are behind remote
    private func performAutoPull() async {
        isAutoPulling = true

        let success = await sshManager.gitPullWithAutoConnect(project.path, settings: settings)

        await MainActor.run {
            isAutoPulling = false
            if success {
                // Update status to clean after successful pull
                gitStatus = .clean
                showGitBanner = false

                // Add system message about the pull
                messages.append(ChatMessage(
                    role: .system,
                    content: "✓ Auto-pulled latest changes from remote",
                    timestamp: Date()
                ))
            } else {
                // Show error in banner
                gitStatus = .error("Auto-pull failed")
            }
        }
    }

    /// Send a message to Claude asking to help with local changes
    private func promptClaudeForCleanup() {
        hasPromptedCleanup = true

        let cleanupPrompt: String
        switch gitStatus {
        case .dirty:
            cleanupPrompt = """
            There are uncommitted changes in this project. Please run `git status` and `git diff` to review the changes, then help me decide how to handle them. Options might include:
            - Committing the changes with an appropriate message
            - Stashing them for later
            - Discarding them if they're not needed
            """

        case .ahead(let count):
            cleanupPrompt = """
            This project has \(count) unpushed commit\(count == 1 ? "" : "s"). Please run `git log --oneline @{upstream}..HEAD` to show me what commits need to be pushed, then help me decide whether to push them now.
            """

        case .dirtyAndAhead:
            cleanupPrompt = """
            This project has both uncommitted changes AND unpushed commits. Please:
            1. Run `git status` to show uncommitted changes
            2. Run `git log --oneline @{upstream}..HEAD` to show unpushed commits
            3. Help me decide how to handle both - whether to commit, stash, push, or discard.
            """

        case .diverged:
            cleanupPrompt = """
            This project has diverged from the remote - there are both local and remote changes. Please:
            1. Run `git status` to show the current state
            2. Run `git log --oneline HEAD...@{upstream}` to show the divergence
            3. Help me resolve this - we may need to rebase or merge.
            """

        default:
            return
        }

        // Add user message
        let userMessage = ChatMessage(role: .user, content: cleanupPrompt, timestamp: Date())
        messages.append(userMessage)

        // Hide banner after adding message to avoid layout shift during scroll
        showGitBanner = false

        // Send to Claude
        wsManager.sendMessage(
            cleanupPrompt,
            projectPath: project.path,
            resumeSessionId: selectedSession?.id,
            permissionMode: settings.effectivePermissionMode,
            model: effectiveModelId
        )
        processingStartTime = Date()

        // Trigger scroll to bottom after a brief delay to let layout settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            scrollToBottomTrigger = true
        }
    }

    // MARK: - Model Selection

    private func switchToModel(_ model: ClaudeModel, customId: String? = nil) {
        // Just update local state - model is passed with each message
        currentModel = model
        if model == .custom, let customId = customId {
            self.customModelId = customId
            settings.customModelId = customId
        }
    }

    /// Get the model ID to pass in WebSocket messages
    private var effectiveModelId: String? {
        let model = currentModel ?? settings.defaultModel
        switch model {
        case .opus:
            return "claude-opus-4-5-20251101"
        case .sonnet:
            return "claude-sonnet-4-5-20250929"
        case .haiku:
            return "claude-3-5-haiku-20241022"
        case .custom:
            return customModelId.isEmpty ? nil : customModelId
        }
    }
}

// MARK: - Custom Model Picker Sheet

struct CustomModelPickerSheet: View {
    @Binding var customModelId: String
    let onConfirm: (String) -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Enter a custom model ID")
                    .font(CLITheme.monoFont)
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))

                TextField("e.g., claude-opus-4-5-20251101", text: $customModelId)
                    .font(CLITheme.monoFont)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                Text("Examples:\n• claude-opus-4-5-20251101\n• claude-sonnet-4-5-20250929\n• claude-sonnet-4-5-20250929[1m]")
                    .font(CLITheme.monoSmall)
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding()
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Custom Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Switch") { onConfirm(customModelId) }
                        .disabled(customModelId.isEmpty)
                }
            }
        }
    }
}

// MARK: - Git Sync Banner

struct GitSyncBanner: View {
    let status: GitStatus
    let isAutoPulling: Bool
    let isRefreshing: Bool
    let onDismiss: () -> Void
    let onRefresh: () -> Void
    let onPull: (() -> Void)?
    let onAskClaude: (() -> Void)?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            // Status icon
            if isAutoPulling || isRefreshing {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: status.icon)
                    .foregroundColor(iconColor)
            }

            // Status text
            VStack(alignment: .leading, spacing: 2) {
                Text(isRefreshing ? "Checking..." : statusTitle)
                    .font(CLITheme.monoSmall)
                    .fontWeight(.medium)
                    .foregroundColor(CLITheme.primaryText(for: colorScheme))

                Text(isRefreshing ? "Refreshing git status" : statusSubtitle)
                    .font(.caption)
                    .foregroundColor(CLITheme.secondaryText(for: colorScheme))
            }

            Spacer()

            // Actions
            if !isAutoPulling && !isRefreshing {
                // Pull button (for behind status)
                if let onPull = onPull {
                    Button {
                        onPull()
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 16))
                            .foregroundColor(CLITheme.cyan(for: colorScheme))
                    }
                    .accessibilityLabel("Pull changes")
                }

                // Refresh button
                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                }
                .accessibilityLabel("Refresh git status")

                if let onAskClaude = onAskClaude {
                    Button {
                        onAskClaude()
                    } label: {
                        Text("Ask Claude")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(CLITheme.cyan(for: colorScheme).opacity(0.2))
                            .foregroundColor(CLITheme.cyan(for: colorScheme))
                            .cornerRadius(6)
                    }
                }
            }

            // Dismiss button
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(bannerBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.accessibilityLabel)
    }

    private var iconColor: Color {
        switch status.colorName {
        case "green":
            return CLITheme.green(for: colorScheme)
        case "orange":
            return CLITheme.yellow(for: colorScheme)
        case "blue":
            return CLITheme.blue(for: colorScheme)
        case "cyan":
            return CLITheme.cyan(for: colorScheme)
        case "red":
            return CLITheme.red(for: colorScheme)
        default:
            return CLITheme.mutedText(for: colorScheme)
        }
    }

    private var bannerBackground: Color {
        switch status {
        case .dirty, .dirtyAndAhead, .diverged:
            return CLITheme.yellow(for: colorScheme).opacity(0.1)
        case .behind:
            return CLITheme.cyan(for: colorScheme).opacity(0.1)
        case .ahead:
            return CLITheme.blue(for: colorScheme).opacity(0.1)
        case .error:
            return CLITheme.red(for: colorScheme).opacity(0.1)
        default:
            return CLITheme.secondaryBackground(for: colorScheme)
        }
    }

    private var statusTitle: String {
        if isAutoPulling {
            return "Pulling latest changes..."
        }

        switch status {
        case .dirty:
            return "Uncommitted changes"
        case .ahead(let count):
            return "\(count) unpushed commit\(count == 1 ? "" : "s")"
        case .behind(let count):
            return "\(count) commit\(count == 1 ? "" : "s") behind"
        case .dirtyAndAhead:
            return "Local changes + unpushed commits"
        case .diverged:
            return "Diverged from remote"
        case .error(let msg):
            return "Error: \(msg)"
        default:
            return ""
        }
    }

    private var statusSubtitle: String {
        if isAutoPulling {
            return "Auto-syncing with remote..."
        }

        switch status {
        case .dirty, .dirtyAndAhead, .diverged:
            return "Tap 'Ask Claude' to review and resolve"
        case .ahead:
            return "Push your commits to sync with remote"
        case .behind:
            return "Will auto-pull when ready"
        case .error:
            return "Check your connection"
        default:
            return ""
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
                    // Keyboard Shortcuts section
                    Text("Keyboard Shortcuts")
                        .font(.headline)
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))

                    VStack(alignment: .leading, spacing: 12) {
                        KeyboardShortcutRow(shortcut: "⌘ Return", description: "Send message")
                        KeyboardShortcutRow(shortcut: "⌘ K", description: "Clear conversation")
                        KeyboardShortcutRow(shortcut: "⌘ N", description: "New session")
                        KeyboardShortcutRow(shortcut: "⌘ .", description: "Abort current request")
                        KeyboardShortcutRow(shortcut: "⌘ /", description: "Show this help")
                        KeyboardShortcutRow(shortcut: "⌘ R", description: "Resume session picker")
                    }

                    Divider()
                        .padding(.vertical, 8)

                    // Slash Commands section
                    Text("Slash Commands")
                        .font(.headline)
                        .foregroundColor(CLITheme.primaryText(for: colorScheme))

                    VStack(alignment: .leading, spacing: 12) {
                        SlashCommandRow(command: "/clear", description: "Clear conversation and start fresh")
                        SlashCommandRow(command: "/new", description: "Start a new session")
                        SlashCommandRow(command: "/init", description: "Create/modify CLAUDE.md (via Claude)")
                        SlashCommandRow(command: "/resume", description: "Resume a previous session")
                        SlashCommandRow(command: "/compact", description: "Compact conversation to save context")
                        SlashCommandRow(command: "/status", description: "Show connection and session info")
                        SlashCommandRow(command: "/exit", description: "Close chat and return to projects")
                        SlashCommandRow(command: "/help", description: "Show this help")
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
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape)
                }
            }
        }
    }
}

struct KeyboardShortcutRow: View {
    let shortcut: String
    let description: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(CLITheme.yellow(for: colorScheme))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(CLITheme.secondaryBackground(for: colorScheme))
                .cornerRadius(6)

            Text(description)
                .font(.subheadline)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

private struct SlashCommandRow: View {
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
