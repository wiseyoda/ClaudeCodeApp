# Performance Monitoring Setup Guide

Complete guide for Firebase Performance Monitoring integration.

## Overview

Performance Monitoring automatically tracks:
- App startup time
- Screen rendering (frozen frames, slow frames)
- HTTP/S network requests
- Custom code traces

---

## Prerequisites

- [ ] Firebase SDK installed (includes FirebasePerformance)
- [ ] `GoogleService-Info.plist` configured

---

## Automatic Monitoring

Once Firebase Performance is added, these are tracked automatically:

### App Lifecycle
| Metric | Description |
|--------|-------------|
| `_app_start` | Time from launch to first frame |
| `_app_in_background` | Background session duration |
| `_app_in_foreground` | Foreground session duration |

### Screen Rendering
| Metric | Description |
|--------|-------------|
| Frozen frames | Frames taking >700ms to render |
| Slow frames | Frames taking >16ms to render |
| Frame rate | Average FPS |

### Network Requests
All HTTP/S requests are automatically traced including:
- Request URL (path only, no query params)
- Response time
- Payload size
- Success/failure status

---

## Code Implementation

### Basic Configuration

```swift
import FirebasePerformance

// In FirebaseManager.swift
private func configurePerformance() {
    // Enable automatic data collection
    Performance.sharedInstance().isDataCollectionEnabled = true

    // Optionally disable in debug
    #if DEBUG
    Performance.sharedInstance().isInstrumentationEnabled = false
    #endif

    Logger.shared.info("Performance Monitoring configured")
}
```

### PerformanceTracker Helper

```swift
import FirebasePerformance

class PerformanceTracker {
    static let shared = PerformanceTracker()

    private init() {}

    // MARK: - Custom Traces

    /// Start a trace for a code section
    func startTrace(name: String) -> Trace? {
        let trace = Performance.startTrace(name: name)
        trace?.start()
        return trace
    }

    /// Stop a trace and optionally add metrics
    func stopTrace(_ trace: Trace?, metrics: [String: Int64]? = nil) {
        if let metrics = metrics {
            for (key, value) in metrics {
                trace?.setValue(value, forMetric: key)
            }
        }
        trace?.stop()
    }

    // MARK: - Convenience Methods

    /// Measure async operation
    func measure<T>(name: String, operation: () async throws -> T) async rethrows -> T {
        let trace = startTrace(name: name)
        defer { trace?.stop() }
        return try await operation()
    }

    /// Measure sync operation
    func measureSync<T>(name: String, operation: () throws -> T) rethrows -> T {
        let trace = startTrace(name: name)
        defer { trace?.stop() }
        return try operation()
    }
}
```

---

## Custom Traces

### API Request Tracing

```swift
// Trace API calls
func fetchMessages(sessionId: String) async throws -> [Message] {
    let trace = PerformanceTracker.shared.startTrace(name: "fetch_messages")
    trace?.setValue(sessionId, forAttribute: "session_id")

    do {
        let messages = try await apiClient.getMessages(sessionId: sessionId)

        trace?.setValue(Int64(messages.count), forMetric: "message_count")
        trace?.stop()

        return messages
    } catch {
        trace?.setValue(error.localizedDescription, forAttribute: "error")
        trace?.stop()
        throw error
    }
}
```

### SSH Operation Tracing

```swift
// Trace SSH commands
func executeSSHCommand(_ command: String) async throws -> String {
    let trace = PerformanceTracker.shared.startTrace(name: "ssh_command")
    trace?.setValue(categorizeCommand(command), forAttribute: "command_type")

    do {
        let result = try await sshManager.execute(command)

        trace?.setValue(Int64(result.count), forMetric: "output_bytes")
        trace?.stop()

        return result
    } catch {
        trace?.setValue("error", forAttribute: "status")
        trace?.stop()
        throw error
    }
}
```

### Session Loading Trace

```swift
// Trace session loading
func loadSession(_ sessionId: String) async {
    let trace = PerformanceTracker.shared.startTrace(name: "load_session")

    // Track substeps
    let historyTrace = PerformanceTracker.shared.startTrace(name: "load_session_history")
    let history = await loadHistory(sessionId)
    historyTrace?.setValue(Int64(history.count), forMetric: "message_count")
    historyTrace?.stop()

    let metadataTrace = PerformanceTracker.shared.startTrace(name: "load_session_metadata")
    let metadata = await loadMetadata(sessionId)
    metadataTrace?.stop()

    trace?.stop()
}
```

---

## Network Monitoring

### Automatic Monitoring

All URLSession requests are automatically monitored.

### Custom URL Patterns

Optionally configure URL grouping:

```swift
// Group similar URLs together
// /api/sessions/abc123 → /api/sessions/*
// This is done automatically by Firebase
```

### Disable for Specific URLs

```swift
// URLs containing these patterns won't be traced
// Configure in Firebase Console → Performance → Network
```

---

## Screen Traces

### Automatic Screen Traces

Firebase automatically traces screen rendering performance.

### Custom Screen Traces

```swift
struct ChatView: View {
    @State private var screenTrace: Trace?

    var body: some View {
        content
            .onAppear {
                screenTrace = PerformanceTracker.shared.startTrace(name: "screen_chat")
            }
            .onDisappear {
                screenTrace?.stop()
            }
    }
}
```

---

## Metrics and Attributes

### Custom Metrics

Numeric values that can be aggregated:

```swift
// Increment a counter
trace?.incrementMetric("retry_count", by: 1)

// Set a value
trace?.setValue(Int64(messageCount), forMetric: "messages_loaded")
```

### Custom Attributes

String values for filtering:

```swift
// Set attributes
trace?.setValue("production", forAttribute: "environment")
trace?.setValue("v1.0.0", forAttribute: "app_version")
trace?.setValue("wifi", forAttribute: "network_type")
```

### Limits

| Limit | Value |
|-------|-------|
| Trace name length | 100 characters |
| Attributes per trace | 5 |
| Attribute name length | 40 characters |
| Attribute value length | 100 characters |
| Metrics per trace | 32 |
| Concurrent traces | 100 |

---

## Integration Examples

### View Lifecycle

```swift
struct SessionListView: View {
    @State private var loadTrace: Trace?

    var body: some View {
        List(sessions) { session in
            SessionRow(session: session)
        }
        .task {
            loadTrace = PerformanceTracker.shared.startTrace(name: "load_session_list")
            await loadSessions()
            loadTrace?.setValue(Int64(sessions.count), forMetric: "session_count")
            loadTrace?.stop()
        }
    }
}
```

### Network Client

```swift
class CLIBridgeAPIClient {
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod
    ) async throws -> T {
        let trace = PerformanceTracker.shared.startTrace(name: "api_\(endpoint)")
        trace?.setValue(method.rawValue, forAttribute: "method")

        do {
            let result: T = try await performRequest(endpoint: endpoint, method: method)
            trace?.setValue("success", forAttribute: "status")
            trace?.stop()
            return result
        } catch {
            trace?.setValue("error", forAttribute: "status")
            trace?.setValue(String(describing: type(of: error)), forAttribute: "error_type")
            trace?.stop()
            throw error
        }
    }
}
```

### Background Task

```swift
class BackgroundManager {
    func performBackgroundRefresh() async {
        let trace = PerformanceTracker.shared.startTrace(name: "background_refresh")

        let startTime = Date()
        await refreshSessions()
        let duration = Date().timeIntervalSince(startTime)

        trace?.setValue(Int64(duration * 1000), forMetric: "duration_ms")
        trace?.stop()
    }
}
```

---

## Dashboard

### Viewing Data

1. Firebase Console → Performance
2. Wait up to 12 hours for initial data
3. Data updates within minutes after initial collection

### Key Metrics

- **App Start**: Cold start, warm start times
- **Screen Rendering**: Frozen/slow frame percentages
- **Network**: Response times, success rates
- **Custom Traces**: Your defined traces

### Filtering

Filter by:
- App version
- Device type
- OS version
- Country
- Custom attributes

---

## Disabling in Development

```swift
#if DEBUG
// Disable automatic instrumentation
Performance.sharedInstance().isInstrumentationEnabled = false

// Or disable data collection entirely
Performance.sharedInstance().isDataCollectionEnabled = false
#endif
```

Or via Info.plist:
```xml
<key>firebase_performance_collection_enabled</key>
<false/>
```

---

## Troubleshooting

### Data Not Appearing

1. **Wait time**: Up to 12 hours for first data
2. **Check collection**: Verify `isDataCollectionEnabled = true`
3. **Check instrumentation**: Verify `isInstrumentationEnabled = true`
4. **Network**: Ensure device has internet

### Traces Not Showing

1. Verify trace is started and stopped
2. Check trace name is valid (≤100 chars)
3. Ensure not exceeding 100 concurrent traces

### High Frozen Frame Rate

1. Check main thread for heavy operations
2. Move work to background threads
3. Optimize image loading
4. Reduce view complexity

---

## Best Practices

1. **Trace meaningful operations**: Focus on user-impacting flows
2. **Use descriptive names**: `load_messages` not `operation_1`
3. **Add context with attributes**: Environment, version, user type
4. **Track success/failure**: Add status attributes
5. **Don't over-trace**: Too many traces impact performance
6. **Disable in debug**: Avoid polluting data with dev builds
7. **Set baselines**: Monitor for regressions
8. **Alert on anomalies**: Set up performance alerts
