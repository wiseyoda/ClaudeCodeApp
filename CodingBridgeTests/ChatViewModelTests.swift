import XCTest
@testable import CodingBridge

@MainActor
final class ChatViewModelTests: XCTestCase {
    private var settingsSnapshot: [String: Any?] = [:]

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        settingsSnapshot = [
            "showThinkingBlocks": defaults.object(forKey: "showThinkingBlocks"),
            "historyLimit": defaults.object(forKey: "historyLimit"),
            "defaultModel": defaults.object(forKey: "defaultModel"),
            "customModelId": defaults.object(forKey: "customModelId")
        ]
    }

    override func tearDown() {
        let defaults = UserDefaults.standard
        for (key, value) in settingsSnapshot {
            if let value {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        settingsSnapshot = [:]
        super.tearDown()
    }

    // MARK: - Initialization

    func test_initialState_defaults() {
        let (viewModel, _, _, _) = makeFixture()

        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertEqual(viewModel.inputText, "")
        XCTAssertTrue(viewModel.selectedImages.isEmpty)
        XCTAssertNil(viewModel.processingStartTime)
        XCTAssertNil(viewModel.selectedSession)
        XCTAssertFalse(viewModel.isUploadingImage)
        XCTAssertFalse(viewModel.isLoadingHistory)
        XCTAssertFalse(viewModel.scrollToBottomTrigger)
        XCTAssertEqual(viewModel.messageFilter, .all)
        XCTAssertEqual(viewModel.searchText, "")
    }

    func test_initialState_setsProjectAndSettings() {
        let settings = makeSettings()
        let project = makeProject(path: "/tmp/project-init")
        let adapter = TestCLIBridgeAdapter(settings: settings)
        let viewModel = ChatViewModel(project: project, settings: settings, wsManager: adapter)

        XCTAssertEqual(viewModel.project.path, project.path)
        XCTAssertTrue(viewModel.settings === settings)
        XCTAssertEqual(viewModel.initialGitStatus, .unknown)
    }

    // MARK: - Session Management

    func test_effectiveSessionToResume_prefersWsManagerSessionId() {
        let (viewModel, adapter, _, _) = makeFixture()
        adapter.sessionId = "session-ws"
        viewModel.selectedSession = makeSession(id: "session-selected")

        XCTAssertEqual(viewModel.effectiveSessionToResume, "session-ws")
    }

    func test_effectiveSessionToResume_nilForEphemeralSelectedSession() {
        let (viewModel, _, _, _) = makeFixture()
        viewModel.selectedSession = makeSession(id: "new-session-123")

        XCTAssertNil(viewModel.effectiveSessionToResume)
    }

    func test_effectiveSessionToResume_returnsSelectedSessionId() {
        let (viewModel, _, _, _) = makeFixture()
        viewModel.selectedSession = makeSession(id: "session-123")

        XCTAssertEqual(viewModel.effectiveSessionToResume, "session-123")
    }

    func test_effectiveSessionToResume_nilWhenNoSession() {
        let (viewModel, _, _, _) = makeFixture()

        XCTAssertNil(viewModel.effectiveSessionToResume)
    }

    func test_startNewSession_resetsStateAndAddsWelcome() {
        let (viewModel, adapter, _, _) = makeFixture()
        viewModel.messages = [ChatMessage(role: .user, content: "Hello")]
        viewModel.selectedSession = makeSession(id: "session-old")
        adapter.sessionId = "session-old"
        viewModel.scrollManager.userDidScrollUp()

        viewModel.startNewSession()

        XCTAssertNil(adapter.sessionId)
        XCTAssertTrue(viewModel.messages.count == 1)
        XCTAssertEqual(viewModel.messages.first?.role, .system)
        XCTAssertTrue(viewModel.messages.first?.content.contains("New session started") == true)
        XCTAssertTrue(viewModel.selectedSession?.id.hasPrefix("new-session-") == true)
        XCTAssertTrue(viewModel.scrollManager.isAutoScrollEnabled)
    }

    func test_selectInitialSession_usesStoredSession() {
        let project = makeProject(path: "/tmp/project-select-initial")
        let (viewModel, _, _, _) = makeFixture(project: project)
        let session = makeSession(id: "session-1")
        viewModel.sessionStore.addSession(session, for: project.path)
        MessageStore.saveSessionId(session.id, for: project.path)

        viewModel.selectInitialSession()

        XCTAssertEqual(viewModel.selectedSession?.id, session.id)
        XCTAssertNil(viewModel.sessionStore.activeSessionId(for: project.path))
    }

    func test_selectInitialSession_createsEphemeralSession() {
        let project = makeProject(path: "/tmp/project-ephemeral")
        let (viewModel, _, _, _) = makeFixture(project: project)
        MessageStore.saveSessionId("session-missing", for: project.path)

        viewModel.selectInitialSession()

        XCTAssertEqual(viewModel.selectedSession?.id, "session-missing")
        XCTAssertNil(viewModel.selectedSession?.summary)
    }

    func test_autoSelectMostRecentSession_usesStoreSessions() {
        let project = makeProject(path: "/tmp/project-store-sessions")
        let (viewModel, _, _, _) = makeFixture(project: project)
        let older = makeSession(id: "older", lastActivity: "2024-01-01T00:00:00Z")
        let newer = makeSession(id: "newer", lastActivity: "2024-02-01T00:00:00Z")
        viewModel.sessionStore.addSession(older, for: project.path)
        viewModel.sessionStore.addSession(newer, for: project.path)

        viewModel.autoSelectMostRecentSession()

        XCTAssertEqual(viewModel.selectedSession?.id, "newer")
    }

    func test_autoSelectMostRecentSession_fallsBackToProjectSessions() {
        let older = makeSession(id: "older", lastActivity: "2024-01-01T00:00:00Z")
        let newer = makeSession(id: "newer", lastActivity: "2024-02-01T00:00:00Z")
        let project = makeProject(path: "/tmp/project-embedded", sessions: [older, newer])
        let (viewModel, _, _, _) = makeFixture(project: project)

        viewModel.autoSelectMostRecentSession()

        XCTAssertEqual(viewModel.selectedSession?.id, "newer")
    }

    func test_selectMostRecentSession_setsSessionAndLoadsHistory() {
        let project = makeProject(path: "/tmp/project-select-most-recent")
        let settings = makeSettings()
        let adapter = TestCLIBridgeAdapter(settings: settings)
        let viewModel = TestChatViewModel(project: project, settings: settings, wsManager: adapter)
        let session = makeSession(id: "session-1")

        viewModel.selectMostRecentSession(from: [session])

        XCTAssertEqual(viewModel.selectedSession?.id, "session-1")
        XCTAssertEqual(adapter.sessionId, "session-1")
        XCTAssertTrue(viewModel.didLoadSessionHistory)
        XCTAssertEqual(MessageStore.loadSessionId(for: project.path), "session-1")
    }

    func test_selectSession_setsSessionAndLoadsHistory() {
        let project = makeProject(path: "/tmp/project-select-session")
        let settings = makeSettings()
        let adapter = TestCLIBridgeAdapter(settings: settings)
        let viewModel = TestChatViewModel(project: project, settings: settings, wsManager: adapter)
        let session = makeSession(id: "session-2")

        viewModel.selectSession(session)

        XCTAssertEqual(viewModel.selectedSession?.id, "session-2")
        XCTAssertEqual(adapter.sessionId, "session-2")
        XCTAssertTrue(viewModel.didLoadSessionHistory)
    }

    // MARK: - Input Handling

    func test_appendToInput_whenEmpty_appendsWithSpace() {
        let (viewModel, _, _, _) = makeFixture()

        viewModel.appendToInput("Hello")

        XCTAssertEqual(viewModel.inputText, "Hello ")
    }

    func test_appendToInput_whenEndsWithSpace_appendsWithSpace() {
        let (viewModel, _, _, _) = makeFixture()
        viewModel.inputText = "Hello "

        viewModel.appendToInput("World")

        XCTAssertEqual(viewModel.inputText, "Hello World ")
    }

    func test_appendToInput_whenNoTrailingSpace_insertsSpace() {
        let (viewModel, _, _, _) = makeFixture()
        viewModel.inputText = "Hello"

        viewModel.appendToInput("World")

        XCTAssertEqual(viewModel.inputText, "Hello World ")
    }

    func test_sendMessage_addsUserMessageAndClearsInput() {
        let (viewModel, adapter, _, project) = makeFixture()
        viewModel.inputText = "Hello"

        viewModel.sendMessage()

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.role, .user)
        XCTAssertEqual(viewModel.messages.first?.content, "Hello")
        XCTAssertEqual(viewModel.inputText, "")
        XCTAssertTrue(viewModel.selectedImages.isEmpty)
        XCTAssertNotNil(viewModel.processingStartTime)
        XCTAssertEqual(adapter.sentMessages.count, 1)
        XCTAssertEqual(adapter.sentMessages.first?.text, "Hello")
        XCTAssertEqual(adapter.sentMessages.first?.projectPath, project.path)
    }

    func test_sendMessage_ignoresEmptyMessage() {
        let (viewModel, adapter, _, _) = makeFixture()
        viewModel.inputText = "   "

        viewModel.sendMessage()

        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertTrue(adapter.sentMessages.isEmpty)
    }

    func test_sendMessage_withImagesUsesDefaultPrompt() {
        let (viewModel, adapter, _, _) = makeFixture()
        let imageData = Data(repeating: 0x1, count: 10)
        viewModel.selectedImages = [ImageAttachment(data: imageData)]

        viewModel.sendMessage()

        XCTAssertEqual(viewModel.messages.first?.content, "[Image attached]")
        XCTAssertEqual(adapter.sentMessages.first?.text, "What is this image?")
    }

    // MARK: - Slash Commands

    func test_handleSlashCommand_helpShowsSheet() {
        let (viewModel, _, _, _) = makeFixture()

        let handled = viewModel.handleSlashCommand("/help")

        XCTAssertTrue(handled)
        XCTAssertTrue(viewModel.showingHelpSheet)
    }

    func test_handleSlashCommand_exitDisconnects() {
        let (viewModel, adapter, _, _) = makeFixture()

        let handled = viewModel.handleSlashCommand("/exit")

        XCTAssertTrue(handled)
        XCTAssertTrue(adapter.disconnectCalled)
    }

    func test_handleSlashCommand_statusAddsSystemMessage() {
        let (viewModel, adapter, _, _) = makeFixture()
        adapter.connectionState = .connected
        adapter.sessionId = "session-123"
        adapter.tokenUsage = TokenUsage(used: 5, total: 10)

        let handled = viewModel.handleSlashCommand("/status")

        XCTAssertTrue(handled)
        XCTAssertEqual(viewModel.messages.last?.role, .system)
        XCTAssertTrue(viewModel.messages.last?.content.contains("Connection: Connected") == true)
        XCTAssertTrue(viewModel.messages.last?.content.contains("Tokens: 5/10") == true)
    }

    func test_handleClearCommand_clearsMessagesAndCreatesEphemeralSession() {
        let (viewModel, adapter, _, _) = makeFixture()
        viewModel.messages = [ChatMessage(role: .user, content: "Hello")]
        viewModel.selectedSession = makeSession(id: "session-1")
        adapter.sessionId = "session-1"

        viewModel.handleClearCommand()

        // Should create ephemeral session (not nil) to prevent invalid state
        XCTAssertNotNil(viewModel.selectedSession)
        XCTAssertTrue(viewModel.selectedSession?.id.hasPrefix("new-session-") ?? false)
        XCTAssertNil(adapter.sessionId)
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.role, .system)
    }

    // MARK: - WebSocket Callbacks

    func test_webSocket_onTextCommit_appendsAssistantMessage() {
        let (viewModel, adapter, _, _) = makeFixture()
        viewModel.setupWebSocketCallbacks()

        adapter.onTextCommit?("Hello")

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.role, .assistant)
        XCTAssertEqual(viewModel.messages.first?.content, "Hello")
    }

    func test_webSocket_onToolUse_addsToolUseMessage() {
        let (viewModel, adapter, _, _) = makeFixture()
        viewModel.setupWebSocketCallbacks()

        adapter.onToolUse?("tool-1", "Shell", "ls")

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.role, .toolUse)
        XCTAssertEqual(viewModel.messages.first?.content, "Shell(ls)")
    }

    func test_webSocket_onToolUse_tracksSubagentTool() {
        let (viewModel, adapter, _, _) = makeFixture()
        viewModel.setupWebSocketCallbacks()
        adapter.activeSubagent = CLISubagentStartContent(description: "Task")

        adapter.onToolUse?("tool-2", "Shell", "ls")

        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertTrue(viewModel.subagentToolIds.contains("tool-2"))
    }

    func test_webSocket_onToolResult_filtersSubagentResult() {
        let (viewModel, adapter, _, _) = makeFixture()
        viewModel.setupWebSocketCallbacks()
        adapter.activeSubagent = CLISubagentStartContent(description: "Task")

        adapter.onToolUse?("tool-3", "Shell", "ls")
        adapter.onToolResult?("tool-3", "Shell", "done")

        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertFalse(viewModel.subagentToolIds.contains("tool-3"))
    }

    func test_webSocket_onToolResult_filtersTaskTool() {
        let (viewModel, adapter, _, _) = makeFixture()
        viewModel.setupWebSocketCallbacks()

        adapter.onToolResult?("tool-4", "Task", "done")

        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func test_webSocket_onToolResult_addsToolResultMessage() {
        let (viewModel, adapter, _, _) = makeFixture()
        viewModel.setupWebSocketCallbacks()

        adapter.onToolResult?("tool-5", "Shell", "done")

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.role, .toolResult)
        XCTAssertEqual(viewModel.messages.first?.content, "done")
    }

    func test_webSocket_onThinking_appendsThinkingMessage() {
        let (viewModel, adapter, _, _) = makeFixture()
        viewModel.setupWebSocketCallbacks()

        adapter.onThinking?("thinking")

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.role, .thinking)
        XCTAssertEqual(viewModel.messages.first?.content, "thinking")
    }

    func test_webSocket_onError_appendsErrorMessageAndClearsProcessingTime() {
        let (viewModel, adapter, _, _) = makeFixture()
        viewModel.setupWebSocketCallbacks()
        viewModel.processingStartTime = Date()

        adapter.onError?("failure")

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.role, .error)
        XCTAssertTrue(viewModel.messages.first?.content.contains("failure") == true)
        XCTAssertNil(viewModel.processingStartTime)
    }

    func test_webSocket_onAborted_appendsSystemMessage() {
        let (viewModel, adapter, _, _) = makeFixture()
        viewModel.setupWebSocketCallbacks()

        adapter.onAborted?()

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.role, .system)
        XCTAssertTrue(viewModel.messages.first?.content.contains("Task aborted") == true)
    }

    func test_webSocket_onSessionRecovered_clearsSessionId() {
        let (viewModel, adapter, _, project) = makeFixture()
        viewModel.setupWebSocketCallbacks()
        adapter.sessionId = "session-9"
        MessageStore.saveSessionId("session-9", for: project.path)

        adapter.onSessionRecovered?()

        XCTAssertNil(adapter.sessionId)
        XCTAssertEqual(viewModel.messages.last?.role, .system)
        XCTAssertNil(MessageStore.loadSessionId(for: project.path))
    }

    func test_webSocket_onSessionAttached_appendsSystemMessage() {
        let (viewModel, adapter, _, _) = makeFixture()
        viewModel.setupWebSocketCallbacks()

        adapter.onSessionAttached?()

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.role, .system)
        XCTAssertTrue(viewModel.messages.first?.content.contains("Reconnected") == true)
    }

    func test_webSocket_onHistory_insertsMessagesAtStart() {
        let (viewModel, adapter, _, _) = makeFixture()
        viewModel.setupWebSocketCallbacks()
        viewModel.messages = [ChatMessage(role: .user, content: "Existing")]
        // Use unified StoredMessage format for history
        let history = StoredMessage(
            id: "h1",
            timestamp: "2025-01-01T12:00:00Z",
            message: .assistant(CLIAssistantContent(content: "History", delta: nil))
        )

        adapter.onHistory?(CLIHistoryPayload(messages: [history], hasMore: false, cursor: nil))

        XCTAssertEqual(viewModel.messages.first?.content, "History")
        XCTAssertEqual(viewModel.messages.last?.content, "Existing")
    }

    // MARK: - Display Messages

    func test_refreshDisplayMessagesCache_hidesThinkingBlocksWhenDisabled() {
        let settings = makeSettings()
        settings.showThinkingBlocks = false
        let (viewModel, _, _, _) = makeFixture(settings: settings)
        viewModel.messages = [
            ChatMessage(role: .thinking, content: "thinking"),
            ChatMessage(role: .assistant, content: "answer")
        ]

        viewModel.refreshDisplayMessagesCache()

        XCTAssertEqual(viewModel.displayMessages.count, 1)
        XCTAssertEqual(viewModel.displayMessages.first?.role, .assistant)
    }

    func test_refreshDisplayMessagesCache_filtersByMessageFilter() {
        let (viewModel, _, _, _) = makeFixture()
        viewModel.messages = [
            ChatMessage(role: .user, content: "User"),
            ChatMessage(role: .assistant, content: "Assistant")
        ]
        viewModel.messageFilter = .assistant

        viewModel.refreshDisplayMessagesCache()

        XCTAssertEqual(viewModel.displayMessages.count, 1)
        XCTAssertEqual(viewModel.displayMessages.first?.role, .assistant)
    }

    func test_refreshDisplayMessagesCache_filtersBySearchText() {
        let (viewModel, _, _, _) = makeFixture()
        viewModel.messages = [
            ChatMessage(role: .assistant, content: "match this"),
            ChatMessage(role: .assistant, content: "ignore this")
        ]
        viewModel.searchText = "match"

        viewModel.refreshDisplayMessagesCache()

        XCTAssertEqual(viewModel.displayMessages.count, 1)
        XCTAssertEqual(viewModel.displayMessages.first?.content, "match this")
    }

    func test_refreshDisplayMessagesCache_appliesHistoryLimit() {
        let settings = makeSettings()
        settings.historyLimit = .small
        let (viewModel, _, _, _) = makeFixture(settings: settings)
        viewModel.messages = (0..<30).map { index in
            ChatMessage(role: .assistant, content: "message-\(index)")
        }

        viewModel.refreshDisplayMessagesCache()

        XCTAssertEqual(viewModel.displayMessages.count, 25)
        XCTAssertEqual(viewModel.displayMessages.first?.content, "message-5")
    }

    // MARK: - State & Model

    func test_stateBindings_reflectWsManagerFields() {
        let settings = makeSettings()
        let adapter = TestCLIBridgeAdapter(settings: settings)
        let project = makeProject(path: "/tmp/project-state-bindings")
        let viewModel = ChatViewModel(project: project, settings: settings, wsManager: adapter)
        let approval = ApprovalRequest(id: "req-1", toolName: "bash", input: ["command": "ls"], receivedAt: Date())
        let question = AskUserQuestionData(requestId: "q1", questions: [
            UserQuestion(question: "Continue?", header: nil, options: [], multiSelect: false)
        ])

        adapter.connectionState = .connected
        adapter.isReattaching = true
        adapter.isProcessing = true
        adapter.isAborting = true
        adapter.currentText = "streaming"
        adapter.tokenUsage = TokenUsage(used: 3, total: 7)
        adapter.pendingApproval = approval
        adapter.pendingQuestion = question
        adapter.isInputQueued = true
        adapter.queuePosition = 2
        adapter.activeSubagent = CLISubagentStartContent(description: "Task")
        adapter.toolProgress = CLIProgressContent(tool: "Shell")
        adapter.sessionId = "session-1"

        XCTAssertTrue(viewModel.isConnected)
        XCTAssertTrue(viewModel.isReattaching)
        XCTAssertTrue(viewModel.isProcessing)
        XCTAssertTrue(viewModel.isAborting)
        XCTAssertEqual(viewModel.currentStreamingText, "streaming")
        XCTAssertEqual(viewModel.tokenUsage, TokenUsage(used: 3, total: 7))
        XCTAssertEqual(viewModel.pendingApproval, approval)
        XCTAssertEqual(viewModel.pendingQuestion?.requestId, "q1")
        XCTAssertTrue(viewModel.isInputQueued)
        XCTAssertEqual(viewModel.queuePosition, 2)
        XCTAssertEqual(viewModel.activeSubagent?.displayAgentType, "Task")
        XCTAssertEqual(viewModel.toolProgress?.tool, "Shell")
        XCTAssertEqual(viewModel.activeSessionId, "session-1")
    }

    func test_handleProcessingChange_updatesStreamingMetadata() {
        let (viewModel, _, _, _) = makeFixture()
        let previousId = viewModel.streamingMessageId
        let previousTimestamp = viewModel.streamingMessageTimestamp

        viewModel.handleProcessingChange(oldValue: false, isProcessing: true)

        XCTAssertNotEqual(viewModel.streamingMessageId, previousId)
        XCTAssertTrue(viewModel.streamingMessageTimestamp >= previousTimestamp)
    }

    func test_handleModelChange_callsSwitchModelWhenConnected() {
        let settings = makeSettings()
        let adapter = TestCLIBridgeAdapter(settings: settings)
        let project = makeProject(path: "/tmp/project-model-change")
        let viewModel = ChatViewModel(project: project, settings: settings, wsManager: adapter)
        adapter.connectionState = .connected

        viewModel.handleModelChange(oldModel: .haiku, newModel: .sonnet)

        XCTAssertEqual(adapter.switchModelCalls, [.sonnet])
    }

    // MARK: - Helpers

    private func makeSettings() -> AppSettings {
        return AppSettings()
    }

    private func makeProject(path: String = "/tmp/project-\(UUID().uuidString)", sessions: [ProjectSession]? = nil) -> Project {
        Project(
            name: "TestProject",
            path: path,
            displayName: nil,
            fullPath: nil,
            sessions: sessions,
            sessionMeta: nil
        )
    }

    private func makeSession(
        id: String = "session-\(UUID().uuidString)",
        summary: String? = "Summary",
        messageCount: Int? = 1,
        lastActivity: String? = "2024-01-01T00:00:00Z",
        lastUserMessage: String? = "Hello",
        lastAssistantMessage: String? = "Hi"
    ) -> ProjectSession {
        ProjectSession(
            id: id,
            summary: summary,
            lastActivity: lastActivity,
            messageCount: messageCount,
            lastUserMessage: lastUserMessage,
            lastAssistantMessage: lastAssistantMessage
        )
    }

    private func makeFixture(
        project: Project? = nil,
        settings: AppSettings? = nil,
        adapter: TestCLIBridgeAdapter? = nil
    ) -> (ChatViewModel, TestCLIBridgeAdapter, AppSettings, Project) {
        let settings = settings ?? makeSettings()
        let adapter = adapter ?? TestCLIBridgeAdapter(settings: settings)
        let project = project ?? makeProject()
        let viewModel = ChatViewModel(project: project, settings: settings, wsManager: adapter)
        return (viewModel, adapter, settings, project)
    }
}

@MainActor
final class TestChatViewModel: ChatViewModel {
    var didLoadSessionHistory = false

    override func loadSessionHistory(_ session: ProjectSession) {
        didLoadSessionHistory = true
    }
}

@MainActor
final class TestCLIBridgeAdapter: CLIBridgeAdapter {
    struct SentMessage: Equatable {
        let text: String
        let projectPath: String
        let resumeSessionId: String?
        let permissionMode: String?
        let images: [ImageAttachment]?
        let model: String?
    }

    private(set) var sentMessages: [SentMessage] = []
    private(set) var disconnectCalled = false
    private(set) var switchModelCalls: [ClaudeModel] = []

    init(settings: AppSettings) {
        super.init(settings: settings)
    }

    override func sendMessage(
        _ message: String,
        projectPath: String,
        resumeSessionId: String? = nil,
        permissionMode: String? = nil,
        images: [ImageAttachment]? = nil,
        model: String? = nil
    ) {
        sentMessages.append(SentMessage(
            text: message,
            projectPath: projectPath,
            resumeSessionId: resumeSessionId,
            permissionMode: permissionMode,
            images: images,
            model: model
        ))
    }

    override func disconnect() {
        disconnectCalled = true
    }

    override func switchModel(to model: ClaudeModel) {
        switchModelCalls.append(model)
    }

    override func attachToSession(sessionId: String, projectPath: String) {
        // Synchronously set sessionId for testing (real implementation is async)
        self.sessionId = sessionId
    }
}
