# Naming Conventions

## Types

| Type | Convention | Example |
| --- | --- | --- |
| Classes | UpperCamelCase | `ChatViewModel` |
| Structs | UpperCamelCase | `ChatMessage` |
| Enums | UpperCamelCase | `AppError` |
| Protocols | UpperCamelCase + -able/-ible/-ing | `UserFacingError` |
| Typealiases | UpperCamelCase | `MessageHandler` |

## Properties and Methods

| Type | Convention | Example |
| --- | --- | --- |
| Properties | lowerCamelCase | `isLoading` |
| Methods | lowerCamelCase, verb-first | `loadSessions()` |
| Boolean properties | is/has/can/should prefix | `hasTokens` |
| Factories | make/create prefix | `makeViewModel()` |
| Async methods | verb-first | `fetchProjects()` |

## Enums and Cases

| Type | Convention | Example |
| --- | --- | --- |
| Enum cases | lowerCamelCase | `.networkUnavailable` |
| OptionSet | UpperCamelCase | `MessageCardCapability` |

## Files and Folders

| Item | Convention | Example |
| --- | --- | --- |
| File names | UpperCamelCase | `ChatViewModel.swift` |
| Extensions | Type+Feature.swift | `ChatViewModel+StreamEvents.swift` |
| Protocols | ProtocolName.swift | `UserFacingError.swift` |
| Constants | Feature+Constants.swift | `Design+Constants.swift` |
| Folders | UpperCamelCase | `Utilities`, `Managers` |

## Tests

- Test files: `*Tests.swift`.
- Test methods: `test` prefix with expected behavior.

Examples:
- `ChatViewModelTests.swift`
- `testLoadSessionsCachesResults()`

## UI Labels and Strings

- Localized keys: `feature.section.key` (lowercase dot notation).
- Avoid hardcoded user-visible strings in views.
