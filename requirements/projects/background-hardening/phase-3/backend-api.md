# Backend API

> Firebase Admin SDK integration for claudecodeui.

## Prerequisites

1. **Firebase Project** created at https://console.firebase.google.com
2. **Service Account Key** (.json) from Firebase Console → Project Settings → Service Accounts
3. **APNs Key (.p8)** uploaded to Firebase Console → Cloud Messaging → Apple app configuration
4. **Bundle ID** registered with push capability in Apple Developer Portal

## Environment Variables

```bash
# Firebase Admin SDK
GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json

# Or inline credentials (for containerized deployments)
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxx@your-project.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"

# APNs for Live Activities (Firebase Admin can send direct APNs)
APNS_KEY_ID=ABC123DEFG
APNS_TEAM_ID=TEAM123456
APNS_KEY_PATH=/path/to/AuthKey_ABC123DEFG.p8
APNS_BUNDLE_ID=com.level.CodingBridge
```

## New Endpoints

### Register FCM Token

```
POST /api/push/register
Authorization: Bearer <jwt>

{
  "fcmToken": "abc123...",
  "platform": "ios",
  "environment": "sandbox"  // or "production"
}

Response: { "success": true }
```

### Register Live Activity Token

```
POST /api/push/live-activity
Authorization: Bearer <jwt>

{
  "apnsToken": "abc123...",
  "activityId": "activity-uuid",
  "sessionId": "session-uuid",
  "previousToken": "...",  // optional, for rotation
  "platform": "ios",
  "environment": "sandbox"
}

Response: { "success": true }
```

### Invalidate Token

```
DELETE /api/push/invalidate
Authorization: Bearer <jwt>

{ "fcmToken": "abc123..." }

Response: { "success": true }
```

### Get Push Status (Debug)

```
GET /api/push/status
Authorization: Bearer <jwt>

Response:
{
  "fcmTokenRegistered": true,
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
    fcm_token TEXT,
    apns_token TEXT,
    token_type TEXT NOT NULL,  -- 'fcm' or 'live_activity'
    activity_id TEXT,
    session_id TEXT,
    platform TEXT DEFAULT 'ios',
    environment TEXT DEFAULT 'sandbox',
    is_valid BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_user_id (user_id),
    INDEX idx_session_id (session_id),
    INDEX idx_fcm_token (fcm_token)
);
```

## Firebase Admin SDK Integration

### Node.js Service

```javascript
// services/firebase.js

const admin = require('firebase-admin');

class FirebaseService {
  constructor() {
    // Initialize with service account
    if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
      });
    } else {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId: process.env.FIREBASE_PROJECT_ID,
          clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
          privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
        }),
      });
    }
  }

  // Send notification via FCM
  async sendNotification(fcmToken, payload) {
    const message = {
      token: fcmToken,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            sound: 'default',
            category: payload.category,
            'interruption-level': 'time-sensitive',
          },
          ...payload.data,
        },
      },
    };

    try {
      const response = await admin.messaging().send(message);
      return { success: true, messageId: response };
    } catch (error) {
      console.error('FCM send error:', error);

      // Handle invalid token
      if (error.code === 'messaging/registration-token-not-registered') {
        await this.invalidateToken(fcmToken);
      }

      return { success: false, error: error.message };
    }
  }

  // Send silent push to clear notifications
  async sendSilentPush(fcmToken, data) {
    const message = {
      token: fcmToken,
      apns: {
        headers: {
          'apns-priority': '5',
          'apns-push-type': 'background',
        },
        payload: {
          aps: {
            'content-available': 1,
          },
          ...data,
        },
      },
    };

    return await admin.messaging().send(message);
  }

  // Invalidate token in database
  async invalidateToken(fcmToken) {
    // Update database to mark token as invalid
    // Implementation depends on your database
  }
}

module.exports = new FirebaseService();
```

### Live Activity Updates (Direct APNs)

Firebase Admin SDK can also send direct APNs messages for Live Activities:

```javascript
// services/liveActivity.js

const apn = require('@parse/node-apn');

class LiveActivityService {
  constructor() {
    this.provider = new apn.Provider({
      token: {
        key: fs.readFileSync(process.env.APNS_KEY_PATH),
        keyId: process.env.APNS_KEY_ID,
        teamId: process.env.APNS_TEAM_ID,
      },
      production: process.env.NODE_ENV === 'production',
    });
    this.bundleId = process.env.APNS_BUNDLE_ID;
  }

  async updateActivity(apnsToken, contentState, event = 'update') {
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

    return await this.provider.send(notification, apnsToken);
  }
}

module.exports = new LiveActivityService();
```

## Push Payload Formats

### Approval Request (via FCM)

```javascript
await firebase.sendNotification(fcmToken, {
  title: 'Approval Needed',
  body: 'Execute: npm test',
  category: 'APPROVAL_REQUEST',
  data: {
    requestId: 'approval-123',
    toolName: 'Bash',
    type: 'approval',
  },
});
```

### Task Complete (via FCM)

```javascript
await firebase.sendNotification(fcmToken, {
  title: 'Task Complete',
  body: 'Claude finished working on your request.',
  category: 'TASK_COMPLETE',
  data: {
    sessionId: 'session-123',
    type: 'complete',
  },
});
```

### Live Activity Update (Direct APNs)

```javascript
await liveActivity.updateActivity(apnsToken, {
  status: 'processing',
  currentOperation: 'Running tests...',
  elapsedSeconds: 120,
  todoProgress: {
    completed: 3,
    total: 7,
    currentTask: 'Fix auth bug',
  },
});
```

### Clear Notification (Silent Push via FCM)

```javascript
await firebase.sendSilentPush(fcmToken, {
  clearApprovalId: 'approval-123',
});
```

## Rate Limiting

Throttle Live Activity updates to respect APNs limits:

```javascript
const minInterval = 15000;  // 15 seconds
const lastUpdate = new Map();

async function throttledActivityUpdate(token, contentState) {
  const lastTime = lastUpdate.get(token);
  if (lastTime && Date.now() - lastTime < minInterval) {
    return { success: false, reason: 'throttled' };
  }

  lastUpdate.set(token, Date.now());
  return await liveActivity.updateActivity(token, contentState);
}
```

## FCM vs Direct APNs

| Use Case | Service | Why |
|----------|---------|-----|
| Approval notifications | FCM | Simpler, handles token rotation |
| Question notifications | FCM | Simpler, handles token rotation |
| Completion notifications | FCM | Simpler, handles token rotation |
| Clear notifications | FCM (silent) | Background content-available |
| Live Activity updates | Direct APNs | FCM doesn't support liveactivity push type |

---
**Prev:** [notification-actions](./notification-actions.md) | **Next:** [backend-events](./backend-events.md) | **Index:** [../00-INDEX.md](../00-INDEX.md)
