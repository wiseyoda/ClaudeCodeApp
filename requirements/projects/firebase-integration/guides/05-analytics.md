# Firebase Analytics Setup Guide

Complete guide for Firebase Analytics integration.

## Overview

Firebase Analytics provides:
- Automatic event collection (app open, screen views, etc.)
- Custom event logging
- User properties
- Audience segmentation
- Integration with other Firebase services

---

## Prerequisites

- [ ] Firebase SDK installed (includes FirebaseAnalytics)
- [ ] `-ObjC` linker flag added
- [ ] `GoogleService-Info.plist` configured

---

## Automatic Events

Firebase automatically collects these events:

| Event | Description |
|-------|-------------|
| `first_open` | First time user opens app |
| `app_update` | App updated to new version |
| `session_start` | User session begins |
| `screen_view` | Screen is viewed |
| `os_update` | Device OS updated |

No code required for these events.

---

## Code Implementation

### Basic Analytics Events

Create a dedicated analytics helper:

```swift
// AnalyticsEvents.swift

import FirebaseAnalytics

enum AnalyticsEvents {

    // MARK: - Session Events

    static func logSessionStart(projectPath: String) {
        Analytics.logEvent("session_start_custom", parameters: [
            "project_path_hash": String(projectPath.hashValue)
        ])
    }

    static func logSessionEnd(duration: TimeInterval, messageCount: Int) {
        Analytics.logEvent("session_end", parameters: [
            "duration_seconds": Int(duration),
            "message_count": messageCount
        ])
    }

    // MARK: - Message Events

    static func logMessageSent(
        hasAttachments: Bool,
        attachmentCount: Int = 0,
        characterCount: Int
    ) {
        Analytics.logEvent("message_sent", parameters: [
            "has_attachments": hasAttachments,
            "attachment_count": attachmentCount,
            "character_count": min(characterCount, 10000) // Cap for analytics
        ])
    }

    static func logMessageReceived(toolCount: Int, hasError: Bool) {
        Analytics.logEvent("message_received", parameters: [
            "tool_count": toolCount,
            "has_error": hasError
        ])
    }

    // MARK: - Feature Usage

    static func logFeatureUsed(_ feature: Feature) {
        Analytics.logEvent("feature_used", parameters: [
            "feature_name": feature.rawValue
        ])
    }

    enum Feature: String {
        case ssh = "ssh"
        case ideas = "ideas"
        case bookmarks = "bookmarks"
        case commands = "commands"
        case history = "history"
        case imageAttachment = "image_attachment"
        case slashCommand = "slash_command"
    }

    // MARK: - Navigation

    static func logScreenView(_ screenName: String, screenClass: String? = nil) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass ?? screenName
        ])
    }

    // MARK: - SSH Events

    static func logSSHConnection(success: Bool, error: String? = nil) {
        var params: [String: Any] = ["success": success]
        if let error = error {
            params["error_type"] = String(error.prefix(100))
        }
        Analytics.logEvent("ssh_connection", parameters: params)
    }

    static func logSSHCommand(command: String, duration: TimeInterval) {
        Analytics.logEvent("ssh_command", parameters: [
            "command_type": categorizeCommand(command),
            "duration_ms": Int(duration * 1000)
        ])
    }

    private static func categorizeCommand(_ command: String) -> String {
        let cmd = command.lowercased()
        if cmd.hasPrefix("git") { return "git" }
        if cmd.hasPrefix("ls") || cmd.hasPrefix("cat") || cmd.hasPrefix("find") { return "file" }
        if cmd.hasPrefix("cd") || cmd.hasPrefix("pwd") { return "navigation" }
        return "other"
    }

    // MARK: - Errors

    static func logError(type: String, message: String, isFatal: Bool = false) {
        Analytics.logEvent("app_error", parameters: [
            "error_type": type,
            "error_message": String(message.prefix(100)),
            "is_fatal": isFatal
        ])
    }

    // MARK: - Settings

    static func logSettingChanged(_ setting: String, value: String) {
        Analytics.logEvent("setting_changed", parameters: [
            "setting_name": setting,
            "setting_value": value
        ])
    }
}
```

### Usage in Views

```swift
// In ChatView.swift

func sendMessage() {
    AnalyticsEvents.logMessageSent(
        hasAttachments: !attachments.isEmpty,
        attachmentCount: attachments.count,
        characterCount: messageText.count
    )
    // ... rest of send logic
}

// In SettingsView.swift

.onAppear {
    AnalyticsEvents.logScreenView("Settings")
}
```

---

## User Properties

Set properties to segment users:

```swift
// Set user properties
Analytics.setUserProperty("subscription_type", forName: "free")
Analytics.setUserProperty("dark_mode_enabled", forName: "true")
Analytics.setUserProperty("preferred_server", forName: serverURL.host ?? "unknown")

// Clear on logout
Analytics.setUserID(nil)
```

### Useful User Properties

| Property | Description |
|----------|-------------|
| `server_type` | local, remote, custom |
| `theme` | light, dark, system |
| `ssh_enabled` | true, false |
| `account_age_days` | 0, 7, 30, 90, 365+ |

---

## Debug Mode

### Enable DebugView

For real-time event debugging:

1. Edit scheme → Run → Arguments
2. Add: `-FIRAnalyticsDebugEnabled`

### View in Console

1. Firebase Console → Analytics → DebugView
2. Select your device
3. See events in real-time

### Disable Debug Mode

Remove the argument or add:
```
-FIRAnalyticsDebugDisabled
```

---

## Screen Tracking

### Automatic Screen Tracking

Firebase automatically tracks SwiftUI views, but names may be generic.

### Manual Screen Tracking

For better naming:

```swift
struct ChatView: View {
    var body: some View {
        content
            .onAppear {
                AnalyticsEvents.logScreenView("Chat", screenClass: "ChatView")
            }
    }
}
```

### Disable Automatic Tracking

If using manual tracking only, add to Info.plist:

```xml
<key>FirebaseAutomaticScreenReportingEnabled</key>
<false/>
```

---

## Event Limits

### Naming Rules

- Event names: 40 characters max
- Parameter names: 40 characters max
- Parameter values: 100 characters max (strings)
- Up to 25 parameters per event
- Up to 500 distinct event types

### Reserved Names

Don't use these prefixes:
- `firebase_`
- `google_`
- `ga_`

---

## Privacy Considerations

### Data Collection Control

```swift
// Disable analytics collection
Analytics.setAnalyticsCollectionEnabled(false)

// Enable analytics collection
Analytics.setAnalyticsCollectionEnabled(true)
```

### GDPR/Privacy Compliance

```swift
// Check user consent
if userConsentsToAnalytics {
    Analytics.setAnalyticsCollectionEnabled(true)
} else {
    Analytics.setAnalyticsCollectionEnabled(false)
}
```

### What NOT to Log

- Personal identifiable information (PII)
- Email addresses, names, phone numbers
- Passwords or credentials
- Health data
- Financial account numbers
- Precise location data

---

## Integration with Views

### Example: ChatView Integration

```swift
struct ChatView: View {
    @State private var sessionStartTime = Date()
    @State private var messageCount = 0

    var body: some View {
        content
            .onAppear {
                sessionStartTime = Date()
                AnalyticsEvents.logSessionStart(projectPath: project.path)
            }
            .onDisappear {
                let duration = Date().timeIntervalSince(sessionStartTime)
                AnalyticsEvents.logSessionEnd(
                    duration: duration,
                    messageCount: messageCount
                )
            }
    }

    func handleNewMessage() {
        messageCount += 1
        // ...
    }
}
```

### Example: Settings Integration

```swift
struct SettingsView: View {
    @AppStorage("darkMode") var darkMode = false

    var body: some View {
        Toggle("Dark Mode", isOn: $darkMode)
            .onChange(of: darkMode) { newValue in
                AnalyticsEvents.logSettingChanged(
                    "dark_mode",
                    value: String(newValue)
                )
            }
    }
}
```

---

## Dashboard Usage

### Key Metrics

- **Active Users**: Daily, weekly, monthly
- **Engagement**: Session duration, screens per session
- **Retention**: Users returning over time
- **Events**: Most common user actions

### Custom Reports

1. Firebase Console → Analytics → Events
2. Click event name for details
3. View parameter breakdowns

### Audiences

Create user segments:

1. Analytics → Audiences
2. Create audience with conditions
3. Use for targeted messaging or A/B tests

---

## Troubleshooting

### Events Not Appearing

1. **Wait time**: Up to 24 hours for standard dashboard
2. **Use DebugView**: Real-time for debug builds
3. **Check collection**: Verify `setAnalyticsCollectionEnabled(true)`
4. **Check configuration**: Verify GoogleService-Info.plist

### DebugView Not Showing Device

1. Verify `-FIRAnalyticsDebugEnabled` argument
2. Check device is connected to internet
3. Force close and reopen app
4. Wait 1-2 minutes

### Missing Parameters

1. Check parameter name length (≤40 chars)
2. Check parameter value length (≤100 chars)
3. Check parameter count (≤25 per event)

---

## Best Practices

1. **Be consistent**: Use consistent naming conventions
2. **Don't over-log**: Focus on meaningful events
3. **Use parameters**: Add context to events
4. **Test in DebugView**: Verify events before release
5. **Document events**: Maintain event catalog
6. **Review regularly**: Check dashboard for insights
