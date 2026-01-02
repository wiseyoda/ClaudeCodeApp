# Firebase Console Setup Guide

Detailed guide for setting up the Firebase project and console configuration.

## Creating the Firebase Project

### Step 1: Access Firebase Console

1. Navigate to [console.firebase.google.com](https://console.firebase.google.com)
2. Sign in with your Google account
3. Click **"Create a project"** or **"Add project"**

### Step 2: Name Your Project

- **Project name**: `CodingBridge` (or your preferred name)
- Firebase will suggest a unique project ID
- Accept or customize the project ID
- Click **Continue**

### Step 3: Google Analytics

**Important**: Enable Google Analytics - it's required for Crashlytics to work properly.

1. Toggle **"Enable Google Analytics for this project"** ON
2. Select or create a Google Analytics account
3. Accept the Google Analytics terms
4. Click **Create project**

Wait ~30 seconds for project creation to complete.

---

## Registering the iOS App

### Step 1: Add iOS App

1. On project overview, click the **iOS+ icon**
2. This opens the "Add Firebase to your Apple app" wizard

### Step 2: Register App

Fill in the following:

| Field | Value | Notes |
|-------|-------|-------|
| **Bundle ID** | `com.yourname.CodingBridge` | Must match Xcode exactly |
| **App nickname** | `CodingBridge iOS` | Optional, for console display |
| **App Store ID** | Leave blank | Add when published to App Store |

**Finding your Bundle ID:**
1. Open `CodingBridge.xcodeproj` in Xcode
2. Select CodingBridge target
3. General tab → Bundle Identifier

Click **Register app**

### Step 3: Download Config File

1. Click **Download GoogleService-Info.plist**
2. Save to a secure location
3. This file contains your Firebase configuration

**Important**: This file contains API keys. Do not commit to public repositories.

### Step 4: Complete Setup

Click through the remaining wizard steps (SDK installation will be done via SPM).

---

## Configuring Cloud Messaging (FCM)

### Upload APNs Key

1. In Firebase Console, click **gear icon** → **Project settings**
2. Go to **Cloud Messaging** tab
3. Scroll to **Apple app configuration**
4. Under **APNs Authentication Key**, click **Upload**

Upload details:
- **Key file**: Your `.p8` file from Apple Developer
- **Key ID**: 10-character ID from Apple Developer
- **Team ID**: Your Apple Developer Team ID

Click **Upload**

---

## Configuring Remote Config

### Initial Setup

1. In Firebase Console sidebar, click **Remote Config**
2. Click **Create configuration**

### Add Parameters

| Parameter | Type | Default Value | Description |
|-----------|------|---------------|-------------|
| `feature_ssh_enabled` | Boolean | `true` | Enable SSH functionality |
| `feature_ideas_enabled` | Boolean | `true` | Enable Ideas feature |
| `feature_bookmarks_enabled` | Boolean | `true` | Enable bookmarks |
| `max_message_history` | Number | `50` | Messages to keep in history |
| `session_timeout_minutes` | Number | `30` | Session timeout |
| `api_timeout_seconds` | Number | `30` | API request timeout |
| `sse_reconnect_delay_ms` | Number | `1000` | SSE reconnection delay |

### Conditions (Optional)

You can create conditions for A/B testing or staged rollouts:

1. Click **Add condition**
2. Examples:
   - **Beta users**: App version contains "beta"
   - **iOS 18+**: Platform iOS version >= 18

### Publish

Click **Publish changes** to make parameters active.

---

## Viewing Analytics

### Initial Data

- Analytics data may take several hours to appear
- Real-time events visible in **Analytics → DebugView** (requires debug flag)

### Key Dashboards

- **Dashboard**: Overview of users, sessions, engagement
- **Events**: All logged events
- **DebugView**: Real-time event debugging
- **Audiences**: User segments

---

## Viewing Crashlytics

### First Crash Report

1. Navigate to **Crashlytics** in sidebar
2. First crash report may take up to 5 minutes to appear
3. Subsequent crashes appear within seconds

### Key Features

- **Issues**: Grouped crash reports
- **Velocity alerts**: Notifications for crash spikes
- **Version trends**: Crash-free users by version

---

## Project Settings Reference

### General Tab
- Project name and ID
- Public-facing name
- Support email

### Cloud Messaging Tab
- APNs configuration
- Server key (for backend)
- Sender ID

### Service Accounts Tab
- Firebase Admin SDK configuration
- Service account JSON for backend

### Data Privacy Tab
- Data retention settings
- Analytics data sharing

---

## Security Best Practices

1. **Restrict API keys**: In Google Cloud Console, restrict Firebase API keys to iOS only
2. **Enable App Check**: For production, enable Firebase App Check
3. **Monitor usage**: Set up budget alerts for Firebase services
4. **Audit access**: Review who has access to Firebase project

---

## Troubleshooting

### "Project creation failed"
- Check Google account has permissions
- Try incognito/private browser
- Clear browser cache

### "Bundle ID already registered"
- Each bundle ID can only be registered once per project
- Delete existing app or use different bundle ID

### "Analytics not showing data"
- Wait several hours for initial data
- Use DebugView for real-time testing
- Verify GoogleService-Info.plist is correct

### "Cloud Messaging not working"
- Verify APNs key is uploaded correctly
- Check Key ID and Team ID match
- Ensure physical device is used (not simulator)
