# Backend API

> New endpoints and APNs integration for claudecodeui.

## Prerequisites

1. **APNs Key (.p8)** from Apple Developer Portal
2. **Key ID** and **Team ID** from Apple
3. **Bundle ID** registered with push capability

## Environment Variables

```bash
APNS_KEY_ID=ABC123DEFG
APNS_TEAM_ID=TEAM123456
APNS_KEY_PATH=/path/to/AuthKey_ABC123DEFG.p8
APNS_BUNDLE_ID=com.codingbridge.CodingBridge
APNS_ENVIRONMENT=development  # or "production"
```

## New Endpoints

### Register Push Token

```
POST /api/push/register
Authorization: Bearer <jwt>

{
  "token": "abc123...",
  "tokenType": "device",  // or "live_activity"
  "platform": "ios",
  "environment": "development",
  "activityId": "...",    // if live_activity
  "sessionId": "...",     // if live_activity
  "previousToken": "..."  // for token rotation
}

Response: { "success": true }
```

### Invalidate Token

```
DELETE /api/push/invalidate
Authorization: Bearer <jwt>

{ "token": "abc123..." }

Response: { "success": true }
```

### Get Push Status

```
GET /api/push/status
Authorization: Bearer <jwt>

Response:
{
  "deviceTokenRegistered": true,
  "liveActivityTokens": [
    { "activityId": "...", "sessionId": "...", "registeredAt": "..." }
  ]
}
```

## Database Schema

```sql
CREATE TABLE push_tokens (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    token TEXT NOT NULL UNIQUE,
    token_type TEXT NOT NULL,  -- 'device' or 'live_activity'
    activity_id TEXT,
    session_id TEXT,
    platform TEXT DEFAULT 'ios',
    environment TEXT DEFAULT 'development',
    is_valid BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_user_id (user_id),
    INDEX idx_session_id (session_id)
);
```

## APNs Integration

### Node.js Service

```javascript
// services/apns.js

const apn = require('@parse/node-apn');

class APNSService {
  constructor() {
    this.provider = new apn.Provider({
      token: {
        key: fs.readFileSync(process.env.APNS_KEY_PATH),
        keyId: process.env.APNS_KEY_ID,
        teamId: process.env.APNS_TEAM_ID,
      },
      production: process.env.APNS_ENVIRONMENT === 'production',
    });
    this.bundleId = process.env.APNS_BUNDLE_ID;
  }

  async sendNotification(deviceToken, payload) {
    const notification = new apn.Notification();
    notification.topic = this.bundleId;
    notification.expiry = Math.floor(Date.now() / 1000) + 3600;
    notification.sound = payload.sound || 'default';
    notification.alert = {
      title: payload.title,
      subtitle: payload.subtitle,
      body: payload.body,
    };
    notification.category = payload.category;
    notification.payload = payload.data || {};

    const result = await this.provider.send(notification, deviceToken);
    return { success: result.failed.length === 0 };
  }

  async sendLiveActivityUpdate(activityToken, contentState, event = 'update') {
    const notification = new apn.Notification();
    notification.topic = `${this.bundleId}.push-type.liveactivity`;
    notification.pushType = 'liveactivity';
    notification.expiry = Math.floor(Date.now() / 1000) + 300;

    notification.aps = {
      timestamp: Math.floor(Date.now() / 1000),
      event: event,
      'content-state': contentState,
      'stale-date': Math.floor(Date.now() / 1000) + 300,
    };

    if (event === 'end') {
      notification.aps['dismissal-date'] = Math.floor(Date.now() / 1000) + 900;
    }

    return await this.provider.send(notification, activityToken);
  }
}

module.exports = new APNSService();
```

## Push Payload Formats

### Approval Request

```json
{
  "aps": {
    "alert": {
      "title": "Approval Needed",
      "subtitle": "Bash",
      "body": "Execute: npm test"
    },
    "sound": "default",
    "category": "APPROVAL_REQUEST",
    "interruption-level": "time-sensitive"
  },
  "requestId": "approval-123",
  "toolName": "Bash",
  "type": "approval"
}
```

### Live Activity Update

```json
{
  "aps": {
    "timestamp": 1234567890,
    "event": "update",
    "content-state": {
      "status": "processing",
      "currentOperation": "Running tests...",
      "elapsedSeconds": 120,
      "todoProgress": {
        "completed": 3,
        "total": 7,
        "currentTask": "Fix auth bug"
      }
    },
    "stale-date": 1234568190
  }
}
```

### Clear Notification (Silent)

```json
{
  "aps": {
    "content-available": 1
  },
  "clearApprovalId": "approval-123"
}
```

## Rate Limiting

Throttle Live Activity updates (APNs limit):

```javascript
const minInterval = 15000;  // 15 seconds
const lastUpdate = new Map();

async function throttledUpdate(token, contentState) {
  const lastTime = lastUpdate.get(token);
  if (lastTime && Date.now() - lastTime < minInterval) {
    return { success: false, reason: 'throttled' };
  }

  lastUpdate.set(token, Date.now());
  return await apns.sendLiveActivityUpdate(token, contentState);
}
```

---
**Prev:** [notification-actions](./notification-actions.md) | **Next:** [backend-events](./backend-events.md) | **Index:** [../00-INDEX.md](../00-INDEX.md)
