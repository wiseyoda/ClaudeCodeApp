# StreamMessage Types (message.type)


| message.type | Model | Key fields |
|---|---|---|
| `assistant` | `AssistantStreamMessage` | `content`, `delta?` |
| `user` | `UserStreamMessage` | `content` |
| `system` | `SystemStreamMessage` | `content`, `subtype?` (`init`, `result`, `progress`) |
| `thinking` | `ThinkingStreamMessage` | `content`, `thinking?` (alias) |
| `tool_use` | `ToolUseStreamMessage` | `id`, `name`, `input`, `inputDescription?`, `result?` |
| `tool_result` | `ToolResultStreamMessage` | `id`, `tool`, `output`, `success`, `isError?` |
| `progress` | `ProgressStreamMessage` | `id`, `tool`, `elapsed`, `progress?` (0-100), `detail?` |
| `usage` | `UsageStreamMessage` | `inputTokens`, `outputTokens`, `cacheReadTokens?`, `cacheCreateTokens?`, `totalCost?`, `contextUsed?`, `contextLimit?` |
| `state` | `StateStreamMessage` | `state`, `tool?` |
| `permission` | `PermissionRequestMessage` | `id`, `tool`, `input`, `options` |
| `question` | `QuestionMessage` | `id`, `questions` |
| `subagent_start` | `SubagentStartStreamMessage` | `id`, `description` |
| `subagent_complete` | `SubagentCompleteStreamMessage` | `id`, `summary?` |

### State Values

The `state` field in `StateStreamMessage` can be one of:
- `thinking` - Claude is generating a response
- `executing` - A tool is being executed
- `waiting_input` - Waiting for user input
- `waiting_permission` - Waiting for permission approval
- `idle` - No active processing
- `recovering` - Recovering from an error or reconnection
