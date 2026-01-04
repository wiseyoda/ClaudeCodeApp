# Mapping Notes


### Wire → UI Mapping

| Wire Payload | StreamEvent Case | UI Model |
|---|---|---|
| `AssistantStreamMessage` | `.text(content, isFinal)` | `ChatMessage(.assistant)` |
| `ThinkingStreamMessage` | `.thinking(content)` | `ChatMessage(.thinking)` |
| `ToolUseStreamMessage` | `.toolStart(...)` | `ChatMessage(.toolUse)` |
| `ToolResultStreamMessage` | `.toolResult(...)` | `ChatMessage(.toolResult)` |
| `SystemStreamMessage` | `.system(content, subtype)` | `ChatMessage(.system)` |
| `UserStreamMessage` | `.user(content)` | `ChatMessage(.user)` |
| `PermissionRequestMessage` | `.permissionRequest(...)` | `ApprovalRequest` |
| `QuestionMessage` | `.questionRequest(...)` | `AskUserQuestionData` |
| `StateStreamMessage` | `.stateChanged(...)` | Updates connection state |
| `WsErrorMessage` | `.error(...)` | Error handling |

### Normalization Pipeline

1. **Wire payload** arrives via WebSocket
2. **StreamEvent** enum provides type-safe Swift representation
3. **ValidatedMessage** normalizes for UI consumption
4. **ChatMessage** renders in the conversation view

### Cross-References

- `../api/README.md` - Canonical wire format and field definitions
- `../../architecture/data/README.md` - System design and data flow
- `CodingBridge/Generated/*.swift` - OpenAPI-generated Swift types
