# Backend Events

> Session handler triggers for push notifications.

## Event Triggers

Modify existing session handlers to trigger push:

### Approval Request

```javascript
// services/session-handler.js

async handleApprovalRequest(sessionId, userId, request) {
  // Store approval request
  await this.storeApprovalRequest(sessionId, request);

  // Get device tokens
  const tokens = await db.all(
    'SELECT token FROM push_tokens WHERE user_id = ? AND token_type = ? AND is_valid = TRUE',
    [userId, 'device']
  );

  // Send device notifications
  for (const { token } of tokens) {
    await apns.sendNotification(token, {
      title: 'Approval Needed',
      subtitle: request.toolName,
      body: request.summary,
      category: 'APPROVAL_REQUEST',
      data: { requestId: request.id, type: 'approval' },
    });
  }

  // Update Live Activity
  const liveActivityTokens = await db.all(
    'SELECT token FROM push_tokens WHERE user_id = ? AND token_type = ? AND session_id = ? AND is_valid = TRUE',
    [userId, 'live_activity', sessionId]
  );

  for (const { token } of liveActivityTokens) {
    await apns.sendLiveActivityUpdate(token, {
      status: 'awaitingApproval',
      approvalRequest: {
        requestId: request.id,
        toolName: request.toolName,
        summary: request.summary,
      },
    });
  }
}
```

### Question Asked

```javascript
async handleQuestionAsked(sessionId, userId, question) {
  const tokens = await db.all(
    'SELECT token FROM push_tokens WHERE user_id = ? AND token_type = ? AND is_valid = TRUE',
    [userId, 'device']
  );

  for (const { token } of tokens) {
    await apns.sendNotification(token, {
      title: 'Claude has a question',
      body: question.text.substring(0, 200),
      category: 'QUESTION_ASKED',
      data: { questionId: question.id, sessionId, type: 'question' },
    });
  }

  await this.updateLiveActivity(sessionId, userId, {
    status: 'awaitingAnswer',
    currentOperation: 'Waiting for your response',
  });
}
```

### Task Complete

```javascript
async handleTaskComplete(sessionId, userId, result) {
  const isSuccess = result.status === 'success';

  // Send device notification
  const tokens = await db.all(
    'SELECT token FROM push_tokens WHERE user_id = ? AND token_type = ? AND is_valid = TRUE',
    [userId, 'device']
  );

  for (const { token } of tokens) {
    await apns.sendNotification(token, {
      title: isSuccess ? 'Task Complete' : 'Task Failed',
      body: result.summary || (isSuccess ? 'Claude finished' : 'Error occurred'),
      category: isSuccess ? 'TASK_COMPLETE' : 'TASK_ERROR',
      data: { sessionId, type: isSuccess ? 'complete' : 'error' },
    });
  }

  // End Live Activity
  const liveActivityTokens = await db.all(
    'SELECT token FROM push_tokens WHERE user_id = ? AND token_type = ? AND session_id = ? AND is_valid = TRUE',
    [userId, 'live_activity', sessionId]
  );

  for (const { token } of liveActivityTokens) {
    await apns.sendLiveActivityUpdate(token, {
      status: isSuccess ? 'completed' : 'error',
      currentOperation: result.summary,
    }, 'end');
  }

  // Cleanup Live Activity tokens
  await db.run(
    'DELETE FROM push_tokens WHERE session_id = ? AND token_type = ?',
    [sessionId, 'live_activity']
  );
}
```

### Progress Update

```javascript
async handleProgressUpdate(sessionId, userId, progress) {
  const liveActivityTokens = await db.all(
    'SELECT token FROM push_tokens WHERE user_id = ? AND token_type = ? AND session_id = ? AND is_valid = TRUE',
    [userId, 'live_activity', sessionId]
  );

  for (const { token } of liveActivityTokens) {
    await throttledUpdate(token, {
      status: 'processing',
      currentOperation: progress.currentOperation,
      elapsedSeconds: progress.elapsedSeconds,
      todoProgress: progress.todoProgress,
    });
  }
}
```

## Approval Timeout

60-second timeout for approval requests:

```javascript
class ApprovalManager {
  constructor() {
    this.pendingApprovals = new Map();
    this.timeoutDuration = 60000;
  }

  async createApprovalRequest(sessionId, userId, request) {
    const requestId = `approval-${Date.now()}`;

    const timeout = setTimeout(
      () => this.handleTimeout(requestId),
      this.timeoutDuration
    );

    this.pendingApprovals.set(requestId, {
      sessionId, userId, request, timeout,
      expiresAt: Date.now() + this.timeoutDuration
    });

    await this.sendApprovalNotification(userId, {
      ...request,
      requestId,
      expiresAt: new Date(Date.now() + this.timeoutDuration).toISOString()
    });

    return requestId;
  }

  async handleTimeout(requestId) {
    const pending = this.pendingApprovals.get(requestId);
    if (!pending) return;

    this.pendingApprovals.delete(requestId);

    // Send silent push to clear notification
    await this.sendClearNotification(pending.userId, requestId);

    // Notify Claude session
    await this.sendToSession(pending.sessionId, {
      type: 'approval_timeout',
      requestId,
      message: 'User did not respond within 60 seconds'
    });
  }

  async handleResponse(requestId, approved) {
    const pending = this.pendingApprovals.get(requestId);
    if (!pending) {
      return { success: false, error: 'Expired or not found' };
    }

    clearTimeout(pending.timeout);
    this.pendingApprovals.delete(requestId);

    await this.sendToSession(pending.sessionId, {
      type: 'approval_response',
      requestId,
      approved
    });

    return { success: true };
  }
}
```

## WebSocket Events

Add new events for iOS client:

```javascript
// Progress update
{
  type: 'progress_update',
  sessionId: 'session-123',
  data: {
    currentOperation: 'Running tests...',
    elapsedSeconds: 45,
    todoProgress: { completed: 2, total: 5 }
  }
}

// Approval timeout
{
  type: 'approval_timeout',
  sessionId: 'session-123',
  requestId: 'approval-456'
}
```

---
**Prev:** [backend-api](./backend-api.md) | **Next:** [checklist](./checklist.md) | **Index:** [../00-INDEX.md](../00-INDEX.md)
