# Live Activity UI Views

> Lock Screen and Dynamic Island views.

## Lock Screen View

```swift
// CodingBridgeWidgets/Views/LockScreenView.swift

struct LockScreenView: View {
    let context: ActivityViewContext<CodingBridgeActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                StatusIcon(status: context.state.status)
                Text(context.attributes.projectName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                ElapsedTimeView(seconds: context.state.elapsedSeconds)
            }

            // Content
            if let approval = context.state.approvalRequest {
                ApprovalRequestView(approval: approval)
            } else if let operation = context.state.currentOperation {
                Text(operation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Progress
            if let todo = context.state.todoProgress {
                ProgressView(value: todo.progressFraction) {
                    Text(todo.progressText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tint(.white)
            }
        }
        .padding()
        .activityBackgroundTint(backgroundColor(for: context.state.status))
    }

    private func backgroundColor(for status: ActivityStatus) -> Color {
        switch status {
        case .processing: return .blue.opacity(0.8)
        case .awaitingApproval: return .orange.opacity(0.8)
        case .awaitingAnswer: return .purple.opacity(0.8)
        case .completed: return .green.opacity(0.8)
        case .error: return .red.opacity(0.8)
        }
    }
}
```

## Status Icon

```swift
// CodingBridgeWidgets/Views/StatusIcon.swift

struct StatusIcon: View {
    let status: ActivityStatus
    var compact: Bool = false
    var minimal: Bool = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        Image(systemName: iconName)
            .font(minimal ? .caption : (compact ? .caption2 : .body))
            .foregroundStyle(iconColor)
            .symbolEffect(.pulse, isActive: status == .processing && !reduceMotion)
            .accessibilityLabel(accessibilityLabel)
    }

    private var iconName: String {
        switch status {
        case .processing: return "gear"
        case .awaitingApproval: return "hand.raised.fill"
        case .awaitingAnswer: return "questionmark.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch status {
        case .processing: return .white
        case .awaitingApproval: return .orange
        case .awaitingAnswer: return .purple
        case .completed: return .green
        case .error: return .red
        }
    }

    private var accessibilityLabel: String {
        switch status {
        case .processing: return "Processing"
        case .awaitingApproval: return "Approval needed"
        case .awaitingAnswer: return "Question pending"
        case .completed: return "Completed"
        case .error: return "Error occurred"
        }
    }
}
```

## Elapsed Time View

```swift
// CodingBridgeWidgets/Views/ElapsedTimeView.swift

struct ElapsedTimeView: View {
    let seconds: Int
    var compact: Bool = false

    var body: some View {
        Text(formattedTime)
            .font(compact ? .caption2 : .caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }

    private var formattedTime: String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}
```

## Approval Request View

```swift
// CodingBridgeWidgets/Views/ApprovalRequestView.swift

struct ApprovalRequestView: View {
    let approval: ApprovalInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.orange)
                Text("Approval Needed")
                    .font(.subheadline.bold())
            }
            Text(approval.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let remaining = approval.remainingSeconds {
                Text("\(remaining)s remaining")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
```

## Dynamic Island Expanded Bottom

```swift
struct ExpandedBottomView: View {
    let context: ActivityViewContext<CodingBridgeActivityAttributes>

    var body: some View {
        if let todo = context.state.todoProgress {
            HStack {
                Text(todo.currentTask ?? "Working...")
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
                Text(todo.progressText)
                    .font(.caption.monospacedDigit())
            }
        } else if let operation = context.state.currentOperation {
            Text(operation)
                .font(.caption)
                .lineLimit(1)
        }
    }
}
```

## Accessibility

### Dynamic Type

```swift
struct LockScreenView: View {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: scaledSpacing) {
            // Content adapts to accessibility sizes
        }
        .padding(dynamicTypeSize.isAccessibilitySize ? 16 : 12)
    }

    private var scaledSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 12 : 8
    }
}
```

### Bold Text

```swift
@Environment(\.legibilityWeight) var legibilityWeight

Text(formattedTime)
    .fontWeight(legibilityWeight == .bold ? .semibold : .regular)
```

---
**Prev:** [widget-extension](./widget-extension.md) | **Next:** [checklist](./checklist.md) | **Index:** [../00-INDEX.md](../00-INDEX.md)
