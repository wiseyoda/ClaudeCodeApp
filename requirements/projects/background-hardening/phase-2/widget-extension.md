# Widget Extension Setup

> Creating the CodingBridgeWidgets extension for Live Activities.

## Prerequisites

Complete Apple Developer Portal setup BEFORE starting code:

1. Create App Group identifier: `group.com.codingbridge.shared`
2. Add Push Notifications capability to App ID
3. Enable Live Activities for App ID

## Create Extension Target

1. Xcode → File → New → Target
2. Select "Widget Extension"
3. Name: `CodingBridgeWidgets`
4. Include Live Activity: Yes
5. Include Configuration Intent: No

## File Structure

```
CodingBridgeWidgets/
├── CodingBridgeWidgets.swift        # Widget bundle entry point
├── CodingBridgeActivityAttributes.swift  # Shared with main app
└── Views/
    ├── LockScreenView.swift
    ├── StatusIcon.swift
    ├── ElapsedTimeView.swift
    └── ApprovalRequestView.swift
```

## Widget Bundle

```swift
// CodingBridgeWidgets/CodingBridgeWidgets.swift

import WidgetKit
import SwiftUI

@main
struct CodingBridgeWidgets: WidgetBundle {
    var body: some Widget {
        CodingBridgeLiveActivity()
    }
}
```

## Live Activity Widget

```swift
// CodingBridgeWidgets/CodingBridgeLiveActivity.swift

import ActivityKit
import WidgetKit
import SwiftUI

struct CodingBridgeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CodingBridgeActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    StatusIcon(status: context.state.status)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedTimeView(seconds: context.state.elapsedSeconds)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.projectName)
                        .font(.headline)
                        .lineLimit(1)
                }
            } compactLeading: {
                StatusIcon(status: context.state.status, compact: true)
            } compactTrailing: {
                ElapsedTimeView(seconds: context.state.elapsedSeconds, compact: true)
            } minimal: {
                StatusIcon(status: context.state.status, minimal: true)
            }
        }
    }
}
```

## App Group Setup

### Entitlements - Main App

```xml
<!-- CodingBridge.entitlements -->
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.codingbridge.shared</string>
</array>
```

### Entitlements - Widget Extension

```xml
<!-- CodingBridgeWidgetsExtension.entitlements -->
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.codingbridge.shared</string>
</array>
```

## Shared Container

```swift
// CodingBridge/Utilities/SharedContainer.swift

struct SharedContainer {
    static let groupIdentifier = "group.com.codingbridge.shared"

    static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier
        )
    }

    static func saveTaskState(_ state: TaskState) throws {
        guard let url = containerURL?.appendingPathComponent("taskState.json") else {
            throw SharedContainerError.urlNotFound
        }
        let data = try JSONEncoder().encode(state)
        try data.write(to: url)
    }

    static func loadTaskState() -> TaskState? {
        guard let url = containerURL?.appendingPathComponent("taskState.json"),
              let data = try? Data(contentsOf: url),
              data.count < 10_000 else {  // Guard against large files
            return nil
        }
        return try? JSONDecoder().decode(TaskState.self, from: data)
    }
}
```

## Memory Limits

Widget extensions have strict memory limits:

| Context | Limit |
|---------|-------|
| Widget extension | ~30 MB |
| Live Activity UI | ~16 MB |

### Best Practices

- Use SF Symbols instead of custom images
- Keep views lightweight
- No heavy computation in views
- Guard against large strings

```swift
// Guard against huge strings
if let operation = context.state.currentOperation,
   operation.count < 500 {
    Text(operation).lineLimit(2)
} else {
    Text("Processing...")
}
```

---
**Prev:** [live-activity-manager](./live-activity-manager.md) | **Next:** [ui-views](./ui-views.md) | **Index:** [../00-INDEX.md](../00-INDEX.md)
