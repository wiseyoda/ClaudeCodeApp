# Crashlytics Setup Guide

Complete guide for Firebase Crashlytics crash reporting integration.

## Overview

Crashlytics provides:
- Real-time crash reporting
- Stack traces with line numbers
- Crash grouping and trends
- Non-fatal error logging
- Custom logging and keys
- Velocity alerts for crash spikes

---

## Prerequisites

- [ ] Firebase SDK installed (includes FirebaseCrashlytics)
- [ ] FirebaseAnalytics included (required dependency)
- [ ] `GoogleService-Info.plist` configured
- [ ] dSYM upload build phase added

---

## Build Configuration

### dSYM Upload Script

The Crashlytics run script uploads debug symbols for readable stack traces.

**Location**: Build Phases → Last phase

**Script**:
```bash
"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
```

**Input Files**:
```
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${PRODUCT_NAME}
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Info.plist
$(TARGET_BUILD_DIR)/$(INFOPLIST_PATH)
```

### Build Settings

| Setting | Value |
|---------|-------|
| Debug Information Format | DWARF with dSYM File |
| User Script Sandboxing | No (if uploads fail) |

---

## Code Implementation

### Basic Configuration

```swift
import FirebaseCrashlytics

// In FirebaseManager.configure()
private func configureCrashlytics() {
    // Enable crash collection
    Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

    // Set user identifier (if available)
    if let userId = getUserId() {
        Crashlytics.crashlytics().setUserID(userId)
    }

    Logger.shared.info("Crashlytics configured")
}
```

### Custom Keys

Add context to crash reports:

```swift
// Set custom key-value pairs
func setCustomKey(_ key: String, value: Any) {
    Crashlytics.crashlytics().setCustomValue(value, forKey: key)
}

// Example usage
FirebaseManager.shared.setCustomKey("current_screen", value: "ChatView")
FirebaseManager.shared.setCustomKey("session_id", value: sessionId)
FirebaseManager.shared.setCustomKey("server_url", value: settings.serverURL)
```

### Custom Logging

Add breadcrumbs to understand crash context:

```swift
// Log messages that appear in crash reports
func log(_ message: String) {
    Crashlytics.crashlytics().log(message)
}

// Example usage
FirebaseManager.shared.log("User tapped send button")
FirebaseManager.shared.log("Starting SSH connection")
FirebaseManager.shared.log("Received API response: \(statusCode)")
```

### Non-Fatal Error Reporting

Report errors that don't crash the app:

```swift
func logError(_ error: Error, userInfo: [String: Any]? = nil) {
    var info = userInfo ?? [:]
    info["timestamp"] = Date().ISO8601Format()

    Crashlytics.crashlytics().record(error: error, userInfo: info)
}

// Example usage
do {
    try await apiClient.fetchData()
} catch {
    FirebaseManager.shared.logError(error, userInfo: [
        "endpoint": "/api/data",
        "retry_count": retryCount
    ])
}
```

---

## Integration with Existing Error Handling

### Update AppError

Integrate with existing `AppError` type:

```swift
// In AppError.swift or error handling code

extension AppError {
    func reportToCrashlytics() {
        let userInfo: [String: Any] = [
            "error_type": self.type.rawValue,
            "error_code": self.code ?? "unknown",
            "is_retryable": self.isRetryable
        ]

        FirebaseManager.shared.logError(self, userInfo: userInfo)
    }
}
```

### Update Logger

Log important events to Crashlytics:

```swift
// In Logger.swift

func error(_ message: String, error: Error? = nil) {
    // Existing logging...

    // Also log to Crashlytics
    FirebaseManager.shared.log("[ERROR] \(message)")

    if let error = error {
        FirebaseManager.shared.logError(error)
    }
}
```

---

## User Identification

### Set User ID

```swift
// Set when user is identified
func setUserId(_ userId: String) {
    Crashlytics.crashlytics().setUserID(userId)
}

// Clear on logout
func clearUserId() {
    Crashlytics.crashlytics().setUserID("")
}
```

### Privacy Considerations

- User IDs should be internal identifiers, not PII
- Don't include email, name, or phone in user ID
- Consider hashing if using identifiable data
- Provide opt-out mechanism if required by privacy policy

---

## Testing Crashlytics

### Force a Test Crash

Add temporary test code (DEBUG only):

```swift
#if DEBUG
// In SettingsView.swift or a debug menu
Button("Test Crash") {
    fatalError("Test crash for Crashlytics verification")
}

Button("Test Non-Fatal") {
    let error = NSError(
        domain: "TestError",
        code: 42,
        userInfo: [NSLocalizedDescriptionKey: "Test non-fatal error"]
    )
    FirebaseManager.shared.logError(error)
}
#endif
```

### Verify Crash Report

1. Build and run app on device
2. Trigger test crash
3. Relaunch app (sends crash report on next launch)
4. Wait 5 minutes
5. Check Firebase Console → Crashlytics

### Verify dSYM Upload

1. Build for Release configuration
2. Check build log for Crashlytics upload
3. In Firebase Console → Crashlytics → look for readable stack traces

If stack traces show memory addresses instead of function names, dSYMs aren't uploading correctly.

---

## Crashlytics Dashboard

### Issues View

- **Grouped crashes**: Similar crashes grouped together
- **Impact**: Users and events affected
- **Trend**: Crash frequency over time

### Crash Details

- **Stack trace**: Full call stack with line numbers
- **Keys**: Custom keys set before crash
- **Logs**: Custom log messages
- **Device info**: OS version, device model, memory

### Velocity Alerts

Set up alerts for crash spikes:

1. Firebase Console → Crashlytics
2. Click **Alerts** (bell icon)
3. Configure threshold (e.g., 1% crash rate)
4. Add email/Slack notifications

---

## Best Practices

### Do

1. **Set meaningful custom keys**: Screen name, user state, feature flags
2. **Log breadcrumbs**: Important user actions and state changes
3. **Report non-fatal errors**: API failures, parsing errors
4. **Use structured error types**: Consistent error codes and domains
5. **Test crash reporting**: Verify before each release

### Don't

1. **Log PII**: No email, passwords, or personal data
2. **Log excessively**: Performance impact from too much logging
3. **Ignore non-fatals**: They indicate potential issues
4. **Skip testing**: Crashes can be missed if not verified

---

## Disabling for Development

```swift
#if DEBUG
Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
#endif
```

Or via Info.plist:
```xml
<key>FirebaseCrashlyticsCollectionEnabled</key>
<false/>
```

---

## Troubleshooting

### Crashes Not Appearing

1. **Wait for app relaunch**: Crashes sent on next launch
2. **Wait 5 minutes**: Processing delay
3. **Check dSYM upload**: Missing symbols = no stack traces
4. **Verify configuration**: Check GoogleService-Info.plist

### Stack Traces Not Symbolicated

1. Check Build Settings → Debug Information Format
2. Verify run script is last build phase
3. Check build log for upload success/failure
4. Disable User Script Sandboxing if needed

### Upload Script Fails

```
error: upload-symbols: Sandbox: upload-symbols deny
```

Solution: Set User Script Sandboxing to No

### Missing Non-Fatal Errors

1. Verify `record(error:)` is called
2. Check Crashlytics collection is enabled
3. Allow 5 minutes for processing

---

## Advanced: Custom Exception Handler

For catching exceptions not handled by Crashlytics:

```swift
// Set early in app lifecycle
NSSetUncaughtExceptionHandler { exception in
    Crashlytics.crashlytics().record(
        error: NSError(
            domain: "UncaughtException",
            code: 0,
            userInfo: [
                NSLocalizedDescriptionKey: exception.reason ?? "Unknown",
                "callStackSymbols": exception.callStackSymbols.joined(separator: "\n")
            ]
        )
    )
}
```
