# ClaudeCodeApp Hardening Plan

> Technical debt cleanup and architecture improvements before adding new features.

---

## Priority Order

1. **Foundation** - Settings injection + Theme migration
2. **Structure** - Break up ChatView.swift + Extract modules
3. **Reliability** - Error handling + Retry logic + Storage fix
4. **Quality** - Unit tests + Accessibility

---

## Phase 1: Foundation

### 1.1 Fix AppSettings Injection Pattern

**Problem**: `ContentView` and `ChatView` create new `AppSettings()` instances in their `init()` methods instead of using the EnvironmentObject, causing state divergence.

**Current (broken)**:
```swift
// ContentView.swift:12-14
init() {
    let settings = AppSettings()
    _apiClient = StateObject(wrappedValue: APIClient(settings: settings))
}

// ChatView.swift:26-32
init(project: Project, apiClient: APIClient) {
    self.project = project
    self.apiClient = apiClient
    let settings = AppSettings()  // <- New instance, not shared!
    _wsManager = StateObject(wrappedValue: WebSocketManager(settings: settings))
}
```

**Solution**: Use a factory pattern or pass settings through navigation:

```swift
// Option A: Access settings in onAppear instead of init
struct ChatView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var wsManager = WebSocketManager()

    var body: some View { ... }
        .onAppear {
            wsManager.updateSettings(settings)
        }
}

// Option B: Create managers lazily with observed settings
@MainActor
class WebSocketManager: ObservableObject {
    private var settings: AppSettings?

    func configure(with settings: AppSettings) {
        self.settings = settings
    }
}
```

**Files to modify**:
- [ ] `ContentView.swift` - Remove `AppSettings()` from init
- [ ] `ChatView.swift` - Remove `AppSettings()` from init, use `.onAppear` pattern
- [ ] `APIClient.swift` - Accept settings via configure method
- [ ] `WebSocketManager.swift` - Already has `updateSettings()`, just need to remove init param

**Verification**: Build + test that changing a setting (e.g., font size) immediately reflects in all views.

---

### 1.2 Complete Theme Migration

**Problem**: `Theme.swift` has both legacy static colors and ColorScheme-aware functions. Many views still use the static versions which don't respect light mode.

**Current State**:
```swift
// Legacy (dark-mode only):
CLITheme.background
CLITheme.primaryText

// Correct (scheme-aware):
CLITheme.background(for: colorScheme)
CLITheme.primaryText(for: colorScheme)
```

**Migration checklist**:

| File | Static Uses | Migration Status |
|------|-------------|------------------|
| ChatView.swift | ~40 uses | [ ] Pending |
| ContentView.swift | ~15 uses | [ ] Pending |
| TerminalView.swift | ~25 uses | [ ] Pending |
| UserQuestionsView.swift | ~10 uses | [x] Already migrated |

**Pattern to apply**:
```swift
// Before:
.background(CLITheme.background)
.foregroundColor(CLITheme.primaryText)

// After:
@Environment(\.colorScheme) var colorScheme
// ...
.background(CLITheme.background(for: colorScheme))
.foregroundColor(CLITheme.primaryText(for: colorScheme))
```

**After all migrations**: Remove legacy static properties from Theme.swift.

---

## Phase 2: Structure

### 2.1 Break Up ChatView.swift (2,346 lines)

**Target**: Split into focused, testable modules under 300 lines each.

**Extraction Plan**:

```
ChatView.swift (2,346 lines)
├── ChatView.swift (~400 lines) - Main view, state management, callbacks
├── MessageViews/
│   ├── CLIMessageView.swift (~150 lines) - Message display
│   ├── DiffView.swift (~90 lines) - Edit tool diff display
│   ├── TodoListView.swift (~150 lines) - TodoWrite visualization
│   └── StreamingIndicator.swift (~50 lines)
├── InputViews/
│   ├── CLIInputView.swift (~150 lines) - Text input, image picker, voice
│   ├── CLIModeSelector.swift (~30 lines)
│   └── CLIStatusBar.swift (~100 lines)
├── MarkdownParser/
│   ├── MarkdownText.swift (~400 lines) - Block parsing, rendering
│   ├── CodeBlockView.swift (~50 lines)
│   └── MathBlockView.swift (~60 lines)
├── SessionViews/
│   ├── SessionPicker.swift (~60 lines)
│   ├── SessionPickerSheet.swift (~100 lines)
│   └── SlashCommandHelpSheet.swift (~80 lines)
└── Extensions/
    └── String+Markdown.swift (~100 lines) - processedForDisplay, etc.
```

**Extraction order** (lowest risk first):
1. `String+Markdown.swift` - Pure functions, easy to test
2. `CodeBlockView.swift`, `MathBlockView.swift` - Self-contained views
3. `DiffView.swift`, `TodoListView.swift` - Self-contained with parsers
4. `SessionPicker.swift`, `SessionPickerSheet.swift` - Navigation views
5. `CLIStatusBar.swift`, `CLIModeSelector.swift` - Status views
6. `MarkdownText.swift` - Complex but self-contained
7. `CLIInputView.swift` - Depends on SpeechManager
8. `CLIMessageView.swift` - Depends on extracted views

---

### 2.2 Extract Shared Utilities

**Create `Utilities/` folder**:

```swift
// Utilities/ImageUtilities.swift
enum ImageUtilities {
    /// Detect MIME type from image data magic bytes
    static func detectMediaType(from data: Data) -> String {
        guard data.count >= 4 else { return "image/jpeg" }
        let bytes = [UInt8](data.prefix(4))

        // PNG: 89 50 4E 47
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "image/png"
        }
        // GIF: 47 49 46 38
        if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38 {
            return "image/gif"
        }
        // WebP: RIFF...WEBP
        if bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 {
            if data.count >= 12 {
                let webpBytes = [UInt8](data[8..<12])
                if webpBytes == [0x57, 0x45, 0x42, 0x50] {
                    return "image/webp"
                }
            }
        }
        return "image/jpeg"
    }
}
```

**Remove duplicates from**:
- [ ] `APIClient.swift:254-279` - `detectMimeType`
- [ ] `WebSocketManager.swift:479-503` - `detectMediaType`

---

## Phase 3: Reliability

### 3.1 Fix MessageStore Storage

**Problem**: UserDefaults has size limits (~4MB on iOS). Storing image data as base64 can quickly exceed this.

**Solution**: File-based storage with Core Data metadata (or pure file-based).

```swift
// Proposed: Utilities/MessageStore.swift

class MessageStore {
    private static let messagesDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Messages", isDirectory: true)
    }()

    static func loadMessages(for projectPath: String) -> [ChatMessage] {
        let file = messagesFile(for: projectPath)
        guard let data = try? Data(contentsOf: file) else { return [] }

        // Decode messages, but image data is stored separately
        let messages = try? JSONDecoder().decode([ChatMessageDTO].self, from: data)
        return messages?.map { $0.toChatMessage(loadingImagesFrom: imageDirectory(for: projectPath)) } ?? []
    }

    static func saveMessages(_ messages: [ChatMessage], for projectPath: String) {
        // Save message metadata to JSON
        // Save image data to separate files
        // Keep only last 50 messages
    }
}
```

**Migration plan**:
1. Create new file-based storage
2. Add migration from UserDefaults on first launch
3. Clear old UserDefaults keys after migration

---

### 3.2 Improve Error Handling

**Add user-facing error alerts**:

```swift
// Proposed: Utilities/ErrorHandler.swift

enum AppError: LocalizedError {
    case networkUnavailable
    case serverUnreachable(String)
    case authenticationFailed
    case sessionExpired
    case messageFailed(String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "No internet connection"
        case .serverUnreachable(let url):
            return "Cannot reach server at \(url)"
        case .authenticationFailed:
            return "Authentication failed. Check credentials in Settings."
        case .sessionExpired:
            return "Session expired. Please reconnect."
        case .messageFailed(let reason):
            return "Message failed: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .serverUnreachable:
            return "Check that Tailscale is connected and the server is running."
        case .authenticationFailed:
            return "Go to Settings to update your API key or credentials."
        default:
            return nil
        }
    }
}
```

**Add retry logic for WebSocket messages**:

```swift
// WebSocketManager additions

struct PendingMessage {
    let id: UUID
    let message: String
    let projectPath: String
    let sessionId: String?
    let permissionMode: String?
    let imageData: Data?
    var attempts: Int = 0
    let createdAt: Date = Date()
}

private var messageQueue: [PendingMessage] = []
private let maxRetries = 3
private let retryDelays: [TimeInterval] = [1, 2, 4]  // Exponential backoff

private func retryFailedMessages() {
    for (index, pending) in messageQueue.enumerated() {
        guard pending.attempts < maxRetries else {
            // Give up, notify user
            onError?("Message failed after \(maxRetries) attempts")
            messageQueue.remove(at: index)
            continue
        }

        let delay = retryDelays[min(pending.attempts, retryDelays.count - 1)]
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            // Retry send...
        }
    }
}
```

---

### 3.3 Add Error Logging

```swift
// Proposed: Utilities/Logger.swift

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

struct Logger {
    static let shared = Logger()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    func log(_ level: LogLevel, _ message: String, file: String = #file, line: Int = #line) {
        let filename = (file as NSString).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] [\(level.rawValue)] [\(filename):\(line)] \(message)")

        // Could also write to file for later retrieval
    }
}

// Usage:
Logger.shared.log(.error, "WebSocket connection failed: \(error)")
```

---

## Phase 4: Quality

### 4.1 Add Unit Tests

**Test targets to create**:

```
ClaudeCodeAppTests/
├── MarkdownParserTests.swift     - Test block parsing, inline formatting
├── MessageStoreTests.swift        - Test save/load, migration, size limits
├── TodoListParserTests.swift      - Test TodoWrite JSON parsing
├── DiffParserTests.swift          - Test Edit tool content parsing
├── ImageUtilitiesTests.swift      - Test MIME type detection
├── WebSocketMessageTests.swift    - Test message encoding/decoding
└── SessionHistoryLoaderTests.swift - Test JSONL parsing
```

**Example test**:

```swift
// MarkdownParserTests.swift
import XCTest
@testable import ClaudeCodeApp

final class MarkdownParserTests: XCTestCase {

    func testNumberedListWithSubItems() {
        let input = """
        1. First item
           - Sub item A
           - Sub item B
        2. Second item
        """

        let blocks = MarkdownParser.parseBlocks(input)

        XCTAssertEqual(blocks.count, 1)
        guard case .numberedList(let items) = blocks[0] else {
            XCTFail("Expected numbered list")
            return
        }
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items[0].contains("Sub item A"))
    }

    func testCodeBlockExtraction() {
        let input = """
        ```swift
        let x = 1
        ```
        """

        let blocks = MarkdownParser.parseBlocks(input)

        guard case .codeBlock(let code, let lang) = blocks[0] else {
            XCTFail("Expected code block")
            return
        }
        XCTAssertEqual(lang, "swift")
        XCTAssertEqual(code, "let x = 1")
    }
}
```

---

### 4.2 Add Accessibility

**Checklist**:

- [ ] Add `accessibilityLabel` to all buttons without text
- [ ] Add `accessibilityHint` for non-obvious actions
- [ ] Test with VoiceOver enabled
- [ ] Ensure Dynamic Type scales properly
- [ ] Add `accessibilityIdentifier` for UI testing

**Priority areas**:
1. Chat input buttons (mic, photo, send)
2. Tool use collapse/expand
3. Status indicators
4. Session picker

**Example**:
```swift
// Current:
Button { ... } label: {
    Image(systemName: "mic.fill")
}

// With accessibility:
Button { ... } label: {
    Image(systemName: "mic.fill")
}
.accessibilityLabel("Voice input")
.accessibilityHint("Tap to start voice recording")
```

---

## Implementation Sequence

| Order | Task | Effort | Dependencies |
|-------|------|--------|--------------|
| 1 | Fix AppSettings injection | 2h | None |
| 2 | Create Utilities/ImageUtilities.swift | 30m | None |
| 3 | Migrate Theme.swift to all dynamic | 2h | None |
| 4 | Extract String+Markdown.swift | 30m | None |
| 5 | Extract MessageViews/*.swift | 2h | #4 |
| 6 | Extract MarkdownParser/*.swift | 1h | #4 |
| 7 | Extract SessionViews/*.swift | 1h | None |
| 8 | Extract InputViews/*.swift | 1h | None |
| 9 | Fix MessageStore (file-based) | 3h | None |
| 10 | Add error handling utilities | 2h | None |
| 11 | Add WebSocket retry logic | 2h | #10 |
| 12 | Set up test target | 1h | #5, #6 |
| 13 | Write parser tests | 2h | #12 |
| 14 | Add accessibility labels | 2h | #5, #8 |

**Total estimated effort**: ~20 hours

---

## Success Criteria

- [ ] No file over 400 lines (except complex views with clear sections)
- [ ] All views use colorScheme-aware theme colors
- [ ] AppSettings flows correctly through EnvironmentObject
- [ ] Messages with images persist without crashing
- [ ] Failed sends retry automatically with user feedback
- [ ] 80%+ test coverage on parsers
- [ ] App usable with VoiceOver

---

## Notes

### SSHKeyDetection Missing

Found reference to `SSHKeyDetection.detectPrivateKeyType` in SSHManager.swift:186 but no definition. This may be:
1. A missing file that needs to be created
2. Coming from Citadel package (check package API)
3. A compile error waiting to happen

**Action**: Verify build succeeds, add missing type if needed.

### Technical Debt Tracking

After hardening, update ROADMAP.md Technical Debt section:
- [x] ChatView.swift size - Split into modules
- [x] Theme migration - Completed
- [x] Test coverage - Added
- [x] Accessibility - Added

---

*Created: December 2024*
