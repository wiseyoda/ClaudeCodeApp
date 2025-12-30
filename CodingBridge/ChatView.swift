import SwiftUI
import UIKit
import PhotosUI

// MARK: - ChatView

struct ChatView: View {
    // MARK: - Properties
    let project: Project
    let initialGitStatus: GitStatus
    var onSessionsChanged: (() -> Void)?

    // MARK: - Environment
    @EnvironmentObject var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Managers (StateObject/ObservedObject)
    // wsManager is CLIBridgeAdapter - provides WebSocket-style interface to cli-bridge backend
    @StateObject private var wsManager: CLIBridgeAdapter
    @StateObject private var claudeHelper: ClaudeHelper
    @StateObject private var ideasStore: IdeasStore
    @StateObject private var scrollManager = ScrollStateManager()
    @ObservedObject private var sessionStore = SessionStore.shared
    @ObservedObject private var projectSettingsStore = ProjectSettingsStore.shared

    // MARK: - Chat State (messages, input, session)
    /// iOS 26+: Migrate to @IncrementalState for better List performance with large message lists
    /// Add `.incrementalID()` modifier to CLIMessageView using `message.id`
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var selectedImages: [ImageAttachment] = []
    @State private var processingStartTime: Date?
    @State private var selectedSession: ProjectSession?
    @State private var isUploadingImage = false
    @State private var isLoadingHistory = false
    @State private var scrollToBottomTrigger = false

    // MARK: - Streaming Message Cache (prevents view thrashing during streaming)
    @State private var streamingMessageId = UUID()
    @State private var streamingMessageTimestamp = Date()

    // MARK: - Tool Use Tracking (maps tool_use_id to tool name for result filtering)
    @State private var toolUseMap: [String: String] = [:]
    /// Tool IDs created while a subagent was active - results for these should be filtered
    @State private var subagentToolIds: Set<String> = []

    // MARK: - Search State
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var messageFilter: MessageFilter = .all

    // MARK: - Git State
    @State private var gitStatus: GitStatus = .unknown
    @State private var isAutoPulling = false
    @State private var showGitBanner = true
    @State private var hasPromptedCleanup = false
    @State private var gitRefreshTask: Task<Void, Never>?

    // MARK: - Model State
    @State private var showingModelPicker = false
    @State private var currentModel: ClaudeModel?
    @State private var customModelId = ""

    // MARK: - Sheet State
    @State private var showingHelpSheet = false
    @State private var showingSessionPicker = false
    @State private var showingBookmarks = false
    @State private var showIdeasDrawer = false
    @State private var showQuickCapture = false
    @State private var showQuickSettings = false

    // MARK: - Todo Progress Drawer State
    @State private var currentTodos: [TodoListView.TodoItem] = []
    @State private var isTodoDrawerExpanded = false
    @State private var showTodoDrawer = false
    @State private var todoHideTimer: Task<Void, Never>?

    // MARK: - Scroll State
    @FocusState private var isInputFocused: Bool

    // MARK: - Background Tasks
    @State private var disconnectTask: Task<Void, Never>?
    @State private var analyzeTask: Task<Void, Never>?
    @State private var saveDebounceTask: Task<Void, Never>?
    @State private var draftDebounceTask: Task<Void, Never>?

    // MARK: - Display Messages Cache (prevents recomputation on every render)
    @State private var cachedDisplayMessages: [ChatMessage] = []
    @State private var displayMessagesInvalidationKey: Int = 0

    init(project: Project, initialGitStatus: GitStatus = .unknown, onSessionsChanged: (() -> Void)? = nil) {
        self.project = project
        self.initialGitStatus = initialGitStatus
        self.onSessionsChanged = onSessionsChanged
        // Initialize CLIBridgeAdapter (cli-bridge backend) - will be configured in onAppear
        _wsManager = StateObject(wrappedValue: CLIBridgeAdapter())
        _claudeHelper = StateObject(wrappedValue: ClaudeHelper(settings: AppSettings()))
        _ideasStore = StateObject(wrappedValue: IdeasStore(projectPath: project.path))
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
        // iOS 26+: Toolbar will automatically adopt Liquid Glass styling
        // Using Material for glass-compatible background on iOS 17-25
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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
                    .accessibilityLabel("Git status")
                    .accessibilityHint("Tap to refresh git status")
                    .accessibilityValue(gitStatus.accessibilityLabel)
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

                    // Ideas button
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "lightbulb")
                            .foregroundColor(CLITheme.secondaryText(for: colorScheme))
                        // Badge for idea count
                        if ideasStore.ideas.count > 0 {
                            Text(ideasStore.ideas.count > 99 ? "99+" : "\(ideasStore.ideas.count)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(CLITheme.red(for: colorScheme))
                                .clipShape(Capsule())
                                .offset(x: 8, y: -8)
                        }
                    }
                    .onTapGesture {
                        showIdeasDrawer = true
                    }
                    .onLongPressGesture(minimumDuration: 0.4) {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        showQuickCapture = true
                    }
                    .accessibilityLabel("Ideas")
                    .accessibilityHint("Tap to open ideas drawer, hold to quick capture")
                    .accessibilityValue(ideasStore.ideas.count > 0 ? "\(ideasStore.ideas.count) ideas" : "No ideas")

                    // More options menu
                    Menu {
                        Button {
                            startNewSession()
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
            // Cancel any pending disconnect (handles NavigationSplitView recreations)
            disconnectTask?.cancel()
            disconnectTask = nil

            // Configure SessionStore with settings (idempotent)
            sessionStore.configure(with: settings)

            // Update managers with actual EnvironmentObject settings
            wsManager.updateSettings(settings)
            claudeHelper.updateSettings(settings)
            setupWebSocketCallbacks()

            // Start health monitoring for status bar
            HealthMonitorService.shared.configure(serverURL: settings.serverURL)
            HealthMonitorService.shared.startPolling()

            // Check if we were processing when app closed (for reattachment)
            let wasProcessing = MessageStore.loadProcessingState(for: project.path)

            // Load persisted messages as temporary content while history loads
            // Don't trigger scroll here - loadSessionHistory will handle scrolling
            Task {
                let savedMessages = await MessageStore.loadMessages(for: project.path)
                if !savedMessages.isEmpty {
                    messages = savedMessages
                    refreshDisplayMessagesCache()
                } else {
                    refreshDisplayMessagesCache()
                }
            }

            // Load sessions from API, then select most recent and connect
            Task {
                // Load sessions first
                await sessionStore.loadSessions(for: project.path, forceRefresh: true)

                await MainActor.run {
                    // Select session (pre-selected from navigation, or auto-select most recent)
                    selectInitialSession()

                    // Connect based on selected session
                    if let session = selectedSession {
                        print("[ChatView] Opening project with session: \(session.id.prefix(8))...")
                        wsManager.sessionId = session.id
                        wsManager.connect(projectPath: project.path, sessionId: session.id)
                        MessageStore.saveSessionId(session.id, for: project.path)
                        loadSessionHistory(session)

                        // Check if we need to reattach to an active session
                        if wasProcessing {
                            print("[ChatView] Session was processing when app closed - attempting reattachment...")
                            attemptSessionReattachment(sessionId: session.id)
                        }
                    } else {
                        // No sessions exist - connect without sessionId
                        // cli-bridge will create a new session on first message
                        print("[ChatView] No sessions found for project - connecting without session")
                        wsManager.connect(projectPath: project.path)
                        if wasProcessing {
                            MessageStore.clearProcessingState(for: project.path)
                        }
                    }
                }
            }

            // Load draft input
            let savedDraft = MessageStore.loadDraft(for: project.path)
            if !savedDraft.isEmpty {
                inputText = savedDraft
            }

            // Handle git status from ContentView
            gitStatus = initialGitStatus
            handleGitStatusOnLoad()

            // Initialize model state
            customModelId = settings.customModelId

            // Start periodic git status refresh task (every 30 seconds)
            gitRefreshTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 30_000_000_000)  // 30 seconds
                    guard !Task.isCancelled else { break }
                    await MainActor.run {
                        refreshGitStatus()
                    }
                }
            }
        }
        .onDisappear {
            // Cancel debounce and save messages/draft immediately when leaving
            saveDebounceTask?.cancel()
            saveDebounceTask = nil
            draftDebounceTask?.cancel()
            draftDebounceTask = nil
            MessageStore.saveMessages(messages, for: project.path, maxMessages: settings.historyLimit.rawValue)
            MessageStore.saveDraft(inputText, for: project.path)

            // Cancel git refresh task
            gitRefreshTask?.cancel()
            gitRefreshTask = nil

            // Cancel any running message analysis
            analyzeTask?.cancel()
            analyzeTask = nil

            // Delay disconnect to handle NavigationSplitView layout recreations
            // If onAppear is called again quickly, the disconnect will be cancelled
            disconnectTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms delay
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    wsManager.disconnect()
                }
            }
        }
        .onChange(of: messages) { _, newMessages in
            // Debounce save to avoid excessive file I/O during streaming
            // UI cache refreshes immediately, but file save waits 500ms for batching
            saveDebounceTask?.cancel()
            let projectPath = project.path
            let maxMessages = settings.historyLimit.rawValue
            saveDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms debounce
                guard !Task.isCancelled else { return }
                MessageStore.saveMessages(newMessages, for: projectPath, maxMessages: maxMessages)
            }
            // Refresh display messages cache immediately for responsive UI
            refreshDisplayMessagesCache()
        }
        .onChange(of: searchText) { _, _ in
            // Refresh display messages cache when search changes
            refreshDisplayMessagesCache()
        }
        .onChange(of: messageFilter) { _, _ in
            // Refresh display messages cache when filter changes
            refreshDisplayMessagesCache()
        }
        .onChange(of: settings.defaultModel) { oldModel, newModel in
            // When user changes model in UI, send setModel command to cli-bridge
            guard oldModel != newModel else { return }
            guard wsManager.connectionState.isConnected else { return }
            print("[ChatView] Model changed from \(oldModel.shortName) to \(newModel.shortName) - calling switchModel")
            wsManager.switchModel(to: newModel)
        }
        .onChange(of: inputText) { _, newText in
            // Debounce draft saving to avoid disk I/O on every keystroke (causes keyboard lag)
            draftDebounceTask?.cancel()
            let projectPath = project.path
            draftDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms debounce
                guard !Task.isCancelled else { return }
                MessageStore.saveDraft(newText, for: projectPath)
            }

            // Clear suggestions when user starts typing (lightweight, no debounce needed)
            if !newText.isEmpty && !claudeHelper.suggestedActions.isEmpty {
                claudeHelper.clearSuggestions()
            }
        }
        .onChange(of: wsManager.isProcessing) { oldValue, isProcessing in
            // Save processing state for session recovery on app restart
            MessageStore.saveProcessingState(isProcessing, for: project.path)

            // Reset streaming message cache when new streaming session starts
            if isProcessing && !oldValue {
                streamingMessageId = UUID()
                streamingMessageTimestamp = Date()
            }

            // Refocus input when processing completes (not on initial connection)
            // oldValue check prevents focus during .starting → .idle connection transition
            if oldValue && !isProcessing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInputFocused = true
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // App came to foreground - reconnect if disconnected
                // Note: isAppInForeground now reads from BackgroundManager
                if !wsManager.isConnected {
                    log.debug("[ChatView] App active - reconnecting WebSocket")
                    wsManager.connect()
                }
            case .inactive:
                // App is inactive (transitioning)
                break
            case .background:
                // App went to background
                // Note: BackgroundManager handles isAppInBackground state
                break
            @unknown default:
                break
            }
        }
        .sheet(item: $wsManager.pendingQuestion) { questionData in
            userQuestionsSheet(questionData)
        }
        .sheet(isPresented: $showingHelpSheet) {
            SlashCommandHelpSheet()
        }
        .sheet(isPresented: $showingSessionPicker) {
            SessionPickerSheet(
                project: project,
                sessions: localSessionsBinding,
                onSelect: { session in
                    showingSessionPicker = false
                    selectedSession = session
                    wsManager.sessionId = session.id
                    MessageStore.saveSessionId(session.id, for: project.path)
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
        .sheet(isPresented: $showIdeasDrawer) {
            IdeasDrawerSheet(
                isPresented: $showIdeasDrawer,
                ideasStore: ideasStore,
                claudeHelper: claudeHelper,
                projectPath: project.path,
                currentSessionId: wsManager.sessionId,
                onSendIdea: { idea in
                    appendToInput(idea.formattedPrompt)
                }
            )
        }
        .sheet(isPresented: $showQuickCapture) {
            QuickCaptureSheet(isPresented: $showQuickCapture) { text in
                ideasStore.quickAdd(text)
            }
        }
        .onAppear {
            // Initialize sessions via API (SessionStore is single source of truth)
            if !sessionStore.hasLoaded(for: project.path) {
                // Pre-populate with project.sessions as temporary fallback while API loads
                if localSessions.isEmpty {
                    for session in project.sessions ?? [] {
                        sessionStore.addSession(session, for: project.path)
                    }
                }
                // Load all sessions via API in background
                Task {
                    await sessionStore.loadSessions(for: project.path, forceRefresh: true)
                }
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
                HapticManager.rigid()
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
    private func userQuestionsSheet(_ questionData: AskUserQuestionData) -> some View {
        // Use a StateObject wrapper to hold the mutable question data
        // This avoids binding issues that can cause the sheet to freeze
        UserQuestionsSheetWrapper(
            initialData: questionData,
            onSubmit: { answeredData in
                handleQuestionAnswer(answeredData)
            },
            onCancel: {
                handleQuestionCancel()
            }
        )
    }

    /// Handle submission of question answers
    private func handleQuestionAnswer(_ questionData: AskUserQuestionData) {
        // Add user's formatted answer to chat for display
        let answerMessage = ChatMessage(
            role: .user,
            content: questionData.formatAnswers(),
            timestamp: Date()
        )
        messages.append(answerMessage)

        // Send the structured answers back to cli-bridge
        // This uses the request ID from the server and formats answers as a dict
        wsManager.respondToQuestion(
            requestId: questionData.requestId,
            answers: questionData.answersDict()
        )
        processingStartTime = Date()
    }

    /// Handle cancellation of question dialog
    private func handleQuestionCancel() {
        wsManager.abortSession()
        wsManager.clearPendingQuestion()
    }

    /// Compute session ID to resume, filtering out ephemeral sessions
    /// Returns wsManager.sessionId if set, otherwise selectedSession.id if it's a real session
    private var effectiveSessionToResume: String? {
        // If wsManager has a session ID, use it (it's always a real session)
        if let sessionId = wsManager.sessionId {
            return sessionId
        }

        // Fall back to selected session, but filter out ephemeral sessions
        if let session = selectedSession {
            // Ephemeral sessions have IDs starting with "new-session-"
            if session.id.hasPrefix("new-session-") {
                return nil  // Don't pass ephemeral ID to cli-bridge
            }
            return session.id
        }

        return nil
    }

    // MARK: - View Components (extracted to help Swift compiler)

    /// Sessions from SessionStore (single source of truth)
    private var localSessions: [ProjectSession] {
        sessionStore.sessions(for: project.path)
    }

    /// Binding for SessionPicker views
    private var localSessionsBinding: Binding<[ProjectSession]> {
        Binding(
            get: { sessionStore.sessions(for: project.path) },
            set: { _ in /* Updates go through SessionStore methods */ }
        )
    }

    /// Combined sessions list - SessionStore as single source of truth
    /// Only falls back to project.sessions before API has loaded
    /// Returns filtered sessions (excludes helper sessions)
    private var sessions: [ProjectSession] {
        let activeId = wsManager.sessionId
        // If we've loaded from API, always use SessionStore (even if empty = all deleted)
        if sessionStore.hasLoaded(for: project.path) {
            return localSessions.filterForDisplay(projectPath: project.path, activeSessionId: activeId)
        }
        // Before API loads, use project data as fallback
        let baseSessions = localSessions.isEmpty ? (project.sessions ?? []) : localSessions
        return baseSessions.filterForDisplay(projectPath: project.path, activeSessionId: activeId)
    }

    @ViewBuilder
    private var sessionPickerView: some View {
        SessionBar(
            project: project,
            sessions: localSessionsBinding,
            selected: $selectedSession,
            isLoading: isLoadingHistory,
            isProcessing: wsManager.isProcessing,
            activeSessionId: wsManager.sessionId,
            onSelect: { session in
                wsManager.sessionId = session.id
                MessageStore.saveSessionId(session.id, for: project.path)
                loadSessionHistory(session)
            },
            onNew: {
                startNewSession()
            },
            onDelete: { session in
                Task {
                    await deleteSession(session)
                }
            }
        )
    }

    /// Start a completely new session - creates ephemeral "New Session" placeholder
    /// The actual session is created in cli-bridge when the user sends their first message
    private func startNewSession() {
        messages = []
        wsManager.sessionId = nil  // Clear so cli-bridge creates new session on first input
        scrollManager.reset()  // Reset scroll state for fresh session
        MessageStore.clearMessages(for: project.path)
        MessageStore.clearSessionId(for: project.path)

        // Create ephemeral "New Session" placeholder (not persisted until first message)
        let ephemeralSession = ProjectSession(
            id: "new-session-\(UUID().uuidString)",  // Temporary ID, will be replaced
            summary: "New Session",
            messageCount: 0,
            lastActivity: ISO8601DateFormatter().string(from: Date()),
            lastUserMessage: nil,
            lastAssistantMessage: nil
        )
        selectedSession = ephemeralSession

        // Add welcome message for new session
        let welcomeMessage = ChatMessage(
            role: .system,
            content: "New session started. How can I help you?",
            timestamp: Date()
        )
        messages.append(welcomeMessage)
        refreshDisplayMessagesCache()
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
                    onCommit: { promptClaudeForCommit() },
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
                    onCommit: nil,
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
                    onCommit: { promptClaudeForPush() },
                    onAskClaude: { promptClaudeForCleanup() }
                )

            default:
                EmptyView()
            }
        }
    }

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            GeometryReader { outerGeometry in
                ZStack(alignment: .bottom) {
                    ScrollView {
                        messagesListView
                            .background(
                                GeometryReader { contentGeometry in
                                    Color.clear
                                        .preference(
                                            key: ContentSizePreferenceKey.self,
                                            value: contentGeometry.size
                                        )
                                        // Track scroll offset for user scroll detection
                                        .preference(
                                            key: ScrollOffsetPreferenceKey.self,
                                            value: contentGeometry.frame(in: .named("chatScroll")).minY
                                        )
                                }
                            )
                    }
                    .coordinateSpace(name: "chatScroll")
                    .scrollDismissesKeyboard(.interactively)
                    .background(CLITheme.background(for: colorScheme))
                    // Pull-to-refresh: reload session history and git status
                    .refreshable {
                        await refreshChatContent()
                    }
                    // Detect user scrolling - uses debounced handler to prevent UI freezes
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                        // Use debounced handler to avoid rapid state updates during scrolling
                        scrollManager.handleScrollOffset(offset)
                    }
                    // Track content size for at-bottom calculation and auto-scroll
                    .onPreferenceChange(ContentSizePreferenceKey.self) { contentSize in
                        // Update scroll dimensions for at-bottom calculation
                        scrollManager.updateScrollDimensions(
                            contentHeight: contentSize.height,
                            viewportHeight: outerGeometry.size.height
                        )
                        // Request scroll when content grows (if auto-scroll enabled)
                        if contentSize.height > outerGeometry.size.height && settings.autoScrollEnabled {
                            scrollManager.requestScrollToBottom()
                        }
                    }
                    // Record user scroll activity to distinguish from content growth
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { _ in
                                scrollManager.recordUserScrollGesture()
                                // Dismiss keyboard when user scrolls
                                isInputFocused = false
                            }
                    )
                    // Scroll to bottom button - appears when user has scrolled up
                    if !scrollManager.isAutoScrollEnabled {
                        Button {
                            scrollManager.forceScrollToBottom()
                        } label: {
                            Image(systemName: "chevron.compact.down")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(CLITheme.primaryText(for: colorScheme).opacity(0.6))
                        }
                        .padding(.bottom, 16)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.15), value: scrollManager.isAutoScrollEnabled)
                    }
                }
                // Unified scroll trigger - responds to scrollManager.shouldScroll
                .onChange(of: scrollManager.shouldScroll) { _, shouldScroll in
                    if shouldScroll {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("bottomAnchor", anchor: .bottom)
                        }
                    }
                }
                // Consolidated scroll triggers - all go through scrollManager for debouncing
                // Removed currentText.count handler to prevent scroll jitter during streaming
                .onChange(of: messages.count) { _, _ in
                    guard settings.autoScrollEnabled else { return }
                    scrollManager.requestScrollToBottom()
                }
                .onChange(of: wsManager.isProcessing) { _, isProcessing in
                    guard settings.autoScrollEnabled else { return }
                    // Scroll when processing starts or ends
                    scrollManager.requestScrollToBottom()
                }
                // Handle explicit scroll trigger (loading history, etc.)
                .onChange(of: scrollToBottomTrigger) { _, shouldScroll in
                    if shouldScroll {
                        // Force scroll bypasses user intent tracking
                        scrollManager.forceScrollToBottom()
                        scrollToBottomTrigger = false
                    }
                }
                .onAppear {
                    // Only scroll on appear if not loading history (history load handles its own scroll)
                    guard !isLoadingHistory else { return }
                    // Brief delay to ensure view layout settles before scrolling
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrollManager.forceScrollToBottom()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                    // Keep scroll at bottom after rotation if auto-scroll is enabled
                    if scrollManager.isAutoScrollEnabled {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            scrollManager.forceScrollToBottom()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .backgroundRecoveryNeeded)) { notification in
                    // Recover from background processing
                    guard let userInfo = notification.userInfo,
                          let sessionId = userInfo["sessionId"] as? String,
                          let projectPath = userInfo["projectPath"] as? String,
                          projectPath == project.path else {
                        return
                    }
                    log.info("Background recovery requested for session: \(sessionId.prefix(8))...")
                    wsManager.recoverFromBackground(sessionId: sessionId, projectPath: projectPath)
                }
            }
        }
    }

    /// Messages filtered based on search, filter, and user settings.
    /// Uses cached result to avoid recomputation on every render during scrolling.
    private var displayMessages: [ChatMessage] {
        // Return cached value - cache is invalidated by onChange handlers
        cachedDisplayMessages
    }

    /// Grouped display items for compact tool rendering.
    /// Groups consecutive Read/Glob/Grep into "Explored" rows and merges Bash with its result.
    private var groupedDisplayItems: [DisplayItem] {
        groupMessagesForDisplay(displayMessages)
    }

    /// Compute the current invalidation key based on filter dependencies.
    /// When this changes, the cache needs to be refreshed.
    private var currentDisplayMessagesKey: Int {
        var hasher = Hasher()
        hasher.combine(messages.count)
        hasher.combine(messages.last?.id)
        hasher.combine(messages.last?.content.count)  // Detect content updates
        hasher.combine(searchText)
        hasher.combine(messageFilter)
        hasher.combine(settings.showThinkingBlocks)
        return hasher.finalize()
    }

    /// Refresh the cached display messages when dependencies change.
    private func refreshDisplayMessagesCache() {
        let newKey = currentDisplayMessagesKey
        guard newKey != displayMessagesInvalidationKey else { return }
        displayMessagesInvalidationKey = newKey
        cachedDisplayMessages = computeDisplayMessages()
    }

    /// Compute filtered messages (called only when cache is invalidated).
    private func computeDisplayMessages() -> [ChatMessage] {
        var filtered = messages

        // Filter out ClaudeHelper internal prompts (suggestions, file hints, idea enhancement)
        filtered = filtered.filter { !isClaudeHelperPrompt($0.content) }

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

    /// Check if a message is a ClaudeHelper internal prompt or response that should be hidden
    private func isClaudeHelperPrompt(_ content: String) -> Bool {
        // User prompts from ClaudeHelper
        let helperPrefixes = [
            "Based on this conversation context, suggest",
            "Based on this conversation, which files would be most relevant",
            "You are helping a developer expand a quick idea into an actionable prompt",
            "Analyze this Claude Code response and suggest"
        ]
        if helperPrefixes.contains(where: { content.hasPrefix($0) }) {
            return true
        }

        // JSON responses from ClaudeHelper (suggestions array or enhanced idea object)
        // Handle both compact and pretty-printed JSON, and markdown code blocks
        var trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown code fence if present (```json ... ```)
        if trimmed.hasPrefix("```") {
            // Remove opening fence (```json or ```)
            if let firstNewline = trimmed.firstIndex(of: "\n") {
                trimmed = String(trimmed[trimmed.index(after: firstNewline)...])
            }
            // Remove closing fence
            if trimmed.hasSuffix("```") {
                trimmed = String(trimmed.dropLast(3))
            }
            trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Suggestions array: starts with [ and contains "label" and "prompt"
        if trimmed.hasPrefix("[") && trimmed.contains("\"label\"") && trimmed.contains("\"prompt\"") {
            return true
        }

        // Enhanced idea object: starts with { and contains "expandedPrompt"
        if trimmed.hasPrefix("{") && trimmed.contains("\"expandedPrompt\"") {
            return true
        }

        return false
    }

    private var messagesListView: some View {
        // Use regular VStack for smooth scrolling - all messages are already loaded
        // LazyVStack causes jitter due to height estimation on variable-content cells
        VStack(alignment: .leading, spacing: 2) {
            ForEach(groupedDisplayItems) { item in
                DisplayItemView(
                    item: item,
                    projectPath: project.path,
                    projectTitle: project.title,
                    onAnalyze: handleAnalyze,
                    hideTodoInline: showTodoDrawer
                )
                .id(item.id)
            }

            if wsManager.isProcessing {
                streamingIndicatorView
            }

            // Bottom anchor for scrollTo target
            Spacer()
                .frame(height: 1)
                .id("bottomAnchor")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// Handle analyze action - extracted to avoid closure recreation on every render
    private func handleAnalyze(_ msg: ChatMessage) {
        analyzeTask?.cancel()
        analyzeTask = Task {
            guard !Task.isCancelled else { return }
            await claudeHelper.analyzeMessage(
                msg,
                recentMessages: messages,
                projectPath: project.path,
                sessionId: wsManager.sessionId
            )
        }
    }

    @ViewBuilder
    private var streamingIndicatorView: some View {
        if wsManager.isReattaching {
            // Show reattaching indicator when reconnecting to active session
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Reconnecting to session...")
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                Spacer()
            }
            .font(settings.scaledFont(.body))
            .padding(.vertical, 4)
            .id("reattaching")
        } else if wsManager.currentText.isEmpty {
            // Minimal waiting indicator - status bar already shows processing state
            HStack(spacing: 6) {
                Text("+")
                    .foregroundColor(CLITheme.yellow(for: colorScheme))
                Text("...")
                    .foregroundColor(CLITheme.mutedText(for: colorScheme))
                Spacer()
            }
            .font(settings.scaledFont(.body))
            .padding(.vertical, 4)
            .id("streaming")
        } else {
            // Use cached ID and timestamp to prevent view thrashing during streaming
            // The message struct is still recreated, but with stable identity
            CLIMessageView(
                message: ChatMessage(
                    id: streamingMessageId,
                    role: .assistant,
                    content: wsManager.currentText,
                    timestamp: streamingMessageTimestamp,
                    isStreaming: true
                ),
                projectPath: project.path,
                projectTitle: project.title
            )
            .id(streamingMessageId)  // Stable ID prevents LazyVStack recalculation
        }
    }

    private var statusAndInputView: some View {
        VStack(spacing: 0) {
            // Banners appear ABOVE the status bar for better visibility

            // Todo progress drawer (floating, collapsible, shows during streaming)
            if showTodoDrawer && !currentTodos.isEmpty {
                TodoProgressDrawer(
                    todos: currentTodos,
                    isExpanded: $isTodoDrawerExpanded
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }

            // Permission approval banner (shown when bypass permissions is OFF and approval needed)
            if let approval = wsManager.pendingApproval {
                ApprovalBannerView(
                    request: approval,
                    onApprove: {
                        wsManager.approvePendingRequest(alwaysAllow: false)
                    },
                    onAlwaysAllow: {
                        wsManager.approvePendingRequest(alwaysAllow: true)
                    },
                    onDeny: {
                        wsManager.denyPendingRequest()
                    }
                )
            }

            // Input queued banner (shown when input is queued while agent is busy)
            if wsManager.isInputQueued {
                InputQueuedBanner(
                    position: wsManager.queuePosition,
                    onCancel: {
                        wsManager.cancelQueuedInput()
                    }
                )
            }

            // Subagent banner (shown when a Task tool subagent is running)
            if let subagent = wsManager.activeSubagent {
                SubagentBanner(subagent: subagent) {
                    wsManager.activeSubagent = nil
                }
            }

            // Tool progress banner (shown when tool reports progress and NOT waiting for approval/question)
            if let progress = wsManager.toolProgress, wsManager.pendingApproval == nil, wsManager.pendingQuestion == nil {
                ToolProgressBanner(progress: progress) {
                    wsManager.toolProgress = nil
                }
            }

            // Unified status bar with quick settings access
            UnifiedStatusBar(
                isProcessing: wsManager.isProcessing,
                tokenUsage: wsManager.tokenUsage,
                effectivePermissionMode: effectivePermissionModeValue,
                projectPath: project.path,
                showQuickSettings: $showQuickSettings
            )

            // AI-powered suggestion chips (shown when enabled, not processing, and not typing)
            if settings.autoSuggestionsEnabled && !wsManager.isProcessing && inputText.isEmpty && !claudeHelper.suggestedActions.isEmpty {
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
                selectedImages: $selectedImages,
                isProcessing: wsManager.isProcessing,
                isAborting: wsManager.isAborting,
                projectPath: project.path,
                isFocused: _isInputFocused,
                onSend: sendMessage,
                onAbort: { wsManager.abortSession() },
                recentMessages: messages,
                claudeHelper: claudeHelper,
                sessionId: wsManager.sessionId  // Pass session ID to avoid creating orphan sessions
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

        wsManager.onToolUse = { id, name, input in
            // Track tool_use_id → tool name for result filtering
            toolUseMap[id] = name

            // Track tool IDs created while a subagent is active
            // Results for these IDs should be filtered even after subagent completes
            if wsManager.activeSubagent != nil && name != "Task" {
                subagentToolIds.insert(id)
                log.debug("[ChatView] Tracking subagent tool: \(name) (id: \(id.prefix(8)))")
                return  // Don't show the tool_use message either
            }

            let toolMsg = ChatMessage(
                role: .toolUse,
                content: "\(name)(\(input))",
                timestamp: Date()
            )
            messages.append(toolMsg)

            // Detect TodoWrite tool calls and update the floating drawer
            if name == "TodoWrite" {
                let content = "\(name)(\(input))"
                if let todos = TodoListView.parseTodoContent(content), !todos.isEmpty {
                    // Use withTransaction to batch state updates and prevent animation conflicts
                    // This helps avoid UI freezes when user is typing elsewhere during streaming
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        currentTodos = todos
                        showTodoDrawer = true
                    }
                    // Cancel any pending hide timer - we have new todos
                    todoHideTimer?.cancel()
                    todoHideTimer = nil
                }
            }
        }

        wsManager.onToolResult = { id, tool, result in
            // Look up the original tool name from our tracking map
            // The 'tool' from result may be "unknown" if cli-bridge doesn't provide it
            let toolName = toolUseMap[id] ?? tool

            // Skip results for tools that were created while a subagent was active
            // Results may arrive AFTER subagent completes due to coalescing
            if subagentToolIds.contains(id) {
                log.debug("[ChatView] Filtering subagent tool result: \(toolName) (id: \(id.prefix(8)))")
                subagentToolIds.remove(id)  // Clean up after filtering
                return
            }

            // Also skip the Task tool's own result (when subagent completes)
            if toolName == "Task" {
                log.debug("[ChatView] Filtering Task tool result (id: \(id.prefix(8)))")
                return
            }

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
            // Clear tool use tracking to prevent memory growth
            toolUseMap.removeAll()
            subagentToolIds.removeAll()

            // Add final assistant message with execution time and token count
            if !wsManager.currentText.isEmpty {
                // Calculate execution time
                let executionTime: TimeInterval? = processingStartTime.map { Date().timeIntervalSince($0) }

                // Get token count from current usage
                let tokenCount = wsManager.tokenUsage?.used

                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: wsManager.currentText,
                    timestamp: Date(),
                    executionTime: executionTime,
                    tokenCount: tokenCount
                )
                messages.append(assistantMessage)
            }
            processingStartTime = nil

            // Refresh git status after task completion
            refreshGitStatus()

            // Generate AI-powered suggestions for next actions using current session context
            if settings.autoSuggestionsEnabled {
                Task {
                    await claudeHelper.generateSuggestions(
                        recentMessages: messages,
                        projectPath: project.path,
                        currentSessionId: wsManager.sessionId  // Use current session for full context
                    )
                }
            }

            // Start auto-hide timer for todo drawer (15s after streaming completes)
            if showTodoDrawer && !currentTodos.isEmpty {
                todoHideTimer?.cancel()
                todoHideTimer = Task {
                    try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
                    if !Task.isCancelled {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showTodoDrawer = false
                            isTodoDrawerExpanded = false
                        }
                    }
                }
            }
        }

        wsManager.onError = { error in
            // Haptic feedback for error
            HapticManager.error()

            let errorMessage = ChatMessage(
                role: .error,
                content: "Error: \(error)",
                timestamp: Date()
            )
            messages.append(errorMessage)
            processingStartTime = nil
        }

        wsManager.onSessionCreated = { sessionId in
            // Check if this session already exists in the store (reconnecting to existing session)
            let existingSession = sessionStore.sessions(for: project.path).first { $0.id == sessionId }
            if let existing = existingSession {
                // Don't overwrite selectedSession if we already have good data
                if selectedSession?.id != sessionId || selectedSession?.summary == nil {
                    selectedSession = existing
                }
                wsManager.sessionId = sessionId
                MessageStore.saveSessionId(sessionId, for: project.path)
                sessionStore.setActiveSession(sessionId, for: project.path)
                return
            }
            // Set wsManager.sessionId so SessionPicker's activeSessionId includes this session
            wsManager.sessionId = sessionId
            // Save session ID for continuity when returning to this project
            MessageStore.saveSessionId(sessionId, for: project.path)

            // Create a new session entry and add to local list
            // Use the first user message as the summary if available
            let summary = messages.first { $0.role == .user }?.content.prefix(50).description

            let newSession = ProjectSession(
                id: sessionId,
                summary: summary,
                messageCount: 1,
                lastActivity: ISO8601DateFormatter().string(from: Date()),
                lastUserMessage: summary,
                lastAssistantMessage: nil
            )

            // Add the new session to SessionStore
            sessionStore.addSession(newSession, for: project.path)
            sessionStore.setActiveSession(sessionId, for: project.path)

            // Select the new session in the picker
            selectedSession = newSession
        }

        // Note: AskUserQuestion is handled via $wsManager.pendingQuestion binding
        // The adapter sets pendingQuestion directly, triggering the sheet

        wsManager.onAborted = {
            // Show feedback that the task was aborted
            let abortMsg = ChatMessage(
                role: .system,
                content: "⏹ Task aborted",
                timestamp: Date()
            )
            messages.append(abortMsg)
            processingStartTime = nil
        }

        wsManager.onSessionRecovered = { [weak wsManager] in
            // Show feedback that session was recovered
            let recoveryMsg = ChatMessage(
                role: .system,
                content: "⚠️ Previous session expired. Starting fresh session.",
                timestamp: Date()
            )
            messages.append(recoveryMsg)

            // Clear the stored session ID for this project
            MessageStore.clearSessionId(for: project.path)

            // CRITICAL: Clear wsManager's sessionId so next message creates new session
            wsManager?.sessionId = nil
        }

        wsManager.onSessionAttached = {
            // Show feedback that we successfully reattached to active session
            let attachMsg = ChatMessage(
                role: .system,
                content: "🔄 Reconnected to active session",
                timestamp: Date()
            )
            messages.append(attachMsg)
            print("[ChatView] Successfully reattached to active session")
        }

        // Handle session events from WebSocket (for real-time session list updates)
        wsManager.onSessionEvent = { [weak sessionStore] event in
            guard let sessionStore = sessionStore else { return }
            Task { @MainActor in
                await sessionStore.handleCLISessionEvent(event)
            }
        }

        // Handle history replay when resuming a session
        wsManager.onHistory = { payload in
            // Convert history messages to ChatMessages and display
            let historyMessages = payload.messages.map { $0.toChatMessage() }
            if !historyMessages.isEmpty {
                messages.insert(contentsOf: historyMessages, at: 0)
                refreshDisplayMessagesCache()
                // Scroll to bottom after history loads
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    scrollToBottomTrigger = true
                }
            }
            print("[ChatView] Loaded \(historyMessages.count) history messages, hasMore: \(payload.hasMore)")
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !selectedImages.isEmpty else { return }

        // Haptic feedback for send action
        HapticManager.medium()

        // Hide todo drawer when user sends a new message (new task starting)
        todoHideTimer?.cancel()
        todoHideTimer = nil
        withAnimation(.easeOut(duration: 0.2)) {
            showTodoDrawer = false
            isTodoDrawerExpanded = false
        }
        currentTodos = []

        // Check for slash commands (client-side handling)
        if text.hasPrefix("/") && selectedImages.isEmpty {
            if handleSlashCommand(text) {
                inputText = ""
                return
            }
            // If command not handled, fall through to send to server
        }

        // Capture images before clearing
        let imagesToSend = selectedImages

        // Add user message with first image for display (if any)
        let displayImage = imagesToSend.first?.originalData
        let imageCountSuffix = imagesToSend.count > 1 ? " (\(imagesToSend.count) images)" : ""
        let userMessage = ChatMessage(
            role: .user,
            content: text.isEmpty ? "[Image attached]\(imageCountSuffix)" : text,
            timestamp: Date(),
            imageData: displayImage
        )
        messages.append(userMessage)

        inputText = ""
        selectedImages = []
        processingStartTime = Date()

        // Server handles thinking mode - just send the text as-is
        let messageToSend = text

        // Use effectiveSessionToResume which filters out ephemeral sessions
        let sessionToResume = effectiveSessionToResume

        // Debug: Log session ID being used
        if let sid = sessionToResume {
            print("[ChatView] Sending message with sessionToResume: \(sid.prefix(8))...")
        } else {
            print("[ChatView] Sending message with NO session ID - new session will be created")
        }

        // Send message with optional images
        let defaultPrompt = imagesToSend.count == 1 ? "What is this image?" : "What are these images?"
        wsManager.sendMessage(
            text.isEmpty ? defaultPrompt : messageToSend,
            projectPath: project.path,
            resumeSessionId: sessionToResume,
            permissionMode: effectivePermissionMode,
            images: imagesToSend.isEmpty ? nil : imagesToSend,
            model: effectiveModelId
        )

        // Persist messages
        MessageStore.saveMessages(messages, for: project.path, maxMessages: settings.historyLimit.rawValue)
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
        scrollManager.reset()  // Reset scroll state for fresh session
        addSystemMessage("Conversation cleared. Starting fresh.")
        MessageStore.clearMessages(for: project.path)
        MessageStore.clearSessionId(for: project.path)
    }

    private func handleNewSessionCommand() {
        // Clear and start new session
        messages.removeAll()
        wsManager.sessionId = nil
        selectedSession = nil
        scrollManager.reset()  // Reset scroll state for fresh session
        addSystemMessage("New session started.")
        MessageStore.clearMessages(for: project.path)
        MessageStore.clearSessionId(for: project.path)
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

    /// Append content to the input field with smart spacing
    private func appendToInput(_ content: String) {
        if inputText.isEmpty {
            inputText = content + " "
        } else if inputText.hasSuffix(" ") {
            inputText += content + " "
        } else {
            inputText += " " + content + " "
        }
    }

    /// Load all sessions via API (SessionStore handles API-based loading)
    private func loadAllSessions() {
        Task {
            await sessionStore.loadSessions(for: project.path, forceRefresh: true)
        }
    }

    // MARK: - Session Auto-Selection

    /// Select initial session: pre-selected from navigation, or fall back to most recent
    private func selectInitialSession() {
        // Check for a pre-selected session (from Recent Sessions navigation)
        if let preSelectedId = sessionStore.loadActiveSessionId(for: project.path) {
            // Try to find session in loaded sessions
            if let preSelectedSession = sessionStore.sessions(for: project.path).first(where: { $0.id == preSelectedId }) {
                print("[ChatView] Using pre-selected session: \(preSelectedId.prefix(8))...")
                selectedSession = preSelectedSession
            } else {
                // Session not in list - create ephemeral session to load it
                print("[ChatView] Pre-selected session \(preSelectedId.prefix(8)) not in list, creating ephemeral...")
                let ephemeralSession = ProjectSession(
                    id: preSelectedId,
                    summary: nil,
                    messageCount: nil,
                    lastActivity: nil,
                    lastUserMessage: nil,
                    lastAssistantMessage: nil
                )
                selectedSession = ephemeralSession
            }
            // Clear the pre-selection so next visit uses auto-select
            sessionStore.clearActiveSessionId(for: project.path)
        } else {
            // Fall back to auto-selecting most recent session
            autoSelectMostRecentSession()
        }
    }

    /// Auto-select the most recent session from project.sessions by lastActivityAt
    /// Does NOT load history or connect - caller is responsible for that
    private func autoSelectMostRecentSession() {
        // First try SessionStore (more up-to-date)
        let storeSessions = sessionStore.displaySessions(for: project.path)
        if !storeSessions.isEmpty {
            if let mostRecent = storeSessions.first, (mostRecent.messageCount ?? 0) > 0 {
                selectedSession = mostRecent
                return
            }
        }

        // Fall back to project.sessions
        guard let sessions = project.sessions else { return }
        let filteredSessions = sessions.filterAndSortForDisplay(projectPath: project.path, activeSessionId: nil)
        guard let mostRecent = filteredSessions.first,
              (mostRecent.messageCount ?? 0) > 0 else { return }

        selectedSession = mostRecent
    }

    /// Select the most recent session from a list of sessions
    private func selectMostRecentSession(from sessions: [ProjectSession]) {
        guard let mostRecent = sessions.first else { return }

        print("[ChatView] Selecting most recent session: \(mostRecent.id.prefix(8))...")
        wsManager.sessionId = mostRecent.id
        selectedSession = mostRecent
        MessageStore.saveSessionId(mostRecent.id, for: project.path)

        // Load the session history if not already loaded
        if messages.isEmpty {
            loadSessionHistory(mostRecent)
        }
    }

    /// Attempt to reattach to an active/processing session
    private func attemptSessionReattachment(sessionId: String) {
        Task {
            // Wait for WebSocket connection to be established
            var attempts = 0
            while !wsManager.connectionState.isConnected && attempts < 20 {
                try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
                attempts += 1
            }

            await MainActor.run {
                if wsManager.connectionState.isConnected {
                    print("[ChatView] Reattaching to session: \(sessionId.prefix(8))...")
                    wsManager.attachToSession(sessionId: sessionId, projectPath: project.path)
                } else {
                    print("[ChatView] Could not reattach - WebSocket not connected after wait")
                    // Clear the processing state since we couldn't reattach
                    MessageStore.clearProcessingState(for: project.path)
                }
            }
        }
    }

    /// Load full session history via API using export endpoint
    private func loadSessionHistory(_ session: ProjectSession) {
        messages = []  // Clear current messages
        isLoadingHistory = true
        scrollManager.reset()  // Reset scroll state for new history

        Task {
            do {
                print("[ChatView] Loading session history via export API for: \(session.id)")

                // Export session as JSON with structured content (preserves tool_use, tool_result, thinking)
                let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
                let exportResponse = try await apiClient.exportSession(
                    projectPath: project.path,
                    sessionId: session.id,
                    format: .json,
                    includeStructuredContent: true
                )

                // Fetch token usage for this session
                await wsManager.refreshTokenUsage(projectPath: project.path, sessionId: session.id)

                // Parse JSONL content to ChatMessages
                let historyMessages = parseJSONLToMessages(exportResponse.content)

                await MainActor.run {
                    if historyMessages.isEmpty {
                        // Fallback to lastAssistantMessage if parsing failed
                        if let lastMsg = session.lastAssistantMessage {
                            messages.append(ChatMessage(role: .assistant, content: lastMsg, timestamp: Date()))
                        }
                    } else {
                        messages = historyMessages
                        print("[ChatView] Loaded \(historyMessages.count) messages from session export")
                    }
                    // Mark loading complete and scroll once after layout settles
                    isLoadingHistory = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrollManager.forceScrollToBottom()
                    }
                }
            } catch {
                print("[ChatView] Failed to load session history via export: \(error)")
                await MainActor.run {
                    // Fallback to lastAssistantMessage
                    if let lastMsg = session.lastAssistantMessage {
                        messages.append(ChatMessage(role: .assistant, content: lastMsg, timestamp: Date()))
                    }
                    // Show error message
                    messages.append(ChatMessage(role: .system, content: "Could not load history: \(error.localizedDescription)", timestamp: Date()))
                    // Mark loading complete and scroll once after layout settles
                    isLoadingHistory = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrollManager.forceScrollToBottom()
                    }
                }
            }
        }
    }

    /// Parse session export JSON into ChatMessages
    /// Format: { "session": {...}, "messages": [...] }
    /// Messages are flattened StreamMessage objects: tool_use, tool_result, thinking as top-level types
    /// This matches the WebSocket live stream format for consistent parsing
    private func parseJSONLToMessages(_ jsonContent: String) -> [ChatMessage] {
        guard let data = jsonContent.data(using: .utf8) else {
            print("[ChatView] Failed to convert export content to data")
            return []
        }

        do {
            // Parse as JSON object with messages array
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let messagesArray = json["messages"] as? [[String: Any]] {
                print("[ChatView] Found \(messagesArray.count) messages in export")
                // flatMap because each export message can produce multiple ChatMessages
                return messagesArray.flatMap { parseExportMessage($0) }
            }
        } catch {
            print("[ChatView] Failed to parse export JSON: \(error)")
        }

        return []
    }

    /// Parse a message from the export format
    /// Handles flattened StreamMessage format (tool_use, tool_result as top-level types)
    /// and plain text content for user/assistant/system messages
    private func parseExportMessage(_ json: [String: Any]) -> [ChatMessage] {
        guard let type = json["type"] as? String else { return [] }

        // Extract timestamp
        var timestamp = Date()
        if let ts = json["timestamp"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: ts) {
                timestamp = date
            } else {
                formatter.formatOptions = [.withInternetDateTime]
                timestamp = formatter.date(from: ts) ?? Date()
            }
        }

        // Handle flattened StreamMessage types (matches WebSocket format)
        switch type {
        case "tool_use":
            // Format: { type: "tool_use", name: "Bash", input: {...}, content: "toolu_id" }
            // Must use JSON serialization to match live stream format: Bash({"command":"..."})
            // This ensures extractParam() can parse the JSON to extract parameters
            if let name = json["name"] as? String {
                var toolContent = name
                if let inputDict = json["input"] as? [String: Any] {
                    if let data = try? JSONSerialization.data(withJSONObject: inputDict),
                       let inputStr = String(data: data, encoding: .utf8) {
                        toolContent = "\(name)(\(inputStr))"
                        print("[ChatView] ✅ Parsed tool_use \(name) with JSON: \(inputStr.prefix(50))...")
                    } else {
                        print("[ChatView] ❌ JSONSerialization failed for \(name)")
                    }
                } else if json["input"] != nil {
                    print("[ChatView] ❌ input not [String: Any] for \(name), keys: \(json.keys)")
                }
                return [ChatMessage(role: .toolUse, content: toolContent, timestamp: timestamp)]
            }
            return []

        case "tool_result":
            // Format: { type: "tool_result", tool: "Bash", output: "...", success: true, is_error: false }
            let output = json["output"] as? String ?? json["content"] as? String ?? ""
            let isError = json["is_error"] as? Bool ?? !(json["success"] as? Bool ?? true)
            let role: ChatMessage.Role = isError ? .error : .toolResult
            return [ChatMessage(role: role, content: output, timestamp: timestamp)]

        case "thinking":
            // Format: { type: "thinking", content: "..." }
            if let thinking = json["content"] as? String, !thinking.isEmpty {
                return [ChatMessage(role: .thinking, content: thinking, timestamp: timestamp)]
            }
            return []

        case "user", "assistant", "system":
            // Skip meta messages (local command metadata that shouldn't appear in chat)
            if json["isMeta"] as? Bool == true {
                return []
            }

            // Plain text content
            if let content = json["content"] as? String, !content.isEmpty {
                // Filter out "Caveat:" messages (CLI metadata about local commands)
                if content.hasPrefix("Caveat: The messages below were generated") {
                    return []
                }

                // Parse local command XML format: <command-name>/resume</command-name>...
                if let localCommand = parseLocalCommandXML(content) {
                    return [localCommand.toChatMessage(timestamp: timestamp)]
                }

                let role: ChatMessage.Role
                switch type {
                case "user": role = .user
                case "assistant": role = .assistant
                default: role = .system
                }
                return [ChatMessage(role: role, content: content, timestamp: timestamp)]
            }
            // Legacy: structured content array (for backwards compatibility)
            if let contentArray = json["content"] as? [[String: Any]] {
                return parseStructuredContent(contentArray, messageType: type, timestamp: timestamp)
            }
            return []

        default:
            print("[ChatView] Unknown message type: \(type)")
            return []
        }
    }

    /// Parse structured content array into ChatMessages
    /// Only handles text blocks - tool_use/tool_result/thinking should be flattened by cli-bridge
    private func parseStructuredContent(_ blocks: [[String: Any]], messageType: String, timestamp: Date) -> [ChatMessage] {
        var messages: [ChatMessage] = []

        for block in blocks {
            guard let blockType = block["type"] as? String else { continue }

            switch blockType {
            case "text":
                if let text = block["text"] as? String, !text.isEmpty {
                    let role: ChatMessage.Role = messageType == "user" ? .user : .assistant
                    messages.append(ChatMessage(role: role, content: text, timestamp: timestamp))
                }

            default:
                // cli-bridge should flatten tool_use/tool_result/thinking to top-level types
                // If we see them here, cli-bridge needs to be updated
                print("[ChatView] Unexpected nested block type '\(blockType)' - cli-bridge should flatten this")
            }
        }

        return messages
    }

    // MARK: - Local Command Parsing

    /// Parsed local command from CLI session history
    struct LocalCommand {
        let name: String      // e.g., "/resume", "/exit"
        let args: String      // command arguments
        let stdout: String    // command output

        /// Convert to ChatMessage for display
        /// Format: "> /command\n└ output"
        func toChatMessage(timestamp: Date) -> ChatMessage {
            var content = name
            if !args.isEmpty {
                content += " \(args)"
            }
            if !stdout.isEmpty {
                content += "\n└ \(stdout)"
            }
            return ChatMessage(role: .system, content: content, timestamp: timestamp)
        }
    }

    /// Parse local command XML format from CLI session history
    /// Format: <command-name>/resume</command-name><command-message>resume</command-message><command-args></command-args><local-command-stdout>No conversations found</local-command-stdout>
    private func parseLocalCommandXML(_ content: String) -> LocalCommand? {
        // Quick check - must contain command-name tag
        guard content.contains("<command-name>") else { return nil }

        // Extract command name
        guard let nameStart = content.range(of: "<command-name>"),
              let nameEnd = content.range(of: "</command-name>") else {
            return nil
        }
        let name = String(content[nameStart.upperBound..<nameEnd.lowerBound])

        // Extract args (may be empty)
        var args = ""
        if let argsStart = content.range(of: "<command-args>"),
           let argsEnd = content.range(of: "</command-args>") {
            args = String(content[argsStart.upperBound..<argsEnd.lowerBound])
        }

        // Extract stdout (may be empty)
        var stdout = ""
        if let stdoutStart = content.range(of: "<local-command-stdout>"),
           let stdoutEnd = content.range(of: "</local-command-stdout>") {
            stdout = String(content[stdoutStart.upperBound..<stdoutEnd.lowerBound])
        }

        return LocalCommand(name: name, args: args, stdout: stdout)
    }

    /// Delete a session from the server
    private func deleteSession(_ session: ProjectSession) async {
        print("[ChatView] Deleting session: \(session.id)")

        // Use SessionStore for centralized delete
        let success = await sessionStore.deleteSession(session, for: project.path)

        if success {
            // If we deleted the currently selected session, clear it
            if selectedSession?.id == session.id {
                selectedSession = nil
                messages.removeAll()
                wsManager.sessionId = nil
                MessageStore.clearSessionId(for: project.path)
            }

            // Notify parent to refresh project list
            onSessionsChanged?()
        } else {
            print("[ChatView] Failed to delete session: \(session.id)")
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
    /// Refresh chat content: reload session history and git status
    private func refreshChatContent() async {
        HapticManager.light()

        // Refresh git status in background
        Task {
            refreshGitStatus()
        }

        // Reload session history if we have an active session
        if let sessionId = wsManager.sessionId {
            do {
                let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
                let exportResponse = try await apiClient.exportSession(
                    projectPath: project.path,
                    sessionId: sessionId,
                    format: .json
                )
                // Parse JSONL content to ChatMessages
                let historyMessages = parseJSONLToMessages(exportResponse.content)
                await MainActor.run {
                    // Only update if we got messages
                    if !historyMessages.isEmpty {
                        messages = historyMessages
                    }
                }
            } catch {
                print("[ChatView] Failed to refresh session history: \(error)")
            }
        }
    }

    private func refreshGitStatus() {
        Task {
            gitStatus = .checking

            // Fetch git status from cli-bridge API
            let newStatus: GitStatus
            do {
                let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
                let projects = try await apiClient.fetchProjects()
                if let cliProject = projects.first(where: { $0.path == project.path }),
                   let git = cliProject.git {
                    newStatus = git.toGitStatus
                } else {
                    newStatus = .notGitRepo
                }
            } catch {
                print("[ChatView] Failed to fetch git status from API: \(error)")
                newStatus = .error(error.localizedDescription)
            }

            await MainActor.run {
                gitStatus = newStatus

                // Sync to ProjectCache so ContentView sees the update
                ProjectCache.shared.updateGitStatus(for: project.path, status: newStatus)

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

        do {
            let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
            let response = try await apiClient.gitPull(projectPath: project.path)

            await MainActor.run {
                isAutoPulling = false
                if response.commits > 0 {
                    gitStatus = .clean
                    showGitBanner = false
                    ProjectCache.shared.updateGitStatus(for: project.path, status: .clean)

                    let filesDesc = response.files.map { " (\($0.count) files)" } ?? ""
                    messages.append(ChatMessage(
                        role: .system,
                        content: "✓ Pulled \(response.commits) commit\(response.commits == 1 ? "" : "s")\(filesDesc)",
                        timestamp: Date()
                    ))
                } else {
                    // Already up to date
                    gitStatus = .clean
                    showGitBanner = false
                    ProjectCache.shared.updateGitStatus(for: project.path, status: .clean)
                }
            }
        } catch {
            await MainActor.run {
                isAutoPulling = false
                let errorStatus = GitStatus.error("Auto-pull failed: \(error.localizedDescription)")
                gitStatus = errorStatus
                ProjectCache.shared.updateGitStatus(for: project.path, status: errorStatus)
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

        // Send to Claude (use effectiveSessionToResume which filters out ephemeral sessions)
        wsManager.sendMessage(
            cleanupPrompt,
            projectPath: project.path,
            resumeSessionId: effectiveSessionToResume,
            permissionMode: effectivePermissionMode,
            model: effectiveModelId
        )
        processingStartTime = Date()

        // Trigger scroll to bottom after a brief delay to let layout settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            scrollToBottomTrigger = true
        }
    }

    /// Send a message to Claude asking to commit changes
    private func promptClaudeForCommit() {
        let commitPrompt = """
        Please help me commit my changes. Run `git status` and `git diff` to review what has changed, then create a commit with an appropriate message. After committing, push the changes to the remote.
        """

        // Add user message
        let userMessage = ChatMessage(role: .user, content: commitPrompt, timestamp: Date())
        messages.append(userMessage)

        // Hide banner after adding message to avoid layout shift during scroll
        showGitBanner = false

        // Send to Claude (use effectiveSessionToResume which filters out ephemeral sessions)
        wsManager.sendMessage(
            commitPrompt,
            projectPath: project.path,
            resumeSessionId: effectiveSessionToResume,
            permissionMode: effectivePermissionMode,
            model: effectiveModelId
        )
        processingStartTime = Date()

        // Trigger scroll to bottom after a brief delay to let layout settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            scrollToBottomTrigger = true
        }
    }

    /// Send a message to Claude asking to push commits
    private func promptClaudeForPush() {
        let pushPrompt = """
        Please push my local commits to the remote. Run `git log --oneline @{upstream}..HEAD` to show what will be pushed, then run `git push` to push the commits.
        """

        // Add user message
        let userMessage = ChatMessage(role: .user, content: pushPrompt, timestamp: Date())
        messages.append(userMessage)

        // Hide banner after adding message to avoid layout shift during scroll
        showGitBanner = false

        // Send to Claude (use effectiveSessionToResume which filters out ephemeral sessions)
        wsManager.sendMessage(
            pushPrompt,
            projectPath: project.path,
            resumeSessionId: effectiveSessionToResume,
            permissionMode: effectivePermissionMode,
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
        if model == .custom {
            return customModelId.isEmpty ? nil : customModelId
        }
        return model.modelId
    }

    /// The effective permission mode value for this project (considers per-project override)
    /// Returns the resolved PermissionMode enum value for UI display
    private var effectivePermissionModeValue: PermissionMode {
        projectSettingsStore.effectivePermissionMode(
            for: project.path,
            globalMode: settings.globalPermissionMode
        )
    }

    /// The effective permission mode to send to server for this project
    /// Always returns a value (never nil) to ensure permissions are set correctly
    private var effectivePermissionMode: String {
        effectivePermissionModeValue.rawValue
    }
}

#Preview {
    @Previewable @State var settings = AppSettings()
    NavigationStack {
        ChatView(
            project: Project(
                name: "test-project",
                path: "/test/project",
                displayName: "Test Project",
                fullPath: "/test/project",
                sessions: nil,
                sessionMeta: nil
            )
        )
    }
    .environmentObject(settings)
}
