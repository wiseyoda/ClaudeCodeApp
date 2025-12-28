# Backend Changes for APNs Integration

> Required modifications to claudecodeui backend for push notification support.

## Overview

The claudecodeui backend needs to be enhanced to:
1. Accept and store push tokens from iOS clients
2. Send push notifications via APNs for task events
3. Send Live Activity updates via APNs push tokens
4. Handle token invalidation and updates

## APNs Configuration

### Prerequisites

1. **Apple Developer Account** with push notification capability
2. **APNs Authentication Key (p8)** - required for Live Activity updates
3. **Bundle ID** registered with push notification entitlement
4. **Team ID** from Apple Developer account

### APNs Key Setup

1. Go to Apple Developer Portal → Certificates, Identifiers & Profiles
2. Create a new Key with Apple Push Notifications service (APNs)
3. Download the `.p8` file (only available once!)
4. Note the Key ID

### Environment Variables

```bash
# APNs Configuration
APNS_KEY_ID=ABC123DEFG
APNS_TEAM_ID=TEAM123456
APNS_KEY_PATH=/path/to/AuthKey_ABC123DEFG.p8
APNS_BUNDLE_ID=com.codingbridge.CodingBridge
APNS_ENVIRONMENT=development  # or "production"
```

## New API Endpoints

### 1. Register Device Push Token

```
POST /api/push/register
Authorization: Bearer <jwt-token>

Request:
{
  "deviceToken": "abc123...",
  "platform": "ios",
  "environment": "development"  // or "production"
}

Response:
{
  "success": true,
  "tokenId": "tok_123"
}
```

### 2. Register Live Activity Push Token

```
POST /api/push/live-activity/register
Authorization: Bearer <jwt-token>

Request:
{
  "activityToken": "def456...",
  "activityId": "activity-123",
  "sessionId": "session-456",
  "previousToken": "old-token...",  // optional, for invalidation
  "platform": "ios"
}

Response:
{
  "success": true
}
```

### 3. Invalidate Token

```
DELETE /api/push/token/:tokenId
Authorization: Bearer <jwt-token>

Response:
{
  "success": true
}
```

### 4. Get Push Status (Debug)

```
GET /api/push/status
Authorization: Bearer <jwt-token>

Response:
{
  "deviceTokenRegistered": true,
  "liveActivityTokens": [
    {
      "activityId": "activity-123",
      "sessionId": "session-456",
      "registeredAt": "2025-01-15T10:30:00Z"
    }
  ]
}
```

### 5. Clear Approval on Other Devices

When user responds to an approval on one device, clear the notification on all other devices.

```
POST /api/push/clear-approval
Authorization: Bearer <jwt-token>

Request:
{
  "requestId": "approval-123",
  "excludeDeviceToken": "abc123..."  // Don't send to device that handled the approval
}

Response:
{
  "success": true,
  "devicesNotified": 2
}
```

### 6. Cancel All Session Notifications

Clear all pending notifications for a session (e.g., when session ends or user cancels).

```
DELETE /api/push/session/:sessionId/notifications
Authorization: Bearer <jwt-token>

Response:
{
  "success": true,
  "clearedCount": 3
}
```

## Database Schema

### Push Tokens Table

```sql
CREATE TABLE push_tokens (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    token TEXT NOT NULL UNIQUE,
    token_type TEXT NOT NULL,  -- 'device' or 'live_activity'
    activity_id TEXT,          -- for live_activity tokens
    session_id TEXT,           -- for live_activity tokens
    platform TEXT NOT NULL DEFAULT 'ios',
    environment TEXT NOT NULL DEFAULT 'development',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP,
    is_valid BOOLEAN DEFAULT TRUE,

    FOREIGN KEY (user_id) REFERENCES users(id),
    INDEX idx_user_id (user_id),
    INDEX idx_token_type (token_type),
    INDEX idx_session_id (session_id)
);
```

## APNs Integration Module

### Node.js Implementation (using `apn` or `@parse/node-apn`)

```javascript
// services/apns.js

const apn = require('@parse/node-apn');
const fs = require('fs');
const path = require('path');

class APNSService {
  constructor() {
    const keyPath = process.env.APNS_KEY_PATH;
    const keyId = process.env.APNS_KEY_ID;
    const teamId = process.env.APNS_TEAM_ID;
    const bundleId = process.env.APNS_BUNDLE_ID;
    const production = process.env.APNS_ENVIRONMENT === 'production';

    this.provider = new apn.Provider({
      token: {
        key: fs.readFileSync(keyPath),
        keyId: keyId,
        teamId: teamId,
      },
      production: production,
    });

    this.bundleId = bundleId;
  }

  // Send standard push notification
  async sendNotification(deviceToken, payload) {
    const notification = new apn.Notification();

    notification.topic = this.bundleId;
    notification.expiry = Math.floor(Date.now() / 1000) + 3600; // 1 hour
    notification.badge = payload.badge;
    notification.sound = payload.sound || 'default';
    notification.alert = {
      title: payload.title,
      subtitle: payload.subtitle,
      body: payload.body,
    };
    notification.category = payload.category;
    notification.payload = payload.data || {};

    try {
      const result = await this.provider.send(notification, deviceToken);
      if (result.failed.length > 0) {
        console.error('APNs send failed:', result.failed);
        return { success: false, error: result.failed[0].response };
      }
      return { success: true };
    } catch (error) {
      console.error('APNs error:', error);
      return { success: false, error: error.message };
    }
  }

  // Send Live Activity update
  async sendLiveActivityUpdate(activityToken, contentState, event = 'update') {
    const notification = new apn.Notification();

    // Live Activity specific settings
    notification.topic = `${this.bundleId}.push-type.liveactivity`;
    notification.pushType = 'liveactivity';
    notification.expiry = Math.floor(Date.now() / 1000) + 300; // 5 minutes

    // Live Activity payload format
    notification.aps = {
      timestamp: Math.floor(Date.now() / 1000),
      event: event,  // 'update' or 'end'
      'content-state': contentState,
      'stale-date': Math.floor(Date.now() / 1000) + 300,
    };

    if (event === 'end') {
      notification.aps['dismissal-date'] = Math.floor(Date.now() / 1000) + 900; // 15 min
    }

    try {
      const result = await this.provider.send(notification, activityToken);
      if (result.failed.length > 0) {
        console.error('Live Activity update failed:', result.failed);
        // Handle token invalidation
        if (result.failed[0].response?.reason === 'BadDeviceToken') {
          await this.handleInvalidToken(activityToken);
        }
        return { success: false, error: result.failed[0].response };
      }
      return { success: true };
    } catch (error) {
      console.error('Live Activity error:', error);
      return { success: false, error: error.message };
    }
  }

  async handleInvalidToken(token) {
    // Mark token as invalid in database
    await db.run(
      'UPDATE push_tokens SET is_valid = FALSE WHERE token = ?',
      [token]
    );
  }

  shutdown() {
    this.provider.shutdown();
  }
}

module.exports = new APNSService();
```

### Push Notification Triggers

Modify existing WebSocket handlers to trigger push notifications:

```javascript
// services/session-handler.js

const apns = require('./apns');
const db = require('./database');

class SessionHandler {
  // ... existing code ...

  async handleApprovalRequest(sessionId, userId, request) {
    // Store approval request
    await this.storeApprovalRequest(sessionId, request);

    // Get user's device tokens
    const tokens = await db.all(
      'SELECT token FROM push_tokens WHERE user_id = ? AND token_type = ? AND is_valid = TRUE',
      [userId, 'device']
    );

    // Get Live Activity tokens for this session
    const liveActivityTokens = await db.all(
      'SELECT token FROM push_tokens WHERE user_id = ? AND token_type = ? AND session_id = ? AND is_valid = TRUE',
      [userId, 'live_activity', sessionId]
    );

    // Send device notification
    for (const { token } of tokens) {
      await apns.sendNotification(token, {
        title: 'Approval Needed',
        subtitle: request.toolName,
        body: request.summary,
        category: 'APPROVAL_REQUEST',
        data: {
          requestId: request.id,
          toolName: request.toolName,
          type: 'approval',
        },
      });
    }

    // Update Live Activity
    for (const { token } of liveActivityTokens) {
      await apns.sendLiveActivityUpdate(token, {
        status: 'awaitingApproval',
        currentOperation: null,
        elapsedSeconds: this.getElapsedSeconds(sessionId),
        approvalRequest: {
          requestId: request.id,
          toolName: request.toolName,
          summary: request.summary,
        },
      });
    }
  }

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
        data: {
          questionId: question.id,
          sessionId: sessionId,
          type: 'question',
        },
      });
    }

    // Update Live Activity
    await this.updateLiveActivity(sessionId, userId, {
      status: 'awaitingAnswer',
      currentOperation: 'Waiting for your response',
    });
  }

  async handleTaskComplete(sessionId, userId, result) {
    const tokens = await db.all(
      'SELECT token FROM push_tokens WHERE user_id = ? AND token_type = ? AND is_valid = TRUE',
      [userId, 'device']
    );

    const isSuccess = result.status === 'success';

    for (const { token } of tokens) {
      await apns.sendNotification(token, {
        title: isSuccess ? 'Task Complete' : 'Task Failed',
        body: result.summary || (isSuccess ? 'Claude finished working' : 'An error occurred'),
        category: isSuccess ? 'TASK_COMPLETE' : 'TASK_ERROR',
        data: {
          sessionId: sessionId,
          type: isSuccess ? 'complete' : 'error',
        },
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
        elapsedSeconds: 0,
      }, 'end');
    }

    // Clean up Live Activity tokens for this session
    await db.run(
      'DELETE FROM push_tokens WHERE session_id = ? AND token_type = ?',
      [sessionId, 'live_activity']
    );
  }

  async updateLiveActivity(sessionId, userId, state) {
    const tokens = await db.all(
      'SELECT token FROM push_tokens WHERE user_id = ? AND token_type = ? AND session_id = ? AND is_valid = TRUE',
      [userId, 'live_activity', sessionId]
    );

    for (const { token } of tokens) {
      await apns.sendLiveActivityUpdate(token, {
        status: state.status || 'processing',
        currentOperation: state.currentOperation,
        elapsedSeconds: state.elapsedSeconds || this.getElapsedSeconds(sessionId),
        todoProgress: state.todoProgress,
        approvalRequest: state.approvalRequest,
      });
    }
  }

  getElapsedSeconds(sessionId) {
    const session = this.sessions.get(sessionId);
    if (!session?.startTime) return 0;
    return Math.floor((Date.now() - session.startTime) / 1000);
  }
}
```

## WebSocket Event Additions

Add new WebSocket events for progress updates:

```javascript
// Existing events that trigger push:
// - approval_request
// - question_asked
// - claude-complete

// New events for Live Activity updates:

// Progress update (sent periodically during processing)
{
  type: 'progress_update',
  sessionId: 'session-123',
  data: {
    currentOperation: 'Running tests...',
    elapsedSeconds: 45,
    todoProgress: {
      completed: 2,
      total: 5,
      currentTask: 'Add unit tests'
    }
  }
}

// State change (processing, idle, etc.)
{
  type: 'state_change',
  sessionId: 'session-123',
  data: {
    previousState: 'idle',
    newState: 'processing'
  }
}
```

## API Routes

```javascript
// routes/push.js

const express = require('express');
const router = express.Router();
const db = require('../services/database');
const { authenticateToken } = require('../middleware/auth');

// Register device token
router.post('/register', authenticateToken, async (req, res) => {
  const { deviceToken, platform, environment } = req.body;
  const userId = req.user.id;

  try {
    const tokenId = `tok_${Date.now()}`;

    // Upsert token (update if exists, insert if new)
    await db.run(`
      INSERT INTO push_tokens (id, user_id, token, token_type, platform, environment)
      VALUES (?, ?, ?, 'device', ?, ?)
      ON CONFLICT(token) DO UPDATE SET
        user_id = excluded.user_id,
        updated_at = CURRENT_TIMESTAMP,
        is_valid = TRUE
    `, [tokenId, userId, deviceToken, platform, environment]);

    res.json({ success: true, tokenId });
  } catch (error) {
    console.error('Token registration error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Register Live Activity token
router.post('/live-activity/register', authenticateToken, async (req, res) => {
  const { activityToken, activityId, sessionId, previousToken } = req.body;
  const userId = req.user.id;

  try {
    // Invalidate previous token if provided
    if (previousToken) {
      await db.run(
        'UPDATE push_tokens SET is_valid = FALSE WHERE token = ?',
        [previousToken]
      );
    }

    const tokenId = `lat_${Date.now()}`;

    await db.run(`
      INSERT INTO push_tokens (id, user_id, token, token_type, activity_id, session_id, platform)
      VALUES (?, ?, ?, 'live_activity', ?, ?, 'ios')
      ON CONFLICT(token) DO UPDATE SET
        activity_id = excluded.activity_id,
        session_id = excluded.session_id,
        updated_at = CURRENT_TIMESTAMP,
        is_valid = TRUE
    `, [tokenId, userId, activityToken, activityId, sessionId]);

    res.json({ success: true });
  } catch (error) {
    console.error('Live Activity token registration error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Delete token
router.delete('/token/:tokenId', authenticateToken, async (req, res) => {
  const { tokenId } = req.params;
  const userId = req.user.id;

  try {
    await db.run(
      'DELETE FROM push_tokens WHERE id = ? AND user_id = ?',
      [tokenId, userId]
    );
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get push status
router.get('/status', authenticateToken, async (req, res) => {
  const userId = req.user.id;

  try {
    const deviceTokens = await db.all(
      'SELECT id, created_at FROM push_tokens WHERE user_id = ? AND token_type = ? AND is_valid = TRUE',
      [userId, 'device']
    );

    const liveActivityTokens = await db.all(
      'SELECT activity_id, session_id, created_at FROM push_tokens WHERE user_id = ? AND token_type = ? AND is_valid = TRUE',
      [userId, 'live_activity']
    );

    res.json({
      deviceTokenRegistered: deviceTokens.length > 0,
      liveActivityTokens: liveActivityTokens.map(t => ({
        activityId: t.activity_id,
        sessionId: t.session_id,
        registeredAt: t.created_at,
      })),
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
```

## Approval Request Timeout

Implement a 60-second timeout for approval requests to prevent Claude from waiting indefinitely.

### Timeout Logic

```javascript
// services/approval-manager.js

class ApprovalManager {
  constructor() {
    this.pendingApprovals = new Map();  // requestId -> { sessionId, userId, timeout, createdAt }
    this.timeoutDuration = 60000;  // 60 seconds
  }

  async createApprovalRequest(sessionId, userId, request) {
    const requestId = `approval-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

    // Store with timeout
    const timeout = setTimeout(
      () => this.handleTimeout(requestId),
      this.timeoutDuration
    );

    this.pendingApprovals.set(requestId, {
      sessionId,
      userId,
      request,
      timeout,
      createdAt: Date.now(),
      expiresAt: Date.now() + this.timeoutDuration
    });

    // Send to iOS clients with expiry time
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

    console.log(`Approval request ${requestId} timed out after 60s`);

    // Clean up
    this.pendingApprovals.delete(requestId);

    // Notify iOS clients to clear the approval UI
    await this.sendTimeoutNotification(pending.userId, pending.sessionId, requestId);

    // Notify Claude session that approval timed out
    await this.sendToSession(pending.sessionId, {
      type: 'approval_timeout',
      requestId,
      message: 'User did not respond within 60 seconds'
    });
  }

  async handleResponse(requestId, approved) {
    const pending = this.pendingApprovals.get(requestId);
    if (!pending) {
      return { success: false, error: 'Request expired or not found' };
    }

    // Clear timeout
    clearTimeout(pending.timeout);
    this.pendingApprovals.delete(requestId);

    // Clear notifications on other devices
    await this.clearApprovalOnOtherDevices(pending.userId, requestId);

    // Notify Claude session
    await this.sendToSession(pending.sessionId, {
      type: 'approval_response',
      requestId,
      approved
    });

    return { success: true };
  }

  async sendTimeoutNotification(userId, sessionId, requestId) {
    // Send WebSocket event
    await this.sendToUser(userId, {
      type: 'approval_timeout',
      sessionId,
      requestId
    });

    // Send silent push to clear notification
    const tokens = await db.all(
      'SELECT token FROM push_tokens WHERE user_id = ? AND token_type = ? AND is_valid = TRUE',
      [userId, 'device']
    );

    for (const { token } of tokens) {
      await apns.sendNotification(token, {
        contentAvailable: true,  // Silent push
        data: {
          type: 'clear_approval',
          requestId
        }
      });
    }
  }
}

module.exports = new ApprovalManager();
```

### API Route for Approval Response

```javascript
// routes/approval.js

router.post('/approval/:requestId/respond', authenticateToken, async (req, res) => {
  const { requestId } = req.params;
  const { approved, deviceToken } = req.body;

  const result = await ApprovalManager.handleResponse(requestId, approved);

  if (result.success) {
    // Clear on other devices (exclude the responding device)
    await ApprovalManager.clearApprovalOnOtherDevices(
      req.user.id,
      requestId,
      deviceToken  // Exclude this device
    );
  }

  res.json(result);
});
```

## Session Handoff Tracking

Track which client is actively using each session to handle multi-device scenarios.

### Session Active Client Table

```sql
CREATE TABLE session_active_clients (
    session_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    client_type TEXT NOT NULL,  -- 'ios', 'desktop', 'web'
    device_id TEXT NOT NULL,
    push_token TEXT,            -- For sending handoff notifications
    last_activity_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id)
);
```

### Handoff Logic

```javascript
// services/session-handler.js

async handleClientActivity(sessionId, userId, clientType, deviceId, pushToken) {
  const current = await db.get(
    'SELECT * FROM session_active_clients WHERE session_id = ?',
    [sessionId]
  );

  // Check if different device is taking over
  if (current && current.device_id !== deviceId) {
    // Notify previous device to release Live Activity
    if (current.push_token) {
      await apns.sendNotification(current.push_token, {
        contentAvailable: true,
        data: {
          type: 'session_handoff',
          sessionId,
          handedOffTo: clientType
        }
      });
    }

    console.log(`Session ${sessionId} handed off from ${current.client_type} to ${clientType}`);
  }

  // Update active client
  await db.run(`
    INSERT INTO session_active_clients (session_id, user_id, client_type, device_id, push_token, last_activity_at)
    VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
    ON CONFLICT(session_id) DO UPDATE SET
      client_type = excluded.client_type,
      device_id = excluded.device_id,
      push_token = excluded.push_token,
      last_activity_at = CURRENT_TIMESTAMP
  `, [sessionId, userId, clientType, deviceId, pushToken]);
}
```

### WebSocket Integration

```javascript
// In WebSocket connection handler

ws.on('message', async (data) => {
  const message = JSON.parse(data);

  // Update active client on any message
  await sessionHandler.handleClientActivity(
    message.sessionId,
    userId,
    message.clientType || 'ios',
    message.deviceId,
    message.pushToken
  );

  // Handle message...
});
```

## Multi-Device Notification Clearing

```javascript
// services/push-service.js

async clearApprovalOnOtherDevices(userId, requestId, excludeToken = null) {
  const tokens = await db.all(
    'SELECT token FROM push_tokens WHERE user_id = ? AND token_type = ? AND is_valid = TRUE',
    [userId, 'device']
  );

  let notified = 0;
  for (const { token } of tokens) {
    if (token === excludeToken) continue;

    await apns.sendNotification(token, {
      contentAvailable: true,
      data: {
        type: 'clear_approval',
        clearApprovalId: requestId,
        reason: 'approved_on_other_device'
      }
    });
    notified++;
  }

  return notified;
}

async clearSessionNotifications(userId, sessionId) {
  const tokens = await db.all(
    'SELECT token FROM push_tokens WHERE user_id = ? AND token_type = ? AND is_valid = TRUE',
    [userId, 'device']
  );

  let cleared = 0;
  for (const { token } of tokens) {
    await apns.sendNotification(token, {
      contentAvailable: true,
      data: {
        type: 'clear_session',
        sessionId
      }
    });
    cleared++;
  }

  // Also end Live Activities for this session
  const liveActivityTokens = await db.all(
    'SELECT token FROM push_tokens WHERE user_id = ? AND token_type = ? AND session_id = ? AND is_valid = TRUE',
    [userId, 'live_activity', sessionId]
  );

  for (const { token } of liveActivityTokens) {
    await apns.sendLiveActivityUpdate(token, {
      status: 'completed',
      currentOperation: 'Session ended'
    }, 'end');
  }

  return cleared + liveActivityTokens.length;
}
```

## Rate Limiting

APNs has rate limits for Live Activity updates. Implement throttling:

```javascript
// services/live-activity-throttle.js

class LiveActivityThrottle {
  constructor() {
    this.lastUpdate = new Map();  // token -> timestamp
    this.minInterval = 15000;     // 15 seconds minimum between updates
  }

  canUpdate(token) {
    const lastTime = this.lastUpdate.get(token);
    if (!lastTime) return true;
    return Date.now() - lastTime >= this.minInterval;
  }

  markUpdated(token) {
    this.lastUpdate.set(token, Date.now());
  }

  async throttledUpdate(token, updateFn) {
    if (!this.canUpdate(token)) {
      console.log(`Throttling Live Activity update for token ${token.substring(0, 8)}...`);
      return { success: false, reason: 'throttled' };
    }

    const result = await updateFn();
    if (result.success) {
      this.markUpdated(token);
    }
    return result;
  }
}

module.exports = new LiveActivityThrottle();
```

## Testing

### Test Push Notification

```bash
# Using curl with APNs HTTP/2
curl -v \
  --http2 \
  --header "authorization: bearer $JWT_TOKEN" \
  --header "apns-topic: com.codingbridge.CodingBridge" \
  --header "apns-push-type: alert" \
  --data '{"aps":{"alert":{"title":"Test","body":"Hello"}}}' \
  https://api.sandbox.push.apple.com/3/device/$DEVICE_TOKEN
```

### Test Live Activity Update

```bash
curl -v \
  --http2 \
  --header "authorization: bearer $JWT_TOKEN" \
  --header "apns-topic: com.codingbridge.CodingBridge.push-type.liveactivity" \
  --header "apns-push-type: liveactivity" \
  --data '{"aps":{"timestamp":1234567890,"event":"update","content-state":{"status":"processing"}}}' \
  https://api.sandbox.push.apple.com/3/device/$ACTIVITY_TOKEN
```

## Security Considerations

1. **Token Storage**: Store tokens securely, don't expose in logs
2. **User Isolation**: Only send notifications to authenticated user's tokens
3. **Token Validation**: Mark invalid tokens immediately
4. **Rate Limiting**: Prevent abuse via API rate limits
5. **HTTPS Only**: All API endpoints must use HTTPS

## Deployment Checklist

- [ ] Generate APNs key (.p8) from Apple Developer Portal
- [ ] Store key securely on server (not in repo)
- [ ] Configure environment variables
- [ ] Run database migrations for push_tokens table
- [ ] Deploy API endpoints
- [ ] Test with development APNs environment first
- [ ] Switch to production APNs for App Store release

## References

- [Setting Up a Remote Notification Server](https://developer.apple.com/documentation/usernotifications/setting-up-a-remote-notification-server)
- [Sending Notification Requests to APNs](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns)
- [Starting and Updating Live Activities with Push Notifications](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications)
- [@parse/node-apn NPM Package](https://www.npmjs.com/package/@parse/node-apn)
