# Deep Links

> URL scheme for notification navigation.

## URL Scheme Registration

Add to `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>codingbridge</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.codingbridge.CodingBridge</string>
    </dict>
</array>
```

## Routes

| URL Pattern | Action |
|-------------|--------|
| `codingbridge://session/{id}` | Navigate to session |
| `codingbridge://session/{id}/approval/{requestId}` | Show approval dialog |
| `codingbridge://session/{id}/question/{questionId}` | Show question |
| `codingbridge://settings/notifications` | Open notification settings |

## Notification Deep Links

Add to notification userInfo:

```swift
content.userInfo = [
    "type": "approval",
    "requestId": requestId,
    "sessionId": sessionId,
    "projectPath": projectPath,
    "deepLink": "codingbridge://session/\(sessionId)/approval/\(requestId)"
]
```

## Handler Implementation

```swift
// In ContentView or coordinator

.onOpenURL { url in
    handleDeepLink(url)
}
.onReceive(NotificationCenter.default.publisher(for: .navigateToDeepLink)) { notification in
    if let url = notification.userInfo?["url"] as? URL {
        handleDeepLink(url)
    }
}

func handleDeepLink(_ url: URL) {
    guard url.scheme == "codingbridge" else { return }

    let pathComponents = url.pathComponents.filter { $0 != "/" }

    switch pathComponents.first {
    case "session":
        guard pathComponents.count >= 2 else { return }
        let sessionId = pathComponents[1]

        if pathComponents.count >= 4 {
            switch pathComponents[2] {
            case "approval":
                let requestId = pathComponents[3]
                navigateToApproval(sessionId: sessionId, requestId: requestId)
            case "question":
                let questionId = pathComponents[3]
                navigateToQuestion(sessionId: sessionId, questionId: questionId)
            default:
                navigateToSession(sessionId)
            }
        } else {
            navigateToSession(sessionId)
        }

    case "settings":
        if pathComponents.count >= 2 && pathComponents[1] == "notifications" {
            showNotificationSettings = true
        }

    default:
        break
    }
}
```

## NotificationManager Deep Link Posting

```swift
func handleOpenAction(userInfo: [AnyHashable: Any]) {
    guard let deepLink = userInfo["deepLink"] as? String,
          let url = URL(string: deepLink) else { return }

    NotificationCenter.default.post(
        name: .navigateToDeepLink,
        object: nil,
        userInfo: ["url": url]
    )
}
```

## Extension

```swift
extension Notification.Name {
    static let navigateToDeepLink = Notification.Name("NavigateToDeepLink")
    static let notificationTapped = Notification.Name("NotificationTapped")
}
```

---
**Index:** [../00-INDEX.md](../00-INDEX.md)
