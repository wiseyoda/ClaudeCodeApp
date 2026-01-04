# Component Patterns


### Message Cards

```swift
struct MessageCard: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Role icon
            Image(systemName: message.role.icon)
                .font(.title3)
                .foregroundStyle(message.role.color)
                .frame(width: 24)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(message.content)
            }
        }
        .padding(12)
        .glassEffect()
    }
}
```

### Tool Cards (Collapsible)

```swift
struct ToolCard: View {
    let tool: ToolUseMessage
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (always visible)
            Button {
                withAnimation(.appSpring) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: tool.icon)
                    Text(tool.name)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .sensoryFeedback(.selection, trigger: isExpanded)

            // Content (collapsible)
            if isExpanded {
                Divider()
                ToolContentView(tool: tool)
            }
        }
        .padding(12)
        .glassEffect(tint: .blue)
    }
}
```

### List Rows

```swift
struct ProjectRow: View {
    let project: Project
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.displayName)
                    .font(.headline)

                Text("\(project.sessionCount) sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.accent)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
```

### Input Fields

```swift
struct ChatInput: View {
    @Binding var text: String
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Message", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(text.isEmpty)
        }
        .padding(12)
        .glassEffect()
    }
}
```

### Status Bars

```swift
struct StatusBar: View {
    let model: ClaudeModel
    let tokenUsage: (current: Int, max: Int)
    let isProcessing: Bool

    var body: some View {
        HStack {
            // Model
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .symbolEffect(.breathe, isActive: isProcessing)
                Text(model.displayName)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()

            // Tokens
            Text("\(tokenUsage.current / 1000)k / \(tokenUsage.max / 1000)k")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect()
    }
}
```

### Sheets

```swift
struct ExampleSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            // Content
            Form {
                // Sections
            }
            .navigationTitle("Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.glass)
    }
}
```

---
