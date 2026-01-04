# DocC Standards

## When to Document

- Public or shared APIs used across features.
- New protocols, actors, or managers.
- Models exposed to views or repositories.
- Anything that enforces a pattern (normalizers, validators, state containers).

## Comment Format

- Use triple-slash DocC comments for types, properties, and methods.
- Summary line is a complete sentence, verb-first.
- Prefer concise summaries and short sections.

```swift
/// Normalizes backend payloads into validated UI messages.
///
/// Use this type for both history and streaming data paths.
final class MessageNormalizer {
    /// Normalizes a paginated history message.
    /// - Parameter paginated: Raw backend message payload.
    /// - Returns: A validated message with warnings, if any.
    func normalize(_ paginated: PaginatedMessage) -> ValidatedMessage { /* ... */ }
}
```

## Sections

- Use "##" headings for major sections and "###" for subsections.
- Use DocC directives sparingly: `- Note:`, `- Warning:`, `- Important:`.

```swift
/// Tracks tool progress state for status banners.
///
/// - Important: This actor is the single source of truth for card status.
actor CardStatusTracker {
    // ...
}
```

## Parameters, Returns, Throws

- Document all parameters and return values for public methods.
- Use `- Throws:` for error cases.

```swift
/// Loads sessions for a project.
/// - Parameter projectId: The project identifier.
/// - Returns: The loaded sessions.
/// - Throws: ``AppError`` when loading fails.
func loadSessions(projectId: String) async throws -> [ProjectSession] { /* ... */ }
```

## Protocols

- Document responsibilities and constraints.
- Include a short usage example when non-trivial.

```swift
/// Provides status updates for tool execution.
///
/// Conforming actors must be thread-safe and Sendable.
protocol StatusTracking: Actor { /* ... */ }
```

## Examples

- Use fenced code blocks with `swift` info string.
- Keep examples minimal and correct.

## Doc Hygiene

- Keep DocC comments in ASCII.
- Update documentation when signatures change.
- Avoid duplicating the issue spec; focus on API behavior and usage.
