# Issue 12: Message Retry for Failed Messages

**Phase:** 7 (Advanced Features)
**Priority:** Medium
**Status:** Not Started
**Depends On:** Issue 04, 05, 06 (Card Views)

## Goal

Add retry capability for failed messages, showing inline retry button on error cards.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue 04, 05, 06 (Card Views).
- Add runtime or tooling dependencies here.

## Touch Set
- Files to create: TBD.
- Files to modify: TBD.

## Interface Definitions
- List new or changed models, protocols, and API payloads.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## Current State

- Failed messages show as error cards
- No retry option - user must retype or abort
- Error state tracked in message

## Solution

### Error Message Enhancement

```swift
// In ChatMessage
enum MessageStatus: Equatable {
    case sent
    case streaming
    case failed(Error)
    case retrying
}

struct ChatMessage {
    // ... existing properties
    var status: MessageStatus = .sent
    var originalContent: String?  // For retry
}
```

### Retry Button in SystemCardView

```swift
// In SystemCardView for .error role
private var errorContent: some View {
    VStack(alignment: .leading, spacing: MessageDesignSystem.Spacing.sm) {
        // Error message
        Text(message.content)
            .font(MessageDesignSystem.bodyFont())
            .foregroundStyle(.red)

        // Retry action (inline, not context menu per user preference)
        if message.canRetry {
            RetryButton(
                isRetrying: message.status == .retrying,
                onRetry: onRetry
            )
        }
    }
}
```

### RetryButton Component

```swift
struct RetryButton: View {
    let isRetrying: Bool
    let onRetry: () -> Void

    var body: some View {
        Button(action: onRetry) {
            HStack(spacing: MessageDesignSystem.Spacing.xs) {
                if isRetrying {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
                Text(isRetrying ? "Retrying..." : "Retry")
            }
            .font(MessageDesignSystem.labelFont())
            .foregroundStyle(.blue)
        }
        .disabled(isRetrying)
        .sensoryFeedback(.impact(weight: .light), trigger: isRetrying)
    }
}
```

### ChatViewModel Retry Logic

```swift
extension ChatViewModel {
    func retryMessage(_ message: ChatMessage) async {
        guard let originalContent = message.originalContent,
              message.status.isFailed else { return }

        // Update status to retrying
        updateMessage(message.id) { msg in
            msg.status = .retrying
        }

        do {
            // Remove the failed message
            removeMessage(message.id)

            // Resend the original content
            try await sendMessage(originalContent)
        } catch {
            // Re-add as failed
            addMessage(ChatMessage(
                role: .error,
                content: error.localizedDescription,
                status: .failed(error),
                originalContent: originalContent
            ))
        }
    }
}
```

### Error Types That Can Retry

```swift
extension ChatMessage {
    var canRetry: Bool {
        guard case .failed(let error) = status else { return false }

        // Only retry transient errors
        switch error {
        case is URLError:
            return true  // Network errors
        case let appError as AppError:
            return appError.isRetryable
        default:
            return false
        }
    }
}

extension AppError {
    var isRetryable: Bool {
        switch self {
        case .networkError, .timeout, .serverError:
            return true
        case .authenticationError, .invalidInput:
            return false
        }
    }
}
```

## User Flow

```
1. User sends message
2. Request fails (network error, timeout, etc.)
3. Error card appears with message + [Retry] button
4. User taps Retry
5. Button shows spinner, "Retrying..."
6. Success: Error card removed, message resent
   Failure: Error card updated with new error
```

## Files to Create

```
CodingBridge/Views/Components/
└── RetryButton.swift
```

## Files to Modify

| File | Changes |
|------|---------|
| `ChatMessage.swift` | Add `MessageStatus`, `originalContent` |
| `SystemCardView.swift` | Add retry button for error cards |
| `ChatViewModel.swift` | Add `retryMessage()` method |
| `AppError.swift` | Add `isRetryable` property |

## Acceptance Criteria

- [ ] Failed messages show inline Retry button
- [ ] Retry button shows loading state
- [ ] Successful retry removes error, resends message
- [ ] Failed retry updates error message
- [ ] Only retryable errors show button
- [ ] Haptic feedback on retry action
- [ ] Build passes

## Edge Cases

| Case | Behavior |
|------|----------|
| Multiple retries | Each retry replaces previous attempt |
| Retry during streaming | Disable retry while agent is active |
| Session expired | Show "Session expired" error, no retry |
| Auth error | No retry button, show re-authenticate message |

## Code Examples

TBD. Add concrete Swift examples before implementation.
