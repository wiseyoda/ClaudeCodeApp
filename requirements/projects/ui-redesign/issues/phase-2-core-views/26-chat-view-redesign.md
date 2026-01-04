---
number: 26
title: Chat View Redesign
phase: phase-2-core-views
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 26: Chat View Redesign

**Phase:** 2 (Core Views)
**Priority:** High
**Status:** Not Started
**Depends On:** Issue #23 (Navigation), Issue #17 (Liquid Glass)
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Goal

Redesign the main chat interface with Liquid Glass styling, virtualized message list, unified components, and a streaming-only status banner above the input.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue #23 (Navigation), Issue #17 (Liquid Glass).
- Add runtime or tooling dependencies here.

## Touch Set
- Files to create: TBD.
- Files to modify: TBD.

## Interface Definitions
- List new or changed models, protocols, and API payloads.

## Edge Cases
- TBD.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## iOS 26.2 Considerations

| Feature | Usage |
|---------|-------|
| `.glassEffect()` | All cards, status banner, input |
| `.scrollIndicatorsFlash()` | Flash on new messages |
| `.navigationSubtitle()` | Show session count |
| `.contentTransition(.numericText())` | Token count animation |
| `HapticManager` | Haptics on send, abort (respects global toggle) |

### Known Issue: @FocusState in safeAreaBar

Do NOT use `@FocusState` inside `.safeAreaBar()` - causes layout glitches. Use `.safeAreaInset()` instead:

```swift
// ✅ CORRECT for iOS 26.x
.safeAreaInset(edge: .bottom) {
    InputView(text: $text)
        .focused($inputFocused)
        .glassEffect()
}
```

Notes:
- Status banner appears only while streaming; it is not tappable.
- Status message collection lives in Settings (see Issue: Status Message Collection).
- Input view integrates slash command autocomplete and command palette (see Issue #35).
- Session info (model/tokens/time) should be shown in a compact toolbar/subtitle chip instead of a persistent full-width bar.

## Design

```
┌─────────────────────────────────────────────────────────┐
│ ≡  my-project                         ⋯  │  ← Toolbar
├─────────────────────────────────────────────────────────┤
│ (Session info lives in toolbar/subtitle)               │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 👤 Help me fix the login bug                       │ │  ← User message
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ ✨ I'll help you fix the login bug. Let me start   │ │  ← Assistant message
│ │    by examining the authentication code...         │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ ▶ 🔧 Bash  $ grep -r "login" src/                  │ │  ← Tool card (collapsed)
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ ▶ 📄 Result  Found 5 matches                       │ │  ← Tool result (collapsed)
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ ✨ “Searching for clues…”  …                        │ │  ← Status banner (streaming only)
│ └─────────────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ 🎤 ✚                                        [Send] │ │  ← Input view
│ │ ─────────────────────────────────────────────────── │ │
│ │ Type a message...                                  │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Implementation

### ChatView

```swift
struct ChatView: View {
    let project: Project
    let onShowSheet: (ActiveSheet) -> Void

    @State private var viewModel: ChatViewModel
    @State private var scrollState = MessageScrollState()
    @Environment(CLIBridgeManager.self) var bridgeManager

    init(project: Project, onShowSheet: @escaping (ActiveSheet) -> Void) {
        self.project = project
        self.onShowSheet = onShowSheet
        self._viewModel = State(initialValue: ChatViewModel(project: project))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Message list
            MessageListView(
                messages: viewModel.displayMessages,
                scrollState: scrollState,
                statusTracker: viewModel.statusTracker
            )

            // Interaction container (overlays when active)
            InteractionContainerView(handler: viewModel.interactionHandler)

            // Status banner (streaming only)
            if viewModel.isProcessing {
                StatusMessageBannerView(
                    message: viewModel.statusBannerMessage,
                    elapsed: viewModel.elapsedTime,
                    toolAccent: viewModel.activeToolAccent
                )
                .padding(.horizontal)
                .padding(.bottom, 4)
            }

            // Input
            InputView(
                text: $viewModel.inputText,
                isProcessing: viewModel.isProcessing,
                onSend: { Task { await viewModel.sendMessage() } },
                onAttach: { onShowSheet(.filePicker(project)) },
                onVoice: { viewModel.startVoiceInput() },
                onCommands: { onShowSheet(.commandPicker) }
            )
        }
        .navigationTitle(project.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ChatToolbar(
                project: project,
                onShowSheet: onShowSheet
            )
        }
        .task {
            await viewModel.initialize(with: bridgeManager)
        }
    }
}
```

### ChatViewModel

```swift
@MainActor @Observable
final class ChatViewModel {
    let project: Project

    // Messages
    private(set) var messages: [ChatMessage] = []
    var displayMessages: [ChatMessage] {
        messages.filter { $0.shouldDisplay }
    }

    // Input
    var inputText = ""

    // State
    private(set) var isProcessing = false
    private(set) var currentModel: ClaudeModel = .sonnet
    private(set) var tokenUsage: (current: Int, max: Int) = (0, 200_000)
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var statusBannerMessage: StatusMessage = .placeholder
    private(set) var activeToolAccent: Color? = nil

    // Trackers
    let statusTracker = CardStatusTracker()
    let interactionHandler = StreamInteractionHandler()

    // Private
    private var bridgeManager: CLIBridgeManager?
    private var elapsedTimer: Timer?
    private let statusMessageStore = StatusMessageStore.shared

    init(project: Project) {
        self.project = project
    }

    func initialize(with bridgeManager: CLIBridgeManager) async {
        self.bridgeManager = bridgeManager
        bridgeManager.onEvent = { [weak self] event in
            Task { @MainActor in
                await self?.handleStreamEvent(event)
            }
        }
        await loadHistory()
    }

    private func updateStatusBanner() {
        guard isProcessing else { return }
        statusBannerMessage = statusMessageStore.currentMessage(for: Date())
    }

    func sendMessage() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isProcessing else { return }

        let text = inputText
        inputText = ""

        // Add user message
        messages.append(ChatMessage(role: .user, content: text))

        // Start processing
        isProcessing = true
        startElapsedTimer()

        do {
            try await bridgeManager?.sendMessage(text, projectPath: project.path)
        } catch {
            messages.append(ChatMessage(role: .error, content: error.localizedDescription))
            isProcessing = false
            stopElapsedTimer()
        }
    }

    func abort() async {
        try? await bridgeManager?.abortAgent()
        isProcessing = false
        stopElapsedTimer()
    }

    private func handleStreamEvent(_ event: StreamEvent) async {
        switch event {
        case .text(let text):
            appendOrUpdateAssistantMessage(text)

        case .toolUse(let msg):
            messages.append(ChatMessage(role: .toolUse, content: msg.name, toolName: msg.name, toolInput: msg.input))
            await statusTracker.updateProgress(
                toolUseId: msg.id,
                info: ProgressInfo(toolName: msg.name, detail: msg.inputDescription, progress: nil, startTime: .now)
            )

        case .toolResult(let msg):
            messages.append(ChatMessage(role: .toolResult, content: msg.output, toolName: msg.toolName))
            await statusTracker.complete(toolUseId: msg.toolUseId)

        case .result(let msg):
            isProcessing = false
            stopElapsedTimer()
            tokenUsage = (msg.usage.inputTokens + msg.usage.outputTokens, 200_000)
            await statusTracker.clearAll()

        case .error(let errorMsg):
            messages.append(ChatMessage(role: .error, content: errorMsg))
            isProcessing = false
            stopElapsedTimer()

        case .permissionRequest(let request):
            interactionHandler.enqueue(.permission(request))

        case .askUserQuestion(let question):
            interactionHandler.enqueue(.question(question))

        // ... handle other cases
        default:
            break
        }
    }

    private func appendOrUpdateAssistantMessage(_ text: String) {
        if let lastIndex = messages.lastIndex(where: { $0.role == .assistant && $0.isStreaming }) {
            messages[lastIndex].content += text
        } else {
            messages.append(ChatMessage(role: .assistant, content: text, isStreaming: true))
        }
    }

    // Timer management
    private func startElapsedTimer() {
        elapsedTime = 0
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedTime += 1
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }
}
```

### StatusBarView

```swift
struct StatusBarView: View {
    let model: ClaudeModel
    let tokenUsage: (current: Int, max: Int)
    let elapsedTime: TimeInterval
    let isProcessing: Bool
    let onAbort: () -> Void

    var body: some View {
        HStack {
            // Model indicator
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .symbolEffect(.variableColor.iterative, isActive: isProcessing)
                Text(model.displayName)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()

            // Token usage
            Text("\(tokenUsage.current / 1000)k / \(tokenUsage.max / 1000)k")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())

            // Elapsed time
            if isProcessing {
                Text(formatTime(elapsedTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            // Abort button
            if isProcessing {
                Button(action: onAbort) {
                    Image(systemName: "stop.circle.fill")
                        .foregroundStyle(.red)
                }
                .sensoryFeedback(.warning, trigger: isProcessing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect()
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
```

### ChatToolbar

```swift
struct ChatToolbar: ToolbarContent {
    let project: Project
    let onShowSheet: (ActiveSheet) -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    onShowSheet(.sessionPicker(project))
                } label: {
                    Label("Sessions", systemImage: "clock.arrow.circlepath")
                }

                NavigationLink(value: NavigationDestination.globalSearch) {
                    Label("Search", systemImage: "magnifyingglass")
                }

                Divider()

                Button {
                    // Export
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}
```

## Files to Create

```
CodingBridge/Features/Chat/
├── ChatView.swift                 # ~100 lines
├── ChatViewModel.swift            # ~200 lines
├── StatusBarView.swift            # ~60 lines
├── ChatToolbar.swift              # ~50 lines
└── MessageListView.swift          # See Issue #11
```

## Files to Modify

| File | Changes |
|------|---------|
| Current `ChatView.swift` | Replace with new implementation |
| `CLIStatusBarViews.swift` | Consolidate into StatusBarView |

## Acceptance Criteria

- [ ] ChatView with Liquid Glass styling (respects intensity)
- [ ] StatusBarView shows model, tokens, time
- [ ] MessageListView with virtualization
- [ ] InputView with all actions (uses safeAreaInset, not safeAreaBar)
- [ ] Toolbar with menu options
- [ ] Stream events update UI correctly
- [ ] Abort button works with haptic feedback
- [ ] Token count animates with `.numericText()`
- [ ] scrollIndicatorsFlash on new messages
- [ ] Build passes on iOS 26.2+ (Xcode 26.2)

## Testing

```swift
struct ChatViewModelTests: XCTestCase {
    func testSendMessage() async {
        let viewModel = ChatViewModel(project: .mock())

        viewModel.inputText = "Hello"
        await viewModel.sendMessage()

        XCTAssertTrue(viewModel.messages.contains { $0.role == .user && $0.content == "Hello" })
        XCTAssertTrue(viewModel.inputText.isEmpty)
    }

    func testAbort() async {
        let viewModel = ChatViewModel(project: .mock())
        viewModel.isProcessing = true

        await viewModel.abort()

        XCTAssertFalse(viewModel.isProcessing)
    }
}
```
