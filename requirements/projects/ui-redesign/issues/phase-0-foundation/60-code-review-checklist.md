---
number: 60
title: Code Review Checklist
phase: phase-0-foundation
priority: Medium
depends_on: null
acceptance_criteria: 5
files_to_touch: 0
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 60: Code Review Checklist

**Phase:** 0 (Foundation)
**Priority:** Medium
**Status:** Not Started
**Depends On:** None
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Required Documentation

Before starting work on this issue, review these architecture and design documents:

### Core Architecture
- **[Swift 6 Concurrency Model](../../docs/architecture/data/02-swift-6-concurrency-model.md)** - Concurrency review criteria
- **[State Management](../../docs/architecture/ui/07-state-management.md)** - State management patterns to review
- **[Environment Injection](../../docs/architecture/ui/08-environment-injection.md)** - Environment injection patterns to review
- **[Dependency Injection](../../docs/architecture/data/10-dependency-injection.md)** - Dependency injection patterns to review
- **[Protocol Design](../../docs/architecture/data/09-protocol-design.md)** - Protocol patterns to review
- **[Component Hierarchy](../../docs/architecture/data/08-component-hierarchy.md)** - Component structure to review

### Design System
- **[Design System Overview](../../docs/design/README.md)** - Design consistency review
- **[Accessibility](../../docs/design/11-accessibility.md)** - Accessibility review criteria

### Foundation
- **[Design Decisions](../../docs/overview/design-decisions.md)** - Key decisions to verify in reviews
- **[Swift Style Guide](../../docs/workflows/swift-style.md)** - Coding standards reference

### Workflows
- **[Execution Guardrails](../../docs/workflows/guardrails.md)** - Development rules and constraints

## Goal

Establish a comprehensive code review checklist ensuring all contributions to the iOS 26 redesign meet quality, safety, accessibility, and performance standards.

## Scope

- In scope:
  - Swift 6 concurrency review criteria
  - iOS 26 API usage review
  - Accessibility review criteria
  - Performance review criteria
  - Security review criteria
  - UI consistency review
  - Documentation review
  - Testing review
- Out of scope:
  - Automated linting setup (separate tooling concern)
  - CI/CD integration for review enforcement
  - PR template automation

## Non-goals

- Automated code review tools
- Mandatory review assignment rules
- Review SLA enforcement

## Dependencies

- Issue #61 (Swift Style + DocC) for style standards
- Issue #63 (Error Types) for error handling patterns

## Touch Set

- Files to create:
  - `requirements/projects/ui-redesign/docs/workflows/code-review-checklist.md`
- Files to modify:
  - None (documentation only)

---

## Code Review Checklist

### 1. Swift 6 Concurrency

| Check | Pass | Fail |
|-------|------|------|
| `@Observable` classes are `final` | ✅ | ❌ Non-final @Observable |
| Dependencies marked `@ObservationIgnored` | ✅ | ❌ Timer/delegate properties observed |
| Actors used for shared mutable state | ✅ | ❌ Class with locking |
| `@MainActor` on UI-bound @Observable only | ✅ | ❌ @MainActor on non-UI type |
| `Sendable` conformance for cross-actor types | ✅ | ❌ Non-Sendable passed across actors |
| No `nonisolated(unsafe)` | ✅ | ❌ Unsafe isolation escape |
| Async methods use structured concurrency | ✅ | ❌ Detached tasks without reason |
| `Task { @MainActor in }` for UI updates from async | ✅ | ❌ Direct @Published update from bg |

#### Examples

```swift
// ✅ Correct
@Observable
final class SessionStore {
    var sessions: [Session] = []

    @ObservationIgnored
    private let repository: SessionRepository
}

// ❌ Wrong: Missing final
@Observable
class SessionStore { ... }

// ❌ Wrong: @MainActor on non-UI type
@MainActor @Observable
final class DataRepository { ... }  // Not UI-bound
```

---

### 2. iOS 26 APIs

| Check | Pass | Fail |
|-------|------|------|
| Liquid Glass via `.glassEffect()` | ✅ | ❌ `.background(.ultraThinMaterial)` |
| `NavigationSplitView` for iPad layouts | ✅ | ❌ `NavigationView` |
| Value-based `NavigationLink` | ✅ | ❌ Destination-based NavigationLink |
| `.navigationDestination(for:)` used | ✅ | ❌ Inline navigation destinations |
| `@Environment(Type.self)` for @Observable | ✅ | ❌ `@EnvironmentObject` |
| `.environment()` for @Observable injection | ✅ | ❌ `.environmentObject()` |
| `@Bindable` for two-way bindings | ✅ | ❌ `@ObservedObject` for bindings |
| `.sensoryFeedback()` for haptics | ✅ | ❌ `UIImpactFeedbackGenerator` |

#### Examples

```swift
// ✅ Correct: iOS 26 patterns
struct ChatView: View {
    @Environment(SessionStore.self) var store

    var body: some View {
        NavigationSplitView {
            List(store.sessions, selection: $selection) { session in
                NavigationLink(value: session) {
                    SessionRow(session: session)
                }
            }
            .navigationDestination(for: Session.self) { session in
                SessionDetail(session: session)
            }
        } detail: {
            // ...
        }
        .glassEffect()
    }
}

// ❌ Wrong: Legacy patterns
struct ChatView: View {
    @EnvironmentObject var store: SessionStore  // Wrong wrapper

    var body: some View {
        NavigationView {  // Wrong navigation
            List(store.sessions) { session in
                NavigationLink(destination: SessionDetail(session: session)) {
                    SessionRow(session: session)
                }
            }
        }
        .background(.ultraThinMaterial)  // Wrong material
    }
}
```

---

### 3. Accessibility

| Check | Pass | Fail |
|-------|------|------|
| All interactive elements have labels | ✅ | ❌ Icon-only button without label |
| Dynamic Type supported | ✅ | ❌ Fixed font sizes |
| Color contrast 4.5:1 minimum | ✅ | ❌ Low contrast text |
| VoiceOver navigation logical | ✅ | ❌ Random focus order |
| Reduce Motion respected | ✅ | ❌ Animations ignore preference |
| Touch targets 44x44pt minimum | ✅ | ❌ Tiny tap targets |
| Images have descriptions | ✅ | ❌ Decorative images not marked |

#### Examples

```swift
// ✅ Correct
Button(action: send) {
    Image(systemName: "arrow.up.circle.fill")
}
.accessibilityLabel("Send message")

Text(content)
    .font(.body)  // Respects Dynamic Type

Image(decorative: "background")  // Marked as decorative

// ❌ Wrong
Button(action: send) {
    Image(systemName: "arrow.up.circle.fill")
}
// Missing accessibility label

Text(content)
    .font(.system(size: 14))  // Fixed size
```

---

### 4. Performance

| Check | Pass | Fail |
|-------|------|------|
| `LazyVStack` for long lists | ✅ | ❌ `VStack` with 50+ items |
| No expensive work in body | ✅ | ❌ Filtering/sorting in body |
| Images sized appropriately | ✅ | ❌ Full-size images scaled down |
| Animations use `animation(_:value:)` | ✅ | ❌ `.animation()` without value |
| `@State` in view, not child | ✅ | ❌ @State in child recreating |
| Equatable conformance for heavy views | ✅ | ❌ Complex view without Equatable |
| Task cancelled in onDisappear | ✅ | ❌ Orphaned async work |

#### Examples

```swift
// ✅ Correct
struct MessageList: View {
    let messages: [Message]

    var body: some View {
        LazyVStack {
            ForEach(messages) { message in
                MessageRow(message: message)
            }
        }
    }
}

struct MessageRow: View, Equatable {
    let message: Message

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.message.id == rhs.message.id &&
        lhs.message.content == rhs.message.content
    }

    var body: some View {
        Text(message.content)
    }
}

// ❌ Wrong
struct MessageList: View {
    let messages: [Message]
    @State private var filtered: [Message] = []

    var body: some View {
        VStack {  // Not lazy
            ForEach(messages.filter { $0.isVisible }) { message in  // Work in body
                MessageRow(message: message)
            }
        }
    }
}
```

---

### 5. Security

| Check | Pass | Fail |
|-------|------|------|
| No hardcoded secrets | ✅ | ❌ API keys in code |
| Keychain for credentials | ✅ | ❌ `@AppStorage` for passwords |
| SSH paths properly escaped | ✅ | ❌ Direct string interpolation |
| User input validated | ✅ | ❌ Unvalidated URL construction |
| No logging of sensitive data | ✅ | ❌ Passwords in logs |
| `$HOME` not `~` in SSH commands | ✅ | ❌ Tilde in SSH paths |
| Double quotes for shell variables | ✅ | ❌ Single quotes around `$HOME` |

#### Examples

```swift
// ✅ Correct
let password = KeychainHelper.load(forKey: "ssh-password")
let path = escapePath(userPath)
let command = "cat \"\(path)\""
let sessionFile = "$HOME/.claude/projects/\(encoded)/session.jsonl"
let sshCommand = "rm -f \"\(sessionFile)\""

// ❌ Wrong
@AppStorage("password") var password = ""  // Insecure storage
let command = "cat \(userPath)"  // Command injection
let sessionFile = "~/.claude/projects/..."  // Tilde won't expand
let sshCommand = "rm -f '\(sessionFile)'"  // Single quotes block expansion
```

---

### 6. UI Consistency

| Check | Pass | Fail |
|-------|------|------|
| Uses `CLITheme` colors | ✅ | ❌ Hardcoded `.blue` |
| Follows design tokens | ✅ | ❌ Custom spacing values |
| Consistent iconography (SF Symbols) | ✅ | ❌ Mixed icon styles |
| Sheet presentation uses detents | ✅ | ❌ Full-height sheets always |
| Error states show banners | ✅ | ❌ Alert for recoverable errors |
| Loading states use skeleton | ✅ | ❌ Plain spinner |
| Empty states are informative | ✅ | ❌ Blank screen |

#### Examples

```swift
// ✅ Correct
struct MessageCard: View {
    var body: some View {
        content
            .padding(CLITheme.Spacing.medium)
            .background(CLITheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CLITheme.cornerRadius))
    }
}

// ❌ Wrong
struct MessageCard: View {
    var body: some View {
        content
            .padding(16)  // Magic number
            .background(.gray.opacity(0.1))  // Hardcoded color
            .clipShape(RoundedRectangle(cornerRadius: 12))  // Magic number
    }
}
```

---

### 7. Documentation

| Check | Pass | Fail |
|-------|------|------|
| Public types have DocC comments | ✅ | ❌ Undocumented public API |
| Complex logic has inline comments | ✅ | ❌ Obscure algorithm unexplained |
| Parameters documented | ✅ | ❌ Public func without param docs |
| MARK comments organize code | ✅ | ❌ 500+ line file without structure |
| TODO items have issue references | ✅ | ❌ `// TODO: fix this` |

#### Examples

```swift
// ✅ Correct
/// Sends a message to the Claude agent.
///
/// - Parameters:
///   - text: The message content
///   - projectPath: The project context
/// - Returns: The session ID
/// - Throws: `AppError.networkUnavailable` if disconnected
func sendMessage(_ text: String, projectPath: String) async throws -> String {
    // Implementation
}

// MARK: - WebSocket Handling

// TODO(#123): Add retry logic for transient failures

// ❌ Wrong
func sendMessage(_ text: String, projectPath: String) async throws -> String {
    // No documentation
}

// TODO: fix this later  // No issue reference
```

---

### 8. Testing

| Check | Pass | Fail |
|-------|------|------|
| New logic has unit tests | ✅ | ❌ Business logic untested |
| Edge cases covered | ✅ | ❌ Only happy path tested |
| Async tests use `await` | ✅ | ❌ `XCTestExpectation` for async |
| Mocks used for dependencies | ✅ | ❌ Tests hit real network |
| Tests are deterministic | ✅ | ❌ Flaky time-based tests |
| Accessibility tested | ✅ | ❌ No accessibility assertions |

#### Examples

```swift
// ✅ Correct
func testLoadSessions_success() async throws {
    let mockRepo = MockSessionRepository()
    mockRepo.sessionsToReturn = [.mock()]
    let store = SessionStore(repository: mockRepo)

    await store.loadSessions(for: "/test")

    XCTAssertEqual(store.sessions.count, 1)
}

func testLoadSessions_empty() async throws {
    let mockRepo = MockSessionRepository()
    mockRepo.sessionsToReturn = []
    let store = SessionStore(repository: mockRepo)

    await store.loadSessions(for: "/test")

    XCTAssertTrue(store.sessions.isEmpty)
    // Also test empty state is displayed correctly
}

// ❌ Wrong
func testLoadSessions() {
    let store = SessionStore()  // Hits real network
    let expectation = expectation(description: "load")

    store.loadSessions(for: "/test")

    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        expectation.fulfill()
    }

    wait(for: [expectation])  // Flaky
}
```

---

## Review Process

### Before Submitting

1. Run `xcodebuild test` locally
2. Self-review against this checklist
3. Ensure feature flag gating if applicable
4. Update documentation if API changed

### During Review

1. Use checklist as discussion guide
2. Request changes for any ❌ items
3. Suggest improvements for patterns
4. Verify tests cover edge cases

### After Merge

1. Monitor crash reports for 24 hours
2. Verify analytics for new code paths
3. Address any follow-up issues

---

## Acceptance Criteria

- [ ] All 8 review sections defined
- [ ] Each section has pass/fail criteria
- [ ] Code examples for each section
- [ ] Review process documented
- [ ] Checklist is actionable and concise

## Testing

Manual: Use this checklist for 5 PRs and refine based on feedback.
