# Remote Config Setup Guide

Complete guide for Firebase Remote Config integration.

## Overview

Remote Config allows you to:
- Change app behavior without app updates
- A/B test features with user segments
- Gradually roll out new features
- Configure per-user personalization
- Set default values with server overrides

---

## Prerequisites

- [ ] Firebase SDK installed (includes FirebaseRemoteConfig)
- [ ] `GoogleService-Info.plist` configured
- [ ] Parameters created in Firebase Console

---

## Console Setup

### Create Parameters

1. Firebase Console → Remote Config
2. Click **Create configuration** (or **Add parameter**)

### Recommended Parameters for CodingBridge

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `feature_ssh_enabled` | Boolean | true | Enable/disable SSH feature |
| `feature_ideas_enabled` | Boolean | true | Enable/disable Ideas feature |
| `feature_bookmarks_enabled` | Boolean | true | Enable/disable bookmarks |
| `max_message_history` | Number | 50 | Messages to keep per session |
| `session_timeout_minutes` | Number | 30 | Session timeout duration |
| `api_timeout_seconds` | Number | 30 | API request timeout |
| `websocket_reconnect_delay_ms` | Number | 1000 | WebSocket reconnection delay |
| `min_supported_version` | String | "1.0.0" | Minimum app version |
| `maintenance_mode` | Boolean | false | Enable maintenance mode |
| `maintenance_message` | String | "" | Message to show in maintenance |

### Publish Changes

Click **Publish changes** to make parameters active.

---

## Local Defaults

### Create RemoteConfigDefaults.plist

Add to Xcode project:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Feature Flags -->
    <key>feature_ssh_enabled</key>
    <true/>
    <key>feature_ideas_enabled</key>
    <true/>
    <key>feature_bookmarks_enabled</key>
    <true/>

    <!-- Limits -->
    <key>max_message_history</key>
    <integer>50</integer>
    <key>session_timeout_minutes</key>
    <integer>30</integer>

    <!-- Timeouts -->
    <key>api_timeout_seconds</key>
    <integer>30</integer>
    <key>sse_reconnect_delay_ms</key>
    <integer>1000</integer>

    <!-- Version Control -->
    <key>min_supported_version</key>
    <string>1.0.0</string>

    <!-- Maintenance -->
    <key>maintenance_mode</key>
    <false/>
    <key>maintenance_message</key>
    <string></string>
</dict>
</plist>
```

---

## Code Implementation

### RemoteConfigManager

Create a dedicated manager:

```swift
import FirebaseRemoteConfig

@MainActor
class RemoteConfigManager: ObservableObject {
    static let shared = RemoteConfigManager()

    @Published var isConfigured = false
    @Published var lastFetchStatus: RemoteConfigFetchStatus?

    private var remoteConfig: RemoteConfig

    private init() {
        remoteConfig = RemoteConfig.remoteConfig()
        configure()
    }

    private func configure() {
        let settings = RemoteConfigSettings()

        #if DEBUG
        // No minimum fetch interval in debug
        settings.minimumFetchInterval = 0
        #else
        // 1 hour minimum in production
        settings.minimumFetchInterval = 3600
        #endif

        remoteConfig.configSettings = settings

        // Load defaults from plist
        remoteConfig.setDefaults(fromPlist: "RemoteConfigDefaults")

        isConfigured = true
    }

    // MARK: - Fetching

    func fetchAndActivate() async {
        do {
            let status = try await remoteConfig.fetchAndActivate()
            lastFetchStatus = remoteConfig.lastFetchStatus

            switch status {
            case .successFetchedFromRemote:
                Logger.shared.info("Remote Config: Fetched from remote")
            case .successUsingPreFetchedData:
                Logger.shared.info("Remote Config: Using cached data")
            case .error:
                Logger.shared.warning("Remote Config: Fetch error")
            @unknown default:
                break
            }
        } catch {
            Logger.shared.error("Remote Config fetch failed: \(error)")
        }
    }

    // MARK: - Feature Flags

    var isSSHEnabled: Bool {
        remoteConfig["feature_ssh_enabled"].boolValue
    }

    var isIdeasEnabled: Bool {
        remoteConfig["feature_ideas_enabled"].boolValue
    }

    var isBookmarksEnabled: Bool {
        remoteConfig["feature_bookmarks_enabled"].boolValue
    }

    // MARK: - Configuration Values

    var maxMessageHistory: Int {
        remoteConfig["max_message_history"].numberValue.intValue
    }

    var sessionTimeoutMinutes: Int {
        remoteConfig["session_timeout_minutes"].numberValue.intValue
    }

    var apiTimeoutSeconds: TimeInterval {
        TimeInterval(remoteConfig["api_timeout_seconds"].numberValue.intValue)
    }

    var sseReconnectDelay: TimeInterval {
        TimeInterval(remoteConfig["sse_reconnect_delay_ms"].numberValue.intValue) / 1000.0
    }

    // MARK: - Version Control

    var minSupportedVersion: String {
        remoteConfig["min_supported_version"].stringValue ?? "1.0.0"
    }

    var isVersionSupported: Bool {
        let current = AppVersion.version
        let minimum = minSupportedVersion
        return current.compare(minimum, options: .numeric) != .orderedAscending
    }

    // MARK: - Maintenance

    var isMaintenanceMode: Bool {
        remoteConfig["maintenance_mode"].boolValue
    }

    var maintenanceMessage: String {
        remoteConfig["maintenance_message"].stringValue ?? ""
    }

    // MARK: - Generic Access

    func value<T>(forKey key: String, default defaultValue: T) -> T {
        let configValue = remoteConfig[key]

        switch T.self {
        case is Bool.Type:
            return configValue.boolValue as! T
        case is Int.Type:
            return configValue.numberValue.intValue as! T
        case is Double.Type:
            return configValue.numberValue.doubleValue as! T
        case is String.Type:
            return (configValue.stringValue ?? "") as! T
        default:
            return defaultValue
        }
    }
}
```

### Integration with FirebaseManager

```swift
// In FirebaseManager.swift

private func configureRemoteConfig() {
    // RemoteConfigManager is self-initializing singleton
    // Trigger fetch on app launch
    Task {
        await RemoteConfigManager.shared.fetchAndActivate()
    }
}
```

---

## Using in Views

### Feature Flag Example

```swift
struct SidebarView: View {
    @ObservedObject var config = RemoteConfigManager.shared

    var body: some View {
        List {
            // Always show chat
            NavigationLink("Chat", destination: ChatView())

            // Conditionally show SSH
            if config.isSSHEnabled {
                NavigationLink("SSH Terminal", destination: SSHView())
            }

            // Conditionally show Ideas
            if config.isIdeasEnabled {
                NavigationLink("Ideas", destination: IdeasView())
            }
        }
    }
}
```

### Configuration Value Example

```swift
struct ChatView: View {
    let config = RemoteConfigManager.shared

    func loadHistory() {
        let maxMessages = config.maxMessageHistory
        messages = MessageStore.shared.load(limit: maxMessages)
    }
}
```

### Maintenance Mode

```swift
struct ContentView: View {
    @ObservedObject var config = RemoteConfigManager.shared

    var body: some View {
        if config.isMaintenanceMode {
            MaintenanceView(message: config.maintenanceMessage)
        } else if !config.isVersionSupported {
            UpdateRequiredView()
        } else {
            MainContentView()
        }
    }
}
```

---

## Real-Time Updates

### Enable Real-Time Updates

```swift
func enableRealTimeUpdates() {
    remoteConfig.addOnConfigUpdateListener { [weak self] update, error in
        guard error == nil else {
            Logger.shared.error("Config update error: \(error!)")
            return
        }

        Task { @MainActor in
            // Activate the new values
            try? await self?.remoteConfig.activate()

            // Notify observers
            NotificationCenter.default.post(
                name: .remoteConfigUpdated,
                object: nil
            )
        }
    }
}

extension Notification.Name {
    static let remoteConfigUpdated = Notification.Name("remoteConfigUpdated")
}
```

### React to Updates

```swift
struct SomeView: View {
    @State private var configVersion = 0

    var body: some View {
        content
            .id(configVersion) // Force refresh on update
            .onReceive(NotificationCenter.default.publisher(for: .remoteConfigUpdated)) { _ in
                configVersion += 1
            }
    }
}
```

---

## A/B Testing

### Create Experiment in Console

1. Firebase Console → Remote Config
2. Click parameter → **Add new condition**
3. Select **A/B test**
4. Define variants and goals

### Track Experiment

```swift
// Log when user sees experiment variant
func trackExperimentExposure(experiment: String, variant: String) {
    Analytics.logEvent("experiment_exposure", parameters: [
        "experiment_name": experiment,
        "variant": variant
    ])
}
```

---

## Best Practices

### Fetch Timing

```swift
// Good: Fetch early, use cached values
func application(_ application: UIApplication, didFinishLaunchingWithOptions...) {
    // Start fetch immediately
    Task {
        await RemoteConfigManager.shared.fetchAndActivate()
    }
    return true
}

// The app uses cached/default values until fetch completes
```

### Graceful Degradation

```swift
// Always have sensible defaults
var apiTimeout: TimeInterval {
    let value = remoteConfig["api_timeout_seconds"].numberValue.intValue
    // Ensure reasonable bounds
    return TimeInterval(max(5, min(value, 120)))
}
```

### Avoid Jarring Changes

```swift
// Don't change UI mid-session for critical features
@Published private(set) var cachedSSHEnabled: Bool = true

func fetchAndActivate() async {
    await remoteConfig.fetchAndActivate()

    // Only update non-critical values immediately
    // Cache critical values until next session
    if !isFirstFetch {
        // Keep cached value
    } else {
        cachedSSHEnabled = isSSHEnabled
        isFirstFetch = false
    }
}
```

---

## Troubleshooting

### Values Not Updating

1. **Check minimumFetchInterval**: Set to 0 for testing
2. **Verify publish**: Changes must be published in Console
3. **Force fetch**: Close app, wait interval, reopen
4. **Check activation**: `fetchAndActivate()` must be called

### Default Values Not Loading

1. Verify `RemoteConfigDefaults.plist` is in project
2. Check file is in Copy Bundle Resources
3. Verify plist format is correct

### Throttling

Firebase throttles excessive fetches:
- Standard: 5 fetches per 60 minutes
- Debug: Unlimited with `minimumFetchInterval = 0`

### Debugging Values

```swift
// Log all current values
func debugPrintAllValues() {
    let keys = remoteConfig.allKeys(from: .remote)
    for key in keys {
        let value = remoteConfig[key]
        print("\(key): \(value.stringValue ?? "nil")")
    }
}
```
