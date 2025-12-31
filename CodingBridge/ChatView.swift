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

    // MARK: - ViewModel
    @StateObject private var viewModel: ChatViewModel

    // MARK: - Focus State (must stay in View for @FocusState)
    @FocusState private var isInputFocused: Bool

    // MARK: - Computed Properties

    /// Display name for project - uses custom name from ProjectNamesStore if set, otherwise server title
    private var displayName: String {
        if let customName = ProjectNamesStore.shared.getName(for: project.path) {
            return customName
        }
        return project.title
    }

    init(project: Project, initialGitStatus: GitStatus = .unknown, onSessionsChanged: (() -> Void)? = nil) {
        self.project = project
        self.initialGitStatus = initialGitStatus
        self.onSessionsChanged = onSessionsChanged
        // Initialize ViewModel with placeholder settings - will be updated in onAppear
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            project: project,
            initialGitStatus: initialGitStatus,
            settings: AppSettings(),
            onSessionsChanged: onSessionsChanged
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar (when searching)
            if viewModel.isSearching {
                ChatSearchBar(
                    searchText: $viewModel.searchText,
                    isSearching: $viewModel.isSearching,
                    selectedFilter: $viewModel.messageFilter
                )

                // Result count
                SearchResultCount(count: viewModel.displayMessages.count, searchText: viewModel.searchText)
            }

            // Git status banner (when there are local changes)
            gitStatusBannerView

            sessionPickerView
            messagesScrollView
            statusAndInputView
        }
        .background(CLITheme.background(for: colorScheme))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ChatTitleView(
                    displayName: displayName,
                    gitStatus: viewModel.gitStatus,
                    onRefreshGitStatus: viewModel.refreshGitStatus
                )
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                ChatToolbarActions(
                    isSearching: viewModel.isSearching,
                    ideasCount: viewModel.ideasStore.ideas.count,
                    isProcessing: viewModel.isProcessing,
                    onToggleSearch: {
                        withAnimation {
                            viewModel.isSearching.toggle()
                            if !viewModel.isSearching {
                                viewModel.searchText = ""
                                viewModel.messageFilter = .all
                            }
                        }
                    },
                    onShowIdeas: { viewModel.showIdeasDrawer = true },
                    onQuickCapture: { viewModel.showQuickCapture = true },
                    onNewChat: viewModel.startNewSession,
                    onShowBookmarks: { viewModel.showingBookmarks = true },
                    onAbort: viewModel.abortSession
                )
            }
        }
        .onAppear {
            // Update ViewModel with actual settings from environment
            viewModel.settings = settings
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: viewModel.messages.count) { _, _ in
            // Only trigger on count changes (not content changes during streaming)
            // This reduces onChange overhead from O(n) array comparison to O(1) int comparison
            viewModel.handleMessagesChange()
        }
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.refreshDisplayMessagesCache()
        }
        .onChange(of: viewModel.messageFilter) { _, _ in
            viewModel.refreshDisplayMessagesCache()
        }
        .onChange(of: settings.defaultModel) { oldModel, newModel in
            viewModel.handleModelChange(oldModel: oldModel, newModel: newModel)
        }
        .onChange(of: viewModel.inputText) { _, newText in
            viewModel.handleInputTextChange(newText)
        }
        .onChange(of: viewModel.isProcessing) { oldValue, isProcessing in
            viewModel.handleProcessingChange(oldValue: oldValue, isProcessing: isProcessing)

            // Refocus input when processing completes
            if oldValue && !isProcessing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInputFocused = true
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if !viewModel.isConnected {
                    log.debug("[ChatView] App active - reconnecting WebSocket")
                    viewModel.wsManager.connect()  // Keep direct access for connect()
                }
            case .inactive, .background:
                break
            @unknown default:
                break
            }
        }
        .sheet(item: Binding(
            get: { viewModel.pendingQuestion },
            set: { _ in }  // Handled by wsManager
        )) { questionData in
            userQuestionsSheet(questionData)
        }
        .sheet(isPresented: $viewModel.showingHelpSheet) {
            SlashCommandHelpSheet()
        }
        .sheet(isPresented: $viewModel.showingSessionPicker) {
            SessionPickerSheet(
                project: project,
                sessions: viewModel.localSessionsBinding,
                onSelect: { session in
                    viewModel.showingSessionPicker = false
                    viewModel.selectSession(session)
                },
                onCancel: {
                    viewModel.showingSessionPicker = false
                },
                onDelete: { session in
                    Task { await viewModel.deleteSession(session) }
                }
            )
        }
        .sheet(isPresented: $viewModel.showingModelPicker) {
            CustomModelPickerSheet(
                customModelId: $viewModel.customModelId,
                onConfirm: { modelId in
                    viewModel.showingModelPicker = false
                    viewModel.switchToModel(.custom, customId: modelId)
                    settings.customModelId = modelId
                },
                onCancel: {
                    viewModel.showingModelPicker = false
                }
            )
        }
        .sheet(isPresented: $viewModel.showingBookmarks) {
            BookmarksView()
                .environmentObject(settings)
        }
        .sheet(isPresented: $viewModel.showIdeasDrawer) {
            IdeasDrawerSheet(
                isPresented: $viewModel.showIdeasDrawer,
                ideasStore: viewModel.ideasStore,
                projectPath: project.path,
                onSendIdea: { idea in
                    viewModel.appendToInput(idea.formattedPrompt)
                }
            )
        }
        .sheet(isPresented: $viewModel.showQuickCapture) {
            QuickCaptureSheet(isPresented: $viewModel.showQuickCapture) { text in
                viewModel.ideasStore.quickAdd(text)
            }
        }
        // MARK: - Keyboard Shortcuts (iPad)
        .background {
            keyboardShortcutButtons
        }
    }

    // MARK: - Keyboard Shortcut Buttons

    @ViewBuilder
    private var keyboardShortcutButtons: some View {
        // Cmd+Return: Send message
        Button("") {
            viewModel.sendMessage()
        }
        .keyboardShortcut(.return, modifiers: .command)
        .hidden()

        // Cmd+K: Clear conversation
        Button("") {
            viewModel.handleClearCommand()
        }
        .keyboardShortcut("k", modifiers: .command)
        .hidden()

        // Cmd+N: New session
        Button("") {
            viewModel.handleNewSessionCommand()
        }
        .keyboardShortcut("n", modifiers: .command)
        .hidden()

        // Cmd+.: Abort current request
        Button("") {
            if viewModel.isProcessing {
                HapticManager.rigid()
                viewModel.abortSession()
            }
        }
        .keyboardShortcut(".", modifiers: .command)
        .hidden()

        // Cmd+/: Show help
        Button("") {
            viewModel.showingHelpSheet = true
        }
        .keyboardShortcut("/", modifiers: .command)
        .hidden()

        // Cmd+R: Resume session picker
        Button("") {
            viewModel.showingSessionPicker = true
        }
        .keyboardShortcut("r", modifiers: .command)
        .hidden()
    }

    /// Sheet view for AskUserQuestion
    @ViewBuilder
    private func userQuestionsSheet(_ questionData: AskUserQuestionData) -> some View {
        UserQuestionsSheetWrapper(
            initialData: questionData,
            onSubmit: { answeredData in
                viewModel.handleQuestionAnswer(answeredData)
            },
            onCancel: {
                viewModel.handleQuestionCancel()
            }
        )
    }

    // MARK: - View Components

    @ViewBuilder
    private var sessionPickerView: some View {
        SessionBar(
            project: project,
            sessions: viewModel.localSessionsBinding,
            selected: $viewModel.selectedSession,
            isLoading: viewModel.isLoadingHistory,
            isProcessing: viewModel.isProcessing,
            activeSessionId: viewModel.activeSessionId,
            onSelect: { session in
                viewModel.selectSession(session)
            },
            onNew: {
                viewModel.startNewSession()
            },
            onDelete: { session in
                Task {
                    await viewModel.deleteSession(session)
                }
            }
        )
    }

    @ViewBuilder
    private var gitStatusBannerView: some View {
        if viewModel.showGitBanner {
            switch viewModel.gitStatus {
            case .dirty, .dirtyAndAhead, .diverged:
                GitSyncBanner(
                    status: viewModel.gitStatus,
                    isAutoPulling: false,
                    isRefreshing: viewModel.gitStatus == .checking,
                    onDismiss: { viewModel.showGitBanner = false },
                    onRefresh: { viewModel.refreshGitStatus() },
                    onPull: nil,
                    onCommit: { viewModel.promptClaudeForCommit() },
                    onAskClaude: { viewModel.promptClaudeForCleanup() }
                )

            case .behind:
                GitSyncBanner(
                    status: viewModel.gitStatus,
                    isAutoPulling: viewModel.isAutoPulling,
                    isRefreshing: viewModel.gitStatus == .checking,
                    onDismiss: { viewModel.showGitBanner = false },
                    onRefresh: { viewModel.refreshGitStatus() },
                    onPull: { Task { await viewModel.performAutoPull() } },
                    onCommit: nil,
                    onAskClaude: nil
                )

            case .ahead:
                GitSyncBanner(
                    status: viewModel.gitStatus,
                    isAutoPulling: false,
                    isRefreshing: viewModel.gitStatus == .checking,
                    onDismiss: { viewModel.showGitBanner = false },
                    onRefresh: { viewModel.refreshGitStatus() },
                    onPull: nil,
                    onCommit: { viewModel.promptClaudeForPush() },
                    onAskClaude: { viewModel.promptClaudeForCleanup() }
                )

            default:
                EmptyView()
            }
        }
    }

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView {
                    messagesListView
                        .background(
                            // Track when bottom anchor is visible
                            GeometryReader { geo in
                                Color.clear
                                    .preference(
                                        key: BottomVisiblePreferenceKey.self,
                                        value: geo.frame(in: .named("scrollArea")).maxY
                                    )
                            }
                        )
                }
                .coordinateSpace(name: "scrollArea")
                .scrollDismissesKeyboard(.interactively)
                .background(CLITheme.background(for: colorScheme))
                .refreshable {
                    await viewModel.refreshChatContent()
                }
                .onPreferenceChange(BottomVisiblePreferenceKey.self) { maxY in
                    // If content bottom is near or below the scroll view bottom, we're at bottom
                    // Hide the scroll button when at bottom
                    if maxY < UIScreen.main.bounds.height + 100 {
                        if viewModel.showScrollToBottom {
                            viewModel.showScrollToBottom = false
                        }
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { _ in
                            isInputFocused = false
                            // Only show button if not already at bottom
                            viewModel.showScrollToBottom = true
                        }
                )

                // Manual scroll to bottom button
                if viewModel.showScrollToBottom {
                    Button {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("bottomAnchor")
                            }
                        }
                        viewModel.showScrollToBottom = false
                    } label: {
                        Image(systemName: "chevron.compact.down")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(CLITheme.primaryText(for: colorScheme).opacity(0.6))
                            .frame(width: 60, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 16)
                    .transition(.opacity)
                }
            }
            // Auto-scroll when new messages arrive (if enabled)
            .onChange(of: viewModel.messages.count) { _, _ in
                if settings.autoScrollEnabled && !viewModel.showScrollToBottom {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("bottomAnchor")
                    }
                }
            }
            // Explicit scroll trigger (used when sending messages - always scrolls)
            .onChange(of: viewModel.scrollToBottomTrigger) { _, shouldScroll in
                if shouldScroll {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("bottomAnchor")
                        }
                    }
                    viewModel.scrollToBottomTrigger = false
                    viewModel.showScrollToBottom = false
                }
            }
            .onAppear {
                guard !viewModel.isLoadingHistory else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    proxy.scrollTo("bottomAnchor")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .backgroundRecoveryNeeded)) { notification in
                guard let userInfo = notification.userInfo,
                      let sessionId = userInfo["sessionId"] as? String,
                      let projectPath = userInfo["projectPath"] as? String,
                      projectPath == project.path else {
                    return
                }
                log.info("Background recovery requested for session: \(sessionId.prefix(8))...")
                viewModel.wsManager.recoverFromBackground(sessionId: sessionId, projectPath: projectPath)
            }
        }
    }

    private var messagesListView: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Show loading indicator when loading history with no messages yet
            if viewModel.isLoadingHistory && viewModel.messages.isEmpty {
                loadingHistoryView
            }

            ForEach(viewModel.groupedDisplayItems) { item in
                DisplayItemView(
                    item: item,
                    projectPath: project.path,
                    projectTitle: project.title,
                    hideTodoInline: viewModel.showTodoDrawer
                )
                .id(item.id)
            }

            if viewModel.isProcessing {
                streamingIndicatorView
            }

            // Bottom anchor for scrollTo target
            // Extra space ensures last message appears above status bar when scrolled to bottom
            Spacer()
                .frame(height: 1)
                .id("bottomAnchor")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, viewModel.wsManager.agentState.isWorking ? 65 : 25)  // Extra space when status bubble showing
    }

    @ViewBuilder
    private var loadingHistoryView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
                .tint(CLITheme.cyan(for: colorScheme))
            Text("Loading session history...")
                .font(CLITheme.monoSmall)
                .foregroundColor(CLITheme.secondaryText(for: colorScheme))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 100)
    }

    @ViewBuilder
    private var streamingIndicatorView: some View {
        if viewModel.isReattaching {
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
        } else if viewModel.currentStreamingText.isEmpty {
            // StatusBubbleView now rendered in statusAndInputView (fixed position)
            EmptyView()
                .id("statusBubble")
        } else {
            CLIMessageView(
                message: ChatMessage(
                    id: viewModel.streamingMessageId,
                    role: .assistant,
                    content: viewModel.currentStreamingText,
                    timestamp: viewModel.streamingMessageTimestamp,
                    isStreaming: true
                ),
                projectPath: project.path,
                projectTitle: project.title
            )
            .id(viewModel.streamingMessageId)
        }
    }

    private var statusAndInputView: some View {
        VStack(spacing: 0) {
            // Todo progress drawer
            if viewModel.showTodoDrawer && !viewModel.currentTodos.isEmpty {
                TodoProgressDrawer(
                    todos: viewModel.currentTodos,
                    isExpanded: $viewModel.isTodoDrawerExpanded
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }

            // Permission approval banner
            if let approval = viewModel.pendingApproval {
                ApprovalBannerView(
                    request: approval,
                    onApprove: {
                        viewModel.approvePendingRequest(alwaysAllow: false)
                    },
                    onAlwaysAllow: {
                        viewModel.approvePendingRequest(alwaysAllow: true)
                    },
                    onDeny: {
                        viewModel.denyPendingRequest()
                    }
                )
            }

            // Input queued banner
            if viewModel.isInputQueued {
                InputQueuedBanner(
                    position: viewModel.queuePosition,
                    onCancel: {
                        viewModel.cancelQueuedInput()
                    }
                )
            }

            // Subagent banner
            if let subagent = viewModel.activeSubagent {
                SubagentBanner(subagent: subagent) {
                    viewModel.clearActiveSubagent()
                }
            }

            // Tool progress banner
            if let progress = viewModel.toolProgress, viewModel.pendingApproval == nil, viewModel.pendingQuestion == nil {
                ToolProgressBanner(progress: progress) {
                    viewModel.clearToolProgress()
                }
            }

            // Status bubble (fixed position, shows when agent is working)
            if viewModel.wsManager.agentState.isWorking {
                StatusBubbleView(
                    state: viewModel.wsManager.agentState,
                    tool: viewModel.wsManager.currentTool
                )
            }

            // Unified status bar
            UnifiedStatusBar(
                isProcessing: viewModel.isProcessing,
                tokenUsage: viewModel.tokenUsage,
                effectivePermissionMode: viewModel.effectivePermissionModeValue,
                projectPath: project.path,
                showQuickSettings: $viewModel.showQuickSettings
            )

            CLIInputView(
                text: $viewModel.inputText,
                selectedImages: $viewModel.selectedImages,
                isProcessing: viewModel.isProcessing,
                isAborting: viewModel.isAborting,
                projectPath: project.path,
                isFocused: _isInputFocused,
                onSend: viewModel.sendMessage,
                onAbort: { viewModel.abortSession() },
                recentMessages: viewModel.messages
            )
            .id("input-view")
        }
        .sheet(isPresented: $viewModel.showQuickSettings) {
            QuickSettingsSheet(
                tokenUsage: viewModel.tokenUsage.map { (current: $0.used, max: $0.total) }
            )
        }
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
