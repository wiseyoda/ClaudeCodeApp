# Privacy

> Content filtering and data protection.

## Lock Screen Content Filtering

Redact sensitive content from notifications:

```swift
func sanitizeForLockScreen(_ content: String) -> String {
    guard settings.showNotificationDetails else {
        return NSLocalizedString("notification.approval.body.generic", comment: "")
    }

    var sanitized = content

    // Redact tokens, keys, secrets
    let patterns = [
        "(?i)(api[_-]?key|token|secret|password|credential)\\s*[:=]\\s*[\"']?[\\w-]+",
        "(?i)bearer\\s+[\\w-]+",
        "[A-Za-z0-9+/]{40,}={0,2}"  // Long base64 strings
    ]

    for pattern in patterns {
        if let regex = try? NSRegularExpression(pattern: pattern) {
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                range: NSRange(sanitized.startIndex..., in: sanitized),
                withTemplate: "[REDACTED]"
            )
        }
    }

    return String(sanitized.prefix(200))
}
```

## Data Protection Level

Use `.completeUntilFirstUserAuthentication` for files that need background access:

```swift
private func setDataProtection(for url: URL) {
    do {
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    } catch {
        Logger.background.error("Failed to set data protection: \(error)")
    }
}
```

Files with this protection:
- `pending-messages.json`
- `taskState.json` (shared container)
- Any state recovery files

## Keychain for Sensitive Data

```swift
// For truly sensitive data (credentials)

func save(_ data: Data, forKey key: String) throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
    ]
    // ...
}
```

## Notification Content Privacy

- Never include API keys, passwords, tokens
- Truncate long messages (200 char max)
- Use `.authenticationRequired` for sensitive actions
- Respect `showNotificationDetails` setting

```swift
func sendApprovalNotification(...) async {
    let content = UNMutableNotificationContent()

    if settings.showNotificationDetails {
        content.body = sanitizeForLockScreen(summary)
    } else {
        content.body = "Claude needs permission to continue"
    }

    // Require Face ID/Touch ID for approve action
    // (defined in notification category)
}
```

## Memory Warning Handling

Save state immediately on memory pressure:

```swift
NotificationCenter.default.addObserver(
    forName: UIApplication.didReceiveMemoryWarningNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    Task { @MainActor in
        await self?.checkpoint()
    }
}

private func checkpoint() async {
    await MessageQueuePersistence.shared.save()
    await DraftInputPersistence.shared.save()

    if let state = currentTaskState {
        try? SharedContainer.saveTaskState(state)
    }
}
```

---
**Index:** [../00-INDEX.md](../00-INDEX.md)
