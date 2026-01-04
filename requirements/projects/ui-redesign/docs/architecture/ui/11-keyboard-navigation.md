# Keyboard Navigation


### Focus Management

```swift
struct ChatView: View {
    @FocusState private var focusedField: Field?

    enum Field {
        case input
        case messageList
    }

    var body: some View {
        VStack {
            MessageListView()
                .focused($focusedField, equals: .messageList)

            InputView()
                .focused($focusedField, equals: .input)
        }
        .onAppear {
            focusedField = .input
        }
        .keyboardShortcut("l", modifiers: .command) {
            focusedField = .input
        }
    }
}
```

### Keyboard Shortcuts

See [Issue #22](../../../issues/phase-8-ios26-platform/22-keyboard-shortcuts.md) for full keyboard shortcut implementation.

---
