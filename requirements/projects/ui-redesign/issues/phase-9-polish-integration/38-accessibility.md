---
number: 38
title: Accessibility
phase: phase-9-polish-integration
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 38: Accessibility

**Phase:** 9 (Polish & Integration)
**Priority:** High
**Status:** Not Started
**Depends On:** All feature issues

## Goal

Ensure the app is fully accessible with VoiceOver, Dynamic Type, and other iOS accessibility features.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: All feature issues.
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
- [ ] Automated accessibility checks added to UI tests.
## Accessibility Checklist

| Feature | Requirements |
|---------|-------------|
| VoiceOver | All interactive elements labeled |
| Dynamic Type | All text scales with system settings |
| Reduce Motion | Animations respect system preference |
| Increase Contrast | UI visible in high contrast mode |
| Voice Control | Commands mapped to actions |
| Switch Control | All elements focusable |

### Automated Accessibility Tests

- Add UI test assertions for labels, traits, and focus order.
- Run Xcode Accessibility Inspector in CI for smoke checks (manual fallback).

## Implementation

### Accessibility Labels

```swift
// Message bubbles
Text(message.content)
    .accessibilityLabel("\(message.role.accessibilityName) message: \(message.content)")
    .accessibilityHint("Double tap to copy")

// Tool cards
ToolCardView(tool: tool)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(tool.name) tool")
    .accessibilityValue(tool.isExpanded ? "Expanded" : "Collapsed")
    .accessibilityHint("Double tap to \(tool.isExpanded ? "collapse" : "expand")")

// Status indicators
Circle()
    .fill(isConnected ? .green : .red)
    .accessibilityLabel(isConnected ? "Connected" : "Disconnected")
```

### Accessibility Traits

```swift
// Buttons
Button("Send") { ... }
    .accessibilityAddTraits(.isButton)

// Headers
Text("Settings")
    .accessibilityAddTraits(.isHeader)

// Selected items
ProjectRowView(project: project)
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])

// Loading indicators
ProgressView()
    .accessibilityLabel("Loading")
    .accessibilityAddTraits(.updatesFrequently)
```

### Dynamic Type Support

```swift
// Use scaled fonts
struct ScaledFont: ViewModifier {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    let style: Font.TextStyle
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(.system(style, design: design))
    }
}

extension View {
    func scaledFont(_ style: Font.TextStyle, design: Font.Design = .default) -> some View {
        modifier(ScaledFont(style: style, design: design))
    }
}

// Usage
Text(message.content)
    .scaledFont(.body)

Text("Title")
    .scaledFont(.headline)
```

### Reduce Motion Support

```swift
struct MotionSafeAnimation: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? .none : animation, value: UUID())
    }
}

extension View {
    func motionSafeAnimation(_ animation: Animation = .default) -> some View {
        modifier(MotionSafeAnimation(animation: animation))
    }
}

// Usage
CardView()
    .motionSafeAnimation(.spring())
```

### Reduced Motion Symbol Effects

```swift
struct AccessibleSymbolEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let isActive: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.symbolEffect(.breathe, isActive: isActive)
        }
    }
}

// Usage
Image(systemName: "sparkles")
    .modifier(AccessibleSymbolEffect(isActive: isProcessing))
```

### Accessibility Rotor

```swift
struct MessageListView: View {
    let messages: [ChatMessage]

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(messages) { message in
                    MessageView(message: message)
                }
            }
        }
        .accessibilityRotor("User Messages") {
            ForEach(messages.filter { $0.role == .user }) { message in
                AccessibilityRotorEntry(message.content, id: message.id)
            }
        }
        .accessibilityRotor("Assistant Messages") {
            ForEach(messages.filter { $0.role == .assistant }) { message in
                AccessibilityRotorEntry(message.content, id: message.id)
            }
        }
        .accessibilityRotor("Tools") {
            ForEach(messages.filter { $0.role == .toolUse }) { message in
                AccessibilityRotorEntry(message.toolName ?? "Tool", id: message.id)
            }
        }
    }
}
```

### VoiceOver Message List Structure

Ensure logical reading order and discoverable grouping:

```swift
struct MessageListView: View {
    let messages: [ChatMessage]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: MessageDesignSystem.Spacing.cardGap) {
                ForEach(messages) { message in
                    MessageCardRouter(message: message)
                        .accessibilityElement(children: .combine)
                        .accessibilitySortPriority(message.role == .user ? 2 : 1)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Message list")
        .accessibilityHint("Swipe left or right to navigate messages")
    }
}
```

### Accessibility Actions

```swift
struct MessageView: View {
    let message: ChatMessage
    @State private var showActions = false

    var body: some View {
        MessageBubble(message: message)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(message.accessibilityDescription)
            .accessibilityAction(named: "Copy") {
                UIPasteboard.general.string = message.content
            }
            .accessibilityAction(named: "Bookmark") {
                BookmarkStore.shared.toggle(message)
            }
            .accessibilityAction(named: "Share") {
                showActions = true
            }
    }
}

extension ChatMessage {
    var accessibilityDescription: String {
        let rolePrefix = role.accessibilityName
        let timeDescription = timestamp.formatted(date: .omitted, time: .shortened)
        return "\(rolePrefix) at \(timeDescription): \(content)"
    }
}

extension ChatMessage.Role {
    var accessibilityName: String {
        switch self {
        case .user: return "You said"
        case .assistant: return "Claude said"
        case .toolUse: return "Tool used"
        case .toolResult: return "Tool result"
        case .thinking: return "Claude is thinking"
        case .error: return "Error"
        }
    }
}
```

### Focus Management

```swift
struct ChatView: View {
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case input
        case search
    }

    var body: some View {
        VStack {
            MessageListView(messages: messages)

            InputView(text: $inputText)
                .focused($focusedField, equals: .input)
        }
        .onAppear {
            focusedField = .input
        }
        .onChange(of: messages) { _, _ in
            // Announce new message
            UIAccessibility.post(
                notification: .announcement,
                argument: "New message received"
            )
        }
    }
}
```

### Increase Contrast Support

```swift
struct ContrastAwareColor: View {
    @Environment(\.accessibilityContrast) var contrast
    let normalColor: Color
    let highContrastColor: Color

    var body: some View {
        Rectangle()
            .fill(contrast == .increased ? highContrastColor : normalColor)
    }
}

// Glass effect with contrast support
extension View {
    func accessibleGlassEffect() -> some View {
        modifier(AccessibleGlassModifier())
    }
}

struct AccessibleGlassModifier: ViewModifier {
    @Environment(\.accessibilityContrast) var contrast

    func body(content: Content) -> some View {
        if contrast == .increased {
            content
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary, lineWidth: 1)
                )
        } else {
            content.glassEffect()
        }
    }
}
```

### Voice Control Labels

```swift
struct SendButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.circle.fill")
        }
        .accessibilityLabel("Send message")
        .accessibilityInputLabels(["Send", "Submit", "Go", "Enter"])
    }
}
```

### Voice Control Command Examples

Add input labels for primary actions:

```swift
Button(action: startNewProject) {
    Label("New Project", systemImage: "plus")
}
.accessibilityLabel("New Project")
.accessibilityInputLabels(["New Project", "Create Project"])

Button(action: retryMessage) {
    Label("Retry", systemImage: "arrow.clockwise")
}
.accessibilityLabel("Retry message")
.accessibilityInputLabels(["Retry", "Try Again"])
```

### Accessibility Audit Helper

```swift
#if DEBUG
struct AccessibilityAuditView: View {
    @State private var auditResults: [AuditResult] = []

    var body: some View {
        List(auditResults) { result in
            HStack {
                Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(result.passed ? .green : .red)

                VStack(alignment: .leading) {
                    Text(result.check)
                        .font(.headline)
                    Text(result.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Accessibility Audit")
        .onAppear {
            runAudit()
        }
    }

    private func runAudit() {
        // Check various accessibility requirements
        auditResults = [
            AuditResult(check: "VoiceOver Labels", passed: true, details: "All elements labeled"),
            AuditResult(check: "Dynamic Type", passed: true, details: "Text scales correctly"),
            // ... more checks
        ]
    }
}

struct AuditResult: Identifiable {
    let id = UUID()
    let check: String
    let passed: Bool
    let details: String
}
#endif
```

## Testing Checklist

### VoiceOver Testing

- [ ] All buttons have descriptive labels
- [ ] Images have alt text or are decorative
- [ ] Form fields have labels
- [ ] Navigation announces destination
- [ ] Status changes are announced
- [ ] Custom controls are accessible

### Dynamic Type Testing

- [ ] Text scales from xSmall to AX5
- [ ] Layout adapts to larger text
- [ ] No text truncation at large sizes
- [ ] Icons scale appropriately
- [ ] Touch targets remain usable

### Reduce Motion Testing

- [ ] Animations disabled when preference set
- [ ] Symbol effects respect preference
- [ ] Transitions are immediate
- [ ] Loading indicators still visible

### Color/Contrast Testing

- [ ] Text contrast meets WCAG AA
- [ ] Icons visible against backgrounds
- [ ] States distinguishable by more than color
- [ ] High contrast mode supported

## Files to Create

```
CodingBridge/Accessibility/
├── AccessibilityModifiers.swift   # ~100 lines
├── ScaledFont.swift               # ~30 lines
├── MotionSafeAnimation.swift      # ~30 lines
├── AccessibilityLabels.swift      # ~50 lines
└── AccessibilityAudit.swift       # ~80 lines (DEBUG only)
```

## Files to Modify

All view files need accessibility updates:
- Add `.accessibilityLabel()` to interactive elements
- Add `.accessibilityHint()` for complex interactions
- Replace hardcoded fonts with scalable fonts
- Wrap animations with reduce motion checks

## Acceptance Criteria

- [ ] VoiceOver fully functional
- [ ] Dynamic Type supported app-wide
- [ ] Reduce Motion respected
- [ ] High Contrast mode supported
- [ ] Voice Control labels added
- [ ] Accessibility rotors for navigation
- [ ] Focus management correct
- [ ] Message list reading order verified
- [ ] Automated accessibility checks in UI tests
- [ ] No accessibility warnings in Xcode
- [ ] Build passes

## Testing

```swift
struct AccessibilityTests: XCTestCase {
    func testMessageAccessibilityLabel() {
        let message = ChatMessage(role: .user, content: "Hello")

        XCTAssertTrue(message.accessibilityDescription.contains("You said"))
        XCTAssertTrue(message.accessibilityDescription.contains("Hello"))
    }

    func testRoleAccessibilityNames() {
        XCTAssertEqual(ChatMessage.Role.user.accessibilityName, "You said")
        XCTAssertEqual(ChatMessage.Role.assistant.accessibilityName, "Claude said")
    }
}
```
