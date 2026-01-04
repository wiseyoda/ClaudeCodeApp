---
number: 30
title: Terminal Redesign
phase: phase-5-secondary-views
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 30: Terminal Redesign

**Phase:** 5 (Secondary Views)
**Priority:** Medium
**Status:** Not Started
**Depends On:** Issue #17 (Liquid Glass), Issue #23 (Navigation)

## Goal

Redesign the SSH terminal view with Liquid Glass styling, improved keyboard support, and better session management.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue #17 (Liquid Glass), Issue #23 (Navigation).
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
## Design

```
┌─────────────────────────────────────────────────────────┐
│ ←  Terminal                              ⋯  │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ user@server:~/project $ ls -la                      │ │
│ │ total 48                                            │ │
│ │ drwxr-xr-x  5 user user 4096 Dec 30 10:00 .        │ │
│ │ drwxr-xr-x 12 user user 4096 Dec 29 15:30 ..       │ │
│ │ -rw-r--r--  1 user user  256 Dec 30 09:45 .env     │ │
│ │ drwxr-xr-x  3 user user 4096 Dec 30 10:00 src      │ │
│ │ -rw-r--r--  1 user user 1024 Dec 30 09:30 README   │ │
│ │                                                     │ │
│ │ user@server:~/project $ _                          │ │
│ │                                                     │ │
│ └─────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ [^C] [Tab] [Esc] [↑] [↓] [←] [→]                   │ │
│ └─────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ $ _                                         [Send] │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Implementation

### TerminalView

```swift
struct TerminalView: View {
    @State private var viewModel = TerminalViewModel()
    @FocusState private var isInputFocused: Bool
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        VStack(spacing: 0) {
            // Terminal output
            TerminalOutputView(
                output: viewModel.output,
                isConnected: viewModel.isConnected
            )

            // Special keys bar (compact on iPad with keyboard)
            if !viewModel.hasHardwareKeyboard || sizeClass == .compact {
                SpecialKeysBar(onKey: viewModel.sendSpecialKey)
            }

            // Input field
            TerminalInputView(
                text: $viewModel.inputText,
                isConnected: viewModel.isConnected,
                onSend: { viewModel.sendCommand() }
            )
            .focused($isInputFocused)
        }
        .navigationTitle("Terminal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            TerminalToolbar(
                isConnected: viewModel.isConnected,
                onReconnect: { Task { await viewModel.reconnect() } },
                onClear: { viewModel.clearOutput() }
            )
        }
        .task {
            await viewModel.connect()
            isInputFocused = true
        }
        .onDisappear {
            viewModel.disconnect()
        }
    }
}
```

### TerminalViewModel

```swift
@MainActor @Observable
final class TerminalViewModel {
    private(set) var output: AttributedString = ""
    private(set) var isConnected = false
    private(set) var hasHardwareKeyboard = false

    var inputText = ""

    private var sshManager: SSHManager?

    func connect() async {
        sshManager = SSHManager()
        do {
            try await sshManager?.connect()
            isConnected = true
            await startReading()
        } catch {
            appendOutput("Connection failed: \(error.localizedDescription)\n", style: .error)
        }
    }

    func disconnect() {
        sshManager?.disconnect()
        isConnected = false
    }

    func reconnect() async {
        disconnect()
        await connect()
    }

    func sendCommand() {
        guard !inputText.isEmpty, isConnected else { return }
        let command = inputText
        inputText = ""

        appendOutput("$ \(command)\n", style: .command)

        Task {
            do {
                let result = try await sshManager?.executeCommand(command) ?? ""
                appendOutput(result, style: .output)
            } catch {
                appendOutput("Error: \(error.localizedDescription)\n", style: .error)
            }
        }
    }

    func sendSpecialKey(_ key: SpecialKey) {
        Task {
            try? await sshManager?.sendSpecialKey(key)
        }
    }

    func clearOutput() {
        output = ""
    }

    private func appendOutput(_ text: String, style: OutputStyle) {
        var attributed = AttributedString(text)
        attributed.foregroundColor = style.color
        attributed.font = .system(.body, design: .monospaced)
        output.append(attributed)
    }

    private func startReading() async {
        // Stream output from SSH session
    }
}

enum OutputStyle {
    case command, output, error

    var color: Color {
        switch self {
        case .command: return .accentColor
        case .output: return .primary
        case .error: return .red
        }
    }
}

enum SpecialKey: String, CaseIterable {
    case ctrlC = "^C"
    case tab = "Tab"
    case escape = "Esc"
    case up = "↑"
    case down = "↓"
    case left = "←"
    case right = "→"

    var controlSequence: String {
        switch self {
        case .ctrlC: return "\u{03}"
        case .tab: return "\t"
        case .escape: return "\u{1B}"
        case .up: return "\u{1B}[A"
        case .down: return "\u{1B}[B"
        case .left: return "\u{1B}[D"
        case .right: return "\u{1B}[C"
        }
    }
}
```

### TerminalOutputView

```swift
struct TerminalOutputView: View {
    let output: AttributedString
    let isConnected: Bool

    @State private var scrollPosition = ScrollPosition()

    var body: some View {
        ScrollView {
            Text(output)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled)
        }
        .scrollPosition($scrollPosition)
        .onChange(of: output) { _, _ in
            scrollPosition.scrollTo(edge: .bottom)
        }
        .overlay(alignment: .topTrailing) {
            if !isConnected {
                StatusBadge(text: "Disconnected", color: .red)
                    .padding()
            }
        }
        .background(Color.black.opacity(0.8))
        .glassEffectUnpadded()
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
```

### SpecialKeysBar

```swift
struct SpecialKeysBar: View {
    let onKey: (SpecialKey) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SpecialKey.allCases, id: \.self) { key in
                    Button {
                        onKey(key)
                    } label: {
                        Text(key.rawValue)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: key)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .glassEffect()
    }
}
```

### TerminalInputView

```swift
struct TerminalInputView: View {
    @Binding var text: String
    let isConnected: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("$")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            TextField("Enter command", text: $text)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .submitLabel(.send)
                .onSubmit(onSend)

            Button(action: onSend) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
            }
            .disabled(text.isEmpty || !isConnected)
        }
        .padding()
        .glassEffect()
    }
}
```

### TerminalToolbar

```swift
struct TerminalToolbar: ToolbarContent {
    let isConnected: Bool
    let onReconnect: () -> Void
    let onClear: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button(action: onReconnect) {
                    Label(isConnected ? "Reconnect" : "Connect", systemImage: "arrow.clockwise")
                }

                Button(action: onClear) {
                    Label("Clear", systemImage: "trash")
                }

                Divider()

                NavigationLink(value: NavigationDestination.sshSettings) {
                    Label("SSH Settings", systemImage: "gear")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}
```

## Keyboard Shortcuts

```swift
extension TerminalView {
    var keyboardShortcuts: some View {
        self
            .keyboardShortcut("k", modifiers: .command) // Clear
            .keyboardShortcut("r", modifiers: .command) // Reconnect
    }
}
```

## Files to Create

```
CodingBridge/Features/Terminal/
├── TerminalView.swift             # ~80 lines
├── TerminalViewModel.swift        # ~100 lines
├── TerminalOutputView.swift       # ~50 lines
├── TerminalInputView.swift        # ~40 lines
├── SpecialKeysBar.swift           # ~40 lines
└── TerminalToolbar.swift          # ~40 lines
```

## Files to Modify

| File | Changes |
|------|---------|
| Current `TerminalView.swift` | Replace with new implementation |
| `SSHManager.swift` | Add sendSpecialKey method |

## Security Checklist

- [ ] Commands with file paths use proper shell quoting
- [ ] Use `$HOME` instead of `~` in remote paths
- [ ] No secrets stored in AppStorage or logs
- [ ] User-facing errors avoid leaking sensitive data

## Acceptance Criteria

- [ ] Terminal output with monospace font
- [ ] Special keys bar for touch input
- [ ] Hardware keyboard detection
- [ ] Auto-scroll to bottom
- [ ] Text selection enabled
- [ ] Connection status indicator
- [ ] Reconnect functionality
- [ ] Clear output button
- [ ] Glass effect styling
- [ ] Security checklist complete
- [ ] Build passes

## Testing

```swift
struct TerminalViewModelTests: XCTestCase {
    func testOutputStyles() {
        let viewModel = TerminalViewModel()

        // Test that output styles have correct colors
        XCTAssertEqual(OutputStyle.command.color, .accentColor)
        XCTAssertEqual(OutputStyle.error.color, .red)
    }

    func testSpecialKeySequences() {
        XCTAssertEqual(SpecialKey.ctrlC.controlSequence, "\u{03}")
        XCTAssertEqual(SpecialKey.escape.controlSequence, "\u{1B}")
    }
}
```
