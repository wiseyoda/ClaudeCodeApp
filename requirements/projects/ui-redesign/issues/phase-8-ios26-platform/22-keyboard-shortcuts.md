# Issue 22: Keyboard Shortcuts

**Phase:** 8 (iOS 26 Platform)
**Priority:** Medium
**Status:** Not Started
**Depends On:** None

## Goal

Add comprehensive hardware keyboard support for iPad and Mac Catalyst.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- See **Depends On** header; add runtime or tooling dependencies here.
- Coordinate App Shortcuts with Issue #55.

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
## Keyboard Shortcuts

### Global Shortcuts

| Shortcut | Action | Context |
|----------|--------|---------|
| ⌘N | New chat session | Anywhere |
| ⌘K | Clear chat | ChatView |
| ⌘F | Search messages | ChatView |
| ⌘, | Open settings | Anywhere |
| ⌘/ | Show help | Anywhere |
| Escape | Abort agent / Cancel | Anywhere |

### Conflict Audit

| Shortcut | Action | Potential Conflict | Mitigation |
|----------|--------|--------------------|------------|
| ⌘N | New chat session | System "New Window" | Gate by app focus; consider alternate if conflict |
| ⌘, | Settings | Standard app settings | Keep (expected behavior) |
| ⌘L | Focus input | App-specific | Ensure it does not override text field navigation |
| ⌘F | Search messages | Standard find | Keep; scope to ChatView |
| ⌘K | Clear chat | Standard "Link" in text contexts | Only active when ChatView focused |
| ⌘/ | Help | Standard "Help" in some apps | Keep; expose in help UI |

### Chat Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘↩ | Send message |
| ⇧↩ | Insert newline |
| ⌘B | Toggle bookmark |
| ⌘C | Copy selected message |
| ⌘⇧C | Copy code block |

### Navigation Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘↑ | Previous message |
| ⌘↓ | Next message |
| ⌘Home | Scroll to top |
| ⌘End | Scroll to bottom |
| ⌘1-9 | Switch to project 1-9 |

### Session Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘S | Save session name |
| ⌘E | Export session |
| ⌘⇧D | Delete session |
| ⌘R | Resume session |

## Implementation

### Keyboard Shortcut Modifier

```swift
import SwiftUI

extension View {
    func chatKeyboardShortcuts(
        onSend: @escaping () -> Void,
        onAbort: @escaping () -> Void,
        onClear: @escaping () -> Void,
        onSearch: @escaping () -> Void,
        onScrollToBottom: @escaping () -> Void
    ) -> some View {
        self
            .keyboardShortcut(.return, modifiers: .command) { onSend() }
            .keyboardShortcut(.escape) { onAbort() }
            .keyboardShortcut("k", modifiers: .command) { onClear() }
            .keyboardShortcut("f", modifiers: .command) { onSearch() }
            .keyboardShortcut(.end, modifiers: .command) { onScrollToBottom() }
    }
}
```

### Focusable Message List

```swift
struct MessageListView: View {
    @Bindable var scrollState: MessageScrollState
    let messages: [ChatMessage]

    @FocusState private var focusedMessageId: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: MessageDesignSystem.Spacing.cardGap) {
                ForEach(messages) { message in
                    MessageCardRouter(message: message)
                        .id(message.id)
                        .focused($focusedMessageId, equals: message.id)
                        .onKeyPress(.upArrow) {
                            moveFocus(to: .previous)
                            return .handled
                        }
                        .onKeyPress(.downArrow) {
                            moveFocus(to: .next)
                            return .handled
                        }
                        .onKeyPress("c", modifiers: .command) {
                            copyMessage(message)
                            return .handled
                        }
                        .onKeyPress("b", modifiers: .command) {
                            toggleBookmark(message)
                            return .handled
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition($scrollState.position)
        .focusable()
        .focusEffectDisabled()
    }

    private func moveFocus(to direction: Direction) {
        guard let currentId = focusedMessageId,
              let currentIndex = messages.firstIndex(where: { $0.id == currentId }) else {
            focusedMessageId = messages.first?.id
            return
        }

        switch direction {
        case .previous:
            if currentIndex > 0 {
                focusedMessageId = messages[currentIndex - 1].id
            }
        case .next:
            if currentIndex < messages.count - 1 {
                focusedMessageId = messages[currentIndex + 1].id
            }
        }
    }
}
```

### ChatView with Shortcuts

```swift
struct ChatView: View {
    @State private var inputText = ""
    @State private var showSearch = false
    @FocusState private var isInputFocused: Bool

    let manager: CLIBridgeManager

    var body: some View {
        VStack {
            MessageListView(...)

            InputView(text: $inputText, onSend: sendMessage)
                .focused($isInputFocused)
        }
        .chatKeyboardShortcuts(
            onSend: sendMessage,
            onAbort: abortAgent,
            onClear: clearChat,
            onSearch: { showSearch.toggle() },
            onScrollToBottom: scrollToBottom
        )
        // Global shortcuts
        .keyboardShortcut(",", modifiers: .command) { showSettings() }
        .keyboardShortcut("/", modifiers: .command) { showHelp() }
        .keyboardShortcut("n", modifiers: .command) { newSession() }
        // Session shortcuts
        .keyboardShortcut("s", modifiers: .command) { saveSessionName() }
        .keyboardShortcut("e", modifiers: .command) { exportSession() }
        // Make input focusable with ⌘L
        .keyboardShortcut("l", modifiers: .command) {
            isInputFocused = true
        }
    }
}
```

### Project Navigation Shortcuts

```swift
struct ContentView: View {
    @State private var selectedProject: Project?
    let projects: [Project]

    var body: some View {
        NavigationSplitView {
            ProjectListView(projects: projects, selection: $selectedProject)
        } detail: {
            if let project = selectedProject {
                ChatView(project: project)
            }
        }
        // Number key shortcuts for quick project switching
        .keyboardShortcut("1", modifiers: .command) { selectProject(at: 0) }
        .keyboardShortcut("2", modifiers: .command) { selectProject(at: 1) }
        .keyboardShortcut("3", modifiers: .command) { selectProject(at: 2) }
        .keyboardShortcut("4", modifiers: .command) { selectProject(at: 3) }
        .keyboardShortcut("5", modifiers: .command) { selectProject(at: 4) }
        .keyboardShortcut("6", modifiers: .command) { selectProject(at: 5) }
        .keyboardShortcut("7", modifiers: .command) { selectProject(at: 6) }
        .keyboardShortcut("8", modifiers: .command) { selectProject(at: 7) }
        .keyboardShortcut("9", modifiers: .command) { selectProject(at: 8) }
    }

    private func selectProject(at index: Int) {
        guard index < projects.count else { return }
        selectedProject = projects[index]
    }
}
```

### Keyboard Shortcuts Help View

```swift
struct KeyboardShortcutsHelpView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Global") {
                    ShortcutRow(shortcut: "⌘N", description: "New chat session")
                    ShortcutRow(shortcut: "⌘,", description: "Settings")
                    ShortcutRow(shortcut: "⌘/", description: "Show this help")
                    ShortcutRow(shortcut: "Esc", description: "Abort / Cancel")
                }

                Section("Chat") {
                    ShortcutRow(shortcut: "⌘↩", description: "Send message")
                    ShortcutRow(shortcut: "⇧↩", description: "Insert newline")
                    ShortcutRow(shortcut: "⌘K", description: "Clear chat")
                    ShortcutRow(shortcut: "⌘F", description: "Search messages")
                    ShortcutRow(shortcut: "⌘L", description: "Focus input")
                }

                Section("Messages") {
                    ShortcutRow(shortcut: "⌘↑/↓", description: "Navigate messages")
                    ShortcutRow(shortcut: "⌘B", description: "Toggle bookmark")
                    ShortcutRow(shortcut: "⌘C", description: "Copy message")
                    ShortcutRow(shortcut: "⌘⇧C", description: "Copy code block")
                }

                Section("Sessions") {
                    ShortcutRow(shortcut: "⌘S", description: "Save session name")
                    ShortcutRow(shortcut: "⌘E", description: "Export session")
                    ShortcutRow(shortcut: "⌘R", description: "Resume session")
                }

                Section("Navigation") {
                    ShortcutRow(shortcut: "⌘1-9", description: "Switch to project")
                    ShortcutRow(shortcut: "⌘Home", description: "Scroll to top")
                    ShortcutRow(shortcut: "⌘End", description: "Scroll to bottom")
                }
            }
            .navigationTitle("Keyboard Shortcuts")
        }
        .containerBackground(.glass, for: .sheet)
    }
}

struct ShortcutRow: View {
    let shortcut: String
    let description: String

    var body: some View {
        HStack {
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.blue)
                .frame(width: 80, alignment: .leading)
            Text(description)
                .foregroundStyle(.primary)
        }
    }
}
```

## Menu Bar Commands (Mac Catalyst)

```swift
struct CodingBridgeCommands: Commands {
    @FocusedBinding(\.selectedProject) var selectedProject

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Chat") { newChat() }
                .keyboardShortcut("n", modifiers: .command)
        }

        CommandMenu("Chat") {
            Button("Send Message") { sendMessage() }
                .keyboardShortcut(.return, modifiers: .command)

            Button("Clear Chat") { clearChat() }
                .keyboardShortcut("k", modifiers: .command)

            Divider()

            Button("Search") { showSearch() }
                .keyboardShortcut("f", modifiers: .command)

            Button("Scroll to Bottom") { scrollToBottom() }
                .keyboardShortcut(.end, modifiers: .command)
        }

        CommandMenu("Agent") {
            Button("Abort") { abortAgent() }
                .keyboardShortcut(.escape, modifiers: [])

            Divider()

            Button("Approve Tool") { approveCurrentTool() }
                .keyboardShortcut("y", modifiers: .command)
                .disabled(!hasPendingApproval)

            Button("Deny Tool") { denyCurrentTool() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(!hasPendingApproval)
        }

        CommandGroup(replacing: .help) {
            Button("Keyboard Shortcuts") { showKeyboardShortcuts() }
                .keyboardShortcut("/", modifiers: .command)
        }
    }
}
```

## Files to Create

```
CodingBridge/Keyboard/
├── KeyboardShortcuts.swift             # ~100 lines
├── KeyboardShortcutsHelpView.swift     # ~80 lines
└── CodingBridgeCommands.swift          # ~60 lines (Mac Catalyst)
```

## Files to Modify

| File | Changes |
|------|---------|
| `ChatView.swift` | Add keyboard shortcut modifiers |
| `MessageListView.swift` | Add focus management, arrow key navigation |
| `ContentView.swift` | Add project number shortcuts |
| `CodingBridgeApp.swift` | Add `.commands { CodingBridgeCommands() }` |

## Acceptance Criteria

- [ ] ⌘↩ sends message
- [ ] Escape aborts agent
- [ ] ⌘K clears chat
- [ ] ⌘F opens search
- [ ] Arrow keys navigate messages when focused
- [ ] ⌘1-9 switches projects
- [ ] ⌘/ shows shortcuts help
- [ ] Mac Catalyst has menu bar commands
- [ ] All shortcuts have haptic feedback
- [ ] Conflict audit completed and documented
- [ ] Build passes

## Testing

```swift
struct KeyboardShortcutTests: XCTestCase {
    func testShortcutModifiersCompile() {
        // Verify keyboard shortcut modifiers compile
        let _ = Text("Test")
            .keyboardShortcut(.return, modifiers: .command)
    }

    func testFocusStateCompiles() {
        // Verify FocusState compiles
        struct TestView: View {
            @FocusState var focused: Bool
            var body: some View { EmptyView() }
        }
    }
}
```

## Discoverability

1. **Help Menu**: ⌘/ shows all shortcuts
2. **Tooltips**: Hover shows shortcut hint
3. **Menu Bar**: Mac Catalyst shows shortcuts in menus
4. **Onboarding**: First-launch tip about keyboard shortcuts
