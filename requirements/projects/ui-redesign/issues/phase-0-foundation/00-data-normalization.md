# Issue 00: Data Normalization Layer

**Phase:** 0 (Foundation)
**Priority:** Critical
**Status:** Not Started

## Goal
Define and implement Data Normalization Layer as described in this spec.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- See **Depends On** header; add runtime or tooling dependencies here.

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
## Problem

Two separate data paths with different handling:

1. **History Path**: `PaginatedMessage.toChatMessage()` in CLIBridgeExtensions.swift
2. **Stream Path**: `StreamEvent` cases in ChatViewModel+StreamEvents.swift

Current issues:
- Silent failures (invalid roles → `.system`, bad JSON → `"{}"`, bad timestamps → `Date()`)
- Different JSON serialization approaches
- Local command parsing only in history path
- No unified validation layer

## Solution

Create a normalization layer that both paths flow through before data reaches card views.

## Model Definitions

Canonical schemas live in [docs/contracts/models](../../docs/contracts/models/README.md). Use those
definitions for any normalization or parsing work.

## Files to Create

```
CodingBridge/Normalization/
├── MessageNormalizer.swift      # Central validation + conversion
├── ValidatedMessage.swift       # Guaranteed-valid message type
├── RoleValidator.swift          # Role string → enum with logging
├── ContentSanitizer.swift       # Clean AnyCodable, validate JSON
└── TimestampParser.swift        # Unified ISO8601 parsing with logging
```

## Implementation Steps

### 1. ValidatedMessage.swift

```swift
/// Normalized message with explicit, validated fields (see docs/contracts/models)
struct ValidatedMessage {
    let id: String
    let role: ChatMessage.Role
    let content: String
    let timestamp: Date
    let isStreaming: Bool
    let toolName: String?
    let toolUseId: String?
    let toolResultId: String?
    let toolInputDescription: String?
    let toolOutput: String?
    let tokenCount: Int?
    let executionTime: TimeInterval?
    let imagePath: String?
    let imageData: Data?
    let warnings: [MessageValidationError]
}
```

### 2. RoleValidator.swift

```swift
struct RoleValidator {
    static func validate(_ rawValue: String) -> (role: ChatMessage.Role, wasValid: Bool) {
        if let role = ChatMessage.Role(rawValue: rawValue) {
            return (role, true)
        }
        Logger.warning("Invalid role '\(rawValue)', using .system")
        return (.system, false)
    }
}
```

### 3. TimestampParser.swift

```swift
struct TimestampParser {
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func parse(_ string: String) -> (date: Date, wasValid: Bool) {
        if let date = formatter.date(from: string) {
            return (date, true)
        }
        Logger.warning("Invalid timestamp '\(string)', using now")
        return (Date(), false)
    }
}
```

### 4. ContentSanitizer.swift

```swift
struct ContentSanitizer {
    /// Remove AnyCodableValue wrappers from JSON strings
    static func sanitize(_ content: String) -> String {
        // Implementation to strip "AnyCodableValue(...)" wrappers
    }

    /// Validate JSON in tool inputs
    static func validateJSON(_ json: String) -> (isValid: Bool, error: String?) {
        // Implementation
    }
}
```

### 5. MessageNormalizer.swift

```swift
@MainActor
final class MessageNormalizer {
    static let shared = MessageNormalizer()

    func normalize(_ paginated: PaginatedMessage) -> ValidatedMessage {
        var warnings: [MessageValidationError] = []

        // Validate role
        let (role, roleValid) = RoleValidator.validate(paginated.role)
        if !roleValid {
            warnings.append(.invalidRole(paginated.role))
        }

        // Validate timestamp
        let (timestamp, timestampValid) = TimestampParser.parse(paginated.timestamp)
        if !timestampValid {
            warnings.append(.invalidTimestamp(paginated.timestamp))
        }

        // Sanitize content
        let content = ContentSanitizer.sanitize(paginated.content)

        let message = ChatMessage(
            role: role,
            content: content,
            timestamp: timestamp,
            // ... other fields
        )

        return ValidatedMessage(message: message, warnings: warnings)
    }

    func normalize(_ streamEvent: StreamEvent) -> ValidatedMessage? {
        // Convert StreamEvent to ValidatedMessage
        // Return nil for events that don't produce messages
    }
}
```

## Files to Modify

| File | Changes |
|------|---------|
| `CLIBridgeExtensions.swift` | Update `PaginatedMessage.toChatMessage()` to use `MessageNormalizer.shared.normalize()` |
| `ChatViewModel+StreamEvents.swift` | Update stream event handling to use normalizer |
| `MessageStore.swift` | Update `ChatMessageDTO` conversion to use normalizer |
| `SessionStore.swift` | Ensure message loading uses normalizer |

## Acceptance Criteria

- [ ] All messages flow through MessageNormalizer
- [ ] Invalid roles are logged, not silently converted
- [ ] Invalid timestamps are logged, not silently converted
- [ ] AnyCodable wrappers are stripped from content
- [ ] Unit tests for each validator
- [ ] ValidatedMessage schema matches docs/contracts/models
- [ ] No behavior changes in UI (same visual output)

## Testing

```swift
class MessageNormalizerTests: XCTestCase {
    func testValidRole() {
        let (role, valid) = RoleValidator.validate("assistant")
        XCTAssertEqual(role, .assistant)
        XCTAssertTrue(valid)
    }

    func testInvalidRole() {
        let (role, valid) = RoleValidator.validate("bogus")
        XCTAssertEqual(role, .system)
        XCTAssertFalse(valid)
    }

    func testValidTimestamp() {
        let (date, valid) = TimestampParser.parse("2025-01-03T10:30:00.000Z")
        XCTAssertTrue(valid)
        // Assert date components
    }

    func testInvalidTimestamp() {
        let (_, valid) = TimestampParser.parse("not-a-date")
        XCTAssertFalse(valid)
    }
}
```
