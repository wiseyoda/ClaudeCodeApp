# Issue 61: Swift Style + DocC Standards

**Phase:** 0 (Foundation)
**Priority:** Medium
**Status:** Not Started
**Depends On:** None
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Goal

Define Swift formatting and documentation standards for the CodingBridge codebase, ensuring consistent code style and comprehensive DocC documentation for all public APIs.

## Scope

- In scope:
  - Swift 6.2.1 style rules
  - Naming conventions
  - DocC comment standards
  - Code organization patterns
  - Swift 6 concurrency conventions
- Out of scope:
  - Automated formatting tooling setup (SwiftFormat/SwiftLint)
  - CI integration for style checks

## Non-goals

- Enforcing style through pre-commit hooks (separate concern)
- Retroactively documenting all existing code (incremental)

## Dependencies

- None (foundational issue)

## Touch Set

- Files to create:
  - `requirements/projects/ui-redesign/docs/workflows/swift-style.md`
- Files to modify:
  - None (documentation only)

---

## Swift Style Guide

### 1. Formatting

#### Indentation and Spacing

| Rule | Value |
|------|-------|
| Indentation | 4 spaces (match Xcode default) |
| Line length | 100 characters soft limit, 120 hard limit |
| Trailing commas | Required in multiline collections |
| Blank lines | 1 between methods, 2 between types |

```swift
// ✅ Correct: Trailing commas in multiline
let options = [
    "first",
    "second",
    "third",  // Trailing comma
]

// ✅ Correct: Spacing around operators
let result = a + b * c
let range = 0..<10

// ✅ Correct: One blank line between methods
func firstMethod() {
    // ...
}

func secondMethod() {
    // ...
}
```

#### Braces and Brackets

```swift
// ✅ Correct: Opening brace on same line
func doSomething() {
    if condition {
        // ...
    } else {
        // ...
    }
}

// ✅ Correct: Closures
let sorted = items.sorted { $0.name < $1.name }

let mapped = items.map { item in
    item.transform()
}

// ✅ Correct: Multiline closure with type annotation
let handler: (Result<Data, Error>) -> Void = { result in
    switch result {
    case .success(let data):
        process(data)
    case .failure(let error):
        handle(error)
    }
}
```

---

### 2. Naming Conventions

#### Types

| Type | Convention | Example |
|------|------------|---------|
| Classes | UpperCamelCase | `ChatViewModel` |
| Structs | UpperCamelCase | `ChatMessage` |
| Enums | UpperCamelCase | `AppError` |
| Enum cases | lowerCamelCase | `.networkUnavailable` |
| Protocols | UpperCamelCase + -able/-ible/-ing | `UserFacingError` |
| Type aliases | UpperCamelCase | `MessageHandler` |

#### Properties and Methods

| Type | Convention | Example |
|------|------------|---------|
| Properties | lowerCamelCase | `isProcessing` |
| Methods | lowerCamelCase, verb-first | `sendMessage()` |
| Boolean properties | `is`, `has`, `should`, `can` prefix | `isLoading`, `hasError` |
| Factory methods | `make` prefix | `makeViewModel()` |
| Async methods | Verb indicating action | `loadSessions()` |

#### Files

| Type | Convention | Example |
|------|------------|---------|
| Single type | TypeName.swift | `ChatViewModel.swift` |
| Extensions | TypeName+Feature.swift | `ChatViewModel+StreamEvents.swift` |
| Protocols | ProtocolName.swift | `UserFacingError.swift` |
| Constants | Feature+Constants.swift | `Design+Constants.swift` |

---

### 3. Code Organization

#### File Structure

```swift
// 1. Imports (alphabetical, system first)
import Foundation
import SwiftUI

import SomeThirdParty

// 2. Type declaration
struct ChatMessage: Identifiable, Codable, Sendable {

    // MARK: - Properties

    let id: UUID
    let role: Role
    var content: String
    var isStreaming: Bool

    // MARK: - Computed Properties

    var displayName: String {
        role.displayName
    }

    // MARK: - Initialization

    init(role: Role, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.isStreaming = false
    }

    // MARK: - Methods

    func formatted() -> String {
        // ...
    }

    // MARK: - Private Methods

    private func validate() -> Bool {
        // ...
    }
}

// 3. Nested types (at end of main type or in extension)
extension ChatMessage {
    enum Role: String, Codable, Sendable {
        case user
        case assistant
        case system
    }
}

// 4. Protocol conformances (separate extensions)
extension ChatMessage: Equatable {
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}
```

#### MARK Comments

```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Protocol Name (for conformance)
```

---

### 4. Swift 6 Concurrency

#### Actors

```swift
// ✅ Correct: Actor for shared state
actor CardStatusTracker {
    private var statuses: [String: Status] = [:]

    func status(for id: String) -> Status {
        statuses[id] ?? .none
    }

    func update(_ id: String, status: Status) {
        statuses[id] = status
    }
}
```

#### @Observable

```swift
// ✅ Correct: @Observable with final
@Observable
final class SessionStore {
    var sessions: [Session] = []
    var isLoading = false

    @ObservationIgnored
    private let repository: SessionRepository

    init(repository: SessionRepository = CLIBridgeSessionRepository()) {
        self.repository = repository
    }
}
```

#### @MainActor @Observable

```swift
// ✅ Correct: For UI-bound state only
@MainActor @Observable
final class ChatViewModel {
    private(set) var messages: [ChatMessage] = []
    var inputText = ""

    func sendMessage() async {
        // Can update UI properties synchronously
        let text = inputText
        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))

        // Async work
        await processMessage(text)
    }
}
```

#### Sendable

```swift
// ✅ Correct: Sendable for cross-actor types
struct AppConfig: Sendable {
    let serverURL: URL
    let timeout: TimeInterval
}

// ✅ Correct: Sendable enum
enum AppError: Error, Sendable {
    case networkUnavailable
    case timeout
}

// ✅ Correct: Sendable closure
let handler: @Sendable (Result<Data, Error>) -> Void = { result in
    // ...
}
```

---

### 5. Error Handling

```swift
// ✅ Correct: Typed errors
func loadSession() throws(AppError) -> Session {
    guard let data = try? Data(contentsOf: url) else {
        throw .fileNotFound(path: url.path)
    }
    return try decode(data)
}

// ✅ Correct: Result for callbacks
func fetch(completion: @escaping (Result<Data, AppError>) -> Void) {
    // ...
}

// ✅ Correct: async throws
func fetchAsync() async throws -> Data {
    // ...
}
```

---

### 6. SwiftUI Patterns

#### View Structure

```swift
struct ChatView: View {
    // 1. Environment
    @Environment(\.dismiss) var dismiss
    @Environment(CLIBridgeManager.self) var bridgeManager

    // 2. State
    @State private var viewModel: ChatViewModel

    // 3. Bindings
    @Binding var selectedProject: Project?

    // 4. Let constants
    let project: Project

    // 5. Body
    var body: some View {
        content
            .navigationTitle(project.name)
            .toolbar { toolbarContent }
            .task { await viewModel.load() }
    }

    // 6. Subviews (computed properties)
    @ViewBuilder
    private var content: some View {
        // ...
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // ...
    }
}
```

#### Previews

```swift
#Preview("Default") {
    ChatView(project: .preview())
}

#Preview("Loading") {
    ChatView(project: .preview())
        .environment(\.isLoading, true)
}

#Preview("Error State") {
    ChatView(project: .preview())
        .environment(\.error, .networkUnavailable)
}
```

---

## DocC Documentation Standards

### 1. When to Document

| Element | Required | Notes |
|---------|----------|-------|
| Public types | Yes | All public/internal APIs |
| Public methods | Yes | Include parameters and returns |
| Public properties | Yes if non-obvious | Skip trivial properties |
| Private methods | If complex | Explain non-obvious logic |
| Enum cases | Yes if non-obvious | Especially with associated values |

### 2. Documentation Format

#### Type Documentation

```swift
/// A normalized message ready for UI display.
///
/// `ValidatedMessage` wraps raw wire data with validation guarantees.
/// Invalid fields are corrected with sensible defaults and recorded
/// in ``warnings`` for logging.
///
/// ## Topics
///
/// ### Creating Messages
/// - ``init(from:)``
/// - ``normalize(_:)``
///
/// ### Validation
/// - ``warnings``
/// - ``isValid``
struct ValidatedMessage {
    // ...
}
```

#### Method Documentation

```swift
/// Sends a message to the Claude agent.
///
/// The message is sent asynchronously over the WebSocket connection.
/// Progress is reported via the ``onEvent`` callback.
///
/// - Parameters:
///   - text: The message content to send
///   - projectPath: The project context for the message
///   - sessionId: Optional session ID to resume
///
/// - Throws: ``AppError/agentBusy`` if an agent is already processing
/// - Throws: ``AppError/networkUnavailable`` if not connected
///
/// - Returns: The session ID for the conversation
///
/// ## Example
///
/// ```swift
/// let sessionId = try await manager.sendMessage(
///     "Fix the login bug",
///     projectPath: "/home/dev/project"
/// )
/// ```
func sendMessage(
    _ text: String,
    projectPath: String,
    sessionId: String? = nil
) async throws -> String {
    // ...
}
```

#### Property Documentation

```swift
/// The current processing state of the agent.
///
/// When `true`, the agent is actively working on a request.
/// UI should show a loading indicator and disable input.
private(set) var isProcessing: Bool
```

#### Enum Case Documentation

```swift
/// Errors that can occur during app operations.
enum AppError: Error {
    /// The network is not available.
    ///
    /// This typically occurs when the device has no internet connection.
    /// Recovery: Check network settings and retry.
    case networkUnavailable

    /// The server could not be reached.
    ///
    /// - Parameter host: The hostname that was unreachable
    case serverUnreachable(host: String)
}
```

### 3. Special Documentation Elements

#### Code Examples

```swift
/// ## Example
///
/// ```swift
/// let store = SessionStore()
/// await store.loadSessions(for: projectPath)
/// print(store.sessions.count)
/// ```
```

#### Warnings and Notes

```swift
/// - Warning: This method must be called on the main thread.
/// - Note: The result is cached for 5 minutes.
/// - Important: Call ``cleanup()`` when done to release resources.
/// - Precondition: `id` must be a valid UUID string.
```

#### Related Symbols

```swift
/// - SeeAlso: ``ValidatedMessage`` for the output type
/// - SeeAlso: ``MessageValidationError`` for possible warnings
```

### 4. DocC Catalog Structure

```
CodingBridge.docc/
├── CodingBridge.md              # Landing page
├── GettingStarted.md            # Quick start guide
├── Architecture.md              # Architecture overview
├── Articles/
│   ├── StreamEvents.md          # WebSocket streaming
│   ├── ErrorHandling.md         # Error patterns
│   └── Concurrency.md           # Swift 6 patterns
├── Tutorials/
│   └── AddingNewFeature.tutorial
└── Resources/
    └── architecture-diagram.png
```

---

## Acceptance Criteria

- [ ] Style guide covers formatting, naming, organization
- [ ] Swift 6 concurrency patterns documented
- [ ] DocC standards with examples
- [ ] SwiftUI-specific patterns documented
- [ ] Error handling patterns documented
- [ ] File structure conventions defined

## Testing

Manual: Apply these standards to new code for 2 weeks and refine based on team feedback.
