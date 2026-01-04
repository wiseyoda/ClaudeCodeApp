# Examples


### stream envelope (assistant delta)
```json
{
  "type": "stream",
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2026-01-03T12:00:00Z",
  "message": {
    "type": "assistant",
    "content": "Hello",
    "delta": true
  }
}
```

### tool_use
```json
{
  "type": "tool_use",
  "id": "tool-use-123",
  "name": "Bash",
  "input": { "command": "ls -la" },
  "inputDescription": "Run command: ls -la"
}
```

### tool_result
```json
{
  "type": "tool_result",
  "id": "tool-use-123",
  "tool": "Bash",
  "output": "total 48\n-rw-r--r-- ...",
  "success": true,
  "isError": false
}
```

### progress
```json
{
  "type": "progress",
  "id": "tool-use-123",
  "tool": "Bash",
  "elapsed": 12.3,
  "progress": 45.0,
  "detail": "Installing dependencies..."
}
```

### permission
```json
{
  "type": "permission",
  "id": "perm-456",
  "tool": "Read",
  "input": { "file_path": "/path/to/file" },
  "options": ["allow", "deny", "always"]
}
```

### question
```json
{
  "type": "question",
  "id": "question-789",
  "questions": [
    {
      "question": "Which approach should we use?",
      "header": "Implementation choice",
      "multiSelect": false,
      "options": [
        { "label": "Option A", "description": "Fast but limited" },
        { "label": "Option B", "description": "Comprehensive" }
      ]
    }
  ]
}
```

### usage
```json
{
  "type": "usage",
  "inputTokens": 1234,
  "outputTokens": 5678,
  "cacheReadTokens": 100,
  "cacheCreateTokens": 50,
  "totalCost": 0.12,
  "contextUsed": 6912,
  "contextLimit": 200000
}
```

### state
```json
{
  "type": "state",
  "state": "executing",
  "tool": "Bash"
}
```

### connected
```json
{
  "type": "connected",
  "agentId": "agent_abc123",
  "sessionId": "550e8400-e29b-41d4-a716-446655440000",
  "model": "claude-sonnet-4-20250514",
  "modelAlias": "sonnet",
  "version": "0.4.12",
  "protocolVersion": "1.0"
}
```

### history
```json
{
  "type": "history",
  "messages": [{ "type": "assistant", "content": "Welcome", "delta": false }],
  "hasMore": false,
  "cursor": null
}
```

### queued
```json
{
  "type": "queued",
  "position": 2
}
```

### queue_cleared
```json
{
  "type": "queue_cleared"
}
```

### session_event
```json
{
  "type": "session_event",
  "action": "updated",
  "projectPath": "/Users/dev/my-project",
  "sessionId": "550e8400-e29b-41d4-a716-446655440000",
  "metadata": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "projectPath": "/Users/dev/my-project",
    "source": "user",
    "createdAt": "2026-01-03T10:00:00Z",
    "lastActivityAt": "2026-01-03T12:00:00Z",
    "messageCount": 42,
    "title": "Implement user auth",
    "summary": "Working on OAuth integration with JWT tokens",
    "customTitle": null,
    "model": "sonnet",
    "archivedAt": null,
    "parentSessionId": null
  }
}
```

### model_changed
```json
{
  "type": "model_changed",
  "model": "claude-opus-4-20250514",
  "previousModel": "claude-sonnet-4-20250514"
}
```

### permission_mode_changed
```json
{
  "type": "permission_mode_changed",
  "mode": "acceptEdits"
}
```

### stopped
```json
{
  "type": "stopped",
  "reason": "complete"
}
```

### interrupted
```json
{
  "type": "interrupted"
}
```

### error (non-recoverable)
```json
{
  "type": "error",
  "code": "AGENT_NOT_FOUND",
  "message": "No agent found with ID agent_abc123",
  "recoverable": false
}
```

### error (retryable)
```json
{
  "type": "error",
  "code": "QUEUE_FULL",
  "message": "Input queue is full. Wait or cancel queued input.",
  "recoverable": true,
  "retryable": true
}
```

### error (rate limited)
```json
{
  "type": "error",
  "code": "RATE_LIMITED",
  "message": "Too many requests",
  "recoverable": true,
  "retryAfter": 60
}
```

### reconnect_complete
```json
{
  "type": "reconnect_complete",
  "missedCount": 5,
  "fromMessageId": "550e8400-e29b-41d4-a716-446655440000"
}
```

### cursor_evicted
```json
{
  "type": "cursor_evicted",
  "lastMessageId": "550e8400-e29b-41d4-a716-446655440000",
  "recommendation": "fetch_from_rest"
}
```

### cursor_invalid
```json
{
  "type": "cursor_invalid",
  "lastMessageId": "550e8400-e29b-41d4-a716-446655440000",
  "recommendation": "full_resync"
}
```

### ping (server-initiated)
```json
{
  "type": "ping",
  "serverTime": 1704288000000
}
```

### pong
```json
{
  "type": "pong",
  "serverTime": 1704288000000
}
```

### subagent_start
```json
{
  "type": "subagent_start",
  "id": "subagent-123",
  "description": "Searching codebase for authentication patterns"
}
```

### subagent_complete
```json
{
  "type": "subagent_complete",
  "id": "subagent-123",
  "summary": "Found 3 auth-related files in src/auth/"
}
```

### thinking
```json
{
  "type": "thinking",
  "content": "Let me analyze this problem step by step...",
  "thinking": "Let me analyze this problem step by step..."
}
```

### system
```json
{
  "type": "system",
  "content": "Session initialized",
  "subtype": "init"
}
```

### user
```json
{
  "type": "user",
  "content": "Can you help me implement user authentication?"
}
```
