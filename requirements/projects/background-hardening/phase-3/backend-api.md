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
```

No direct APNs configuration needed - Firebase handles everything including Live Activities.

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

### Live Activity Updates (via FCM HTTP v1 API)

Firebase fully supports Live Activities - no direct APNs needed:

```javascript
// In FirebaseService class

async updateLiveActivity(liveActivityToken, contentState, event = 'update') {
  const message = {
    token: liveActivityToken,
    apns: {
      headers: {
        'apns-priority': '10',
        'apns-push-type': 'liveactivity',
      },
      payload: {
        aps: {
          timestamp: Math.floor(Date.now() / 1000),
          event: event,
          'content-state': contentState,
          'stale-date': Math.floor(Date.now() / 1000) + 300,
        },
      },
    },
  };

  if (event === 'end') {
    message.apns.payload.aps['dismissal-date'] = Math.floor(Date.now() / 1000) + 900;
  }

  return await admin.messaging().send(message);
}

async startLiveActivity(pushToStartToken, attributes, contentState) {
  const message = {
    token: pushToStartToken,
    apns: {
      headers: {
        'apns-priority': '10',
        'apns-push-type': 'liveactivity',
      },
      payload: {
        aps: {
          timestamp: Math.floor(Date.now() / 1000),
          event: 'start',
          'content-state': contentState,
          'attributes-type': 'CodingBridgeActivityAttributes',
          'attributes': attributes,
          alert: {
            title: 'Claude is working',
            body: 'Tap to view progress',
          },
        },
      },
    },
  };

  return await admin.messaging().send(message);
}
```

See: https://firebase.google.com/docs/cloud-messaging/customize-messages/live-activity

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

### Live Activity Update (via FCM)

```javascript
await firebase.updateLiveActivity(liveActivityToken, {
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

## All Push via FCM

| Use Case | FCM Method |
|----------|------------|
| Approval notifications | `sendNotification()` |
| Question notifications | `sendNotification()` |
| Completion notifications | `sendNotification()` |
| Clear notifications | `sendSilentPush()` |
| Live Activity start | `startLiveActivity()` |
| Live Activity update | `updateLiveActivity()` |
| Live Activity end | `updateLiveActivity(..., 'end')` |

No direct APNs integration needed - Firebase handles everything via the HTTP v1 API.

---
**Prev:** [notification-actions](./notification-actions.md) | **Next:** [backend-events](./backend-events.md) | **Index:** [../00-INDEX.md](../00-INDEX.md)
