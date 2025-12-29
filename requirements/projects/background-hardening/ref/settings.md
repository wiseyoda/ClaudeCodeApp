# User Settings

> New settings for background processing and notifications.

## AppSettings Additions

```swift
// In AppSettings.swift

// MARK: - Background & Notifications

/// Enable Live Activities for task progress (default: true)
@AppStorage("enableLiveActivities") var enableLiveActivities = true

/// Enable background notifications when app not in foreground (default: true)
@AppStorage("enableBackgroundNotifications") var enableBackgroundNotifications = true

/// Show detailed content in notifications visible on Lock Screen (default: false)
/// When false, shows generic "Claude needs attention" instead of command details
@AppStorage("showNotificationDetails") var showNotificationDetails = false

/// Continue background processing in Low Power Mode (default: false)
@AppStorage("backgroundInLowPowerMode") var backgroundInLowPowerMode = false

/// Enable time-sensitive notifications that break through Focus modes (default: true)
@AppStorage("enableTimeSensitiveNotifications") var enableTimeSensitiveNotifications = true
```

## Settings UI

```swift
// In SettingsView.swift

Section("Background & Notifications") {
    Toggle("Live Activities", isOn: $settings.enableLiveActivities)
        .onChange(of: settings.enableLiveActivities) { _, enabled in
            if !enabled {
                Task { await LiveActivityManager.shared.endCurrentActivity() }
            }
        }

    Toggle("Background Notifications", isOn: $settings.enableBackgroundNotifications)

    Toggle("Show Details on Lock Screen", isOn: $settings.showNotificationDetails)

    Toggle("Background in Low Power Mode", isOn: $settings.backgroundInLowPowerMode)

    Toggle("Break Through Focus Modes", isOn: $settings.enableTimeSensitiveNotifications)
}
```

## Permission Status Display

```swift
Section("Permissions") {
    HStack {
        Text("Notifications")
        Spacer()
        PermissionStatusBadge(status: notificationStatus)
    }

    HStack {
        Text("Live Activities")
        Spacer()
        PermissionStatusBadge(status: liveActivityStatus)
    }

    if notificationStatus == .denied || liveActivityStatus == .denied {
        Button("Open Settings") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }
}
```

## Permission Status Badge

```swift
struct PermissionStatusBadge: View {
    let status: PermissionStatus

    enum PermissionStatus {
        case granted, denied, notDetermined
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(color)
    }

    private var iconName: String {
        switch status {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle.fill"
        }
    }

    private var text: String {
        switch status {
        case .granted: return "Enabled"
        case .denied: return "Disabled"
        case .notDetermined: return "Not Set"
        }
    }

    private var color: Color {
        switch status {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined: return .secondary
        }
    }
}
```

## Check Live Activity Availability

```swift
func checkLiveActivityAvailability() -> LiveActivityStatus {
    let authInfo = ActivityAuthorizationInfo()

    if !authInfo.areActivitiesEnabled {
        return .disabledByUser
    }

    if !settings.enableLiveActivities {
        return .disabledInApp
    }

    return .available
}

enum LiveActivityStatus {
    case available
    case disabledByUser
    case disabledInApp
    case notSupported
}
```

---
**Index:** [../00-INDEX.md](../00-INDEX.md)
