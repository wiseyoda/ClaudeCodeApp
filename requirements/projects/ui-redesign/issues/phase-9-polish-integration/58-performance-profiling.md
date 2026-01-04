# Issue 58: Performance Profiling

**Phase:** 9 (Polish & Integration)
**Priority:** Medium
**Status:** Not Started
**Depends On:** 40 (Testing Strategy), 48 (Telemetry & Monitoring)
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Goal

Establish a continuous performance profiling strategy that catches regressions early, maintains smooth 60fps scrolling with 500+ messages, ensures fast app launch, and keeps memory stable during long sessions.

## Scope

- In scope:
  - Instruments template configurations
  - Performance benchmarks and thresholds
  - Regression detection strategy
  - Memory profiling approach
  - Scroll performance measurement
  - Launch time optimization
- Out of scope:
  - Third-party APM tools (covered in Issue #48)
  - Server-side performance monitoring
  - Automated CI performance tests (future work)

## Non-goals

- Real-time performance dashboards
- Performance analytics collection from users

## Dependencies

- Issue #40 (Testing Strategy) for XCTest performance infrastructure
- Issue #48 (Telemetry & Monitoring) for metrics collection

## Touch Set

- Files to create:
  - `CodingBridgeTests/PerformanceTests/`
  - `requirements/projects/ui-redesign/docs/workflows/performance-baselines.md`
- Files to modify:
  - `CodingBridge.xcodeproj` (Instruments templates)

---

## Performance Targets

### Critical Metrics

| Metric | Target | Red Line | Measurement |
|--------|--------|----------|-------------|
| Cold launch | < 1.5s | > 2.5s | Time to first frame |
| Warm launch | < 0.5s | > 1.0s | Time to interactive |
| Scroll FPS (500 msgs) | 60fps | < 50fps | Core Animation hitches |
| Memory (idle) | < 80MB | > 150MB | Allocations instrument |
| Memory (500 msgs) | < 200MB | > 400MB | Allocations instrument |
| Memory growth/hour | < 5MB | > 20MB | Leaks + Allocations |
| Message render | < 16ms | > 32ms | Time Profiler |
| WebSocket latency | < 50ms | > 200ms | Network instrument |

### Secondary Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Settings sheet open | < 100ms | Time Profiler |
| Session picker load | < 200ms | Time Profiler |
| File browser navigation | < 150ms | Time Profiler |
| Search results (1000 msgs) | < 500ms | Time Profiler |

---

## Instruments Templates

### 1. App Launch Template

Measures cold and warm launch times.

**Instruments:**
- Time Profiler
- App Launch
- Thermal State

**Workflow:**
1. Force quit app
2. Start recording
3. Launch app
4. Wait for first frame
5. Stop recording
6. Analyze `applicationDidFinishLaunching` to first render

**What to Look For:**
- Main thread blocking during launch
- Slow initializers
- Network calls before first render
- Large asset loading

### 2. Scroll Performance Template

Measures scroll smoothness with large message lists.

**Instruments:**
- Core Animation
- Time Profiler
- Allocations

**Workflow:**
1. Load session with 500+ messages
2. Start recording
3. Scroll continuously for 30 seconds
4. Stop recording
5. Analyze hitch rate and dropped frames

**What to Look For:**
- Commits > 16ms
- Off-screen rendering
- View allocation spikes
- Main thread work during scroll

### 3. Memory Template

Measures memory usage and leak detection.

**Instruments:**
- Allocations
- Leaks
- VM Tracker

**Workflow:**
1. Launch app
2. Start recording
3. Perform typical usage pattern (10 minutes)
4. Force memory warning
5. Continue for 5 minutes
6. Stop and analyze

**What to Look For:**
- Memory growth over time
- Retained objects after navigation
- Leaks (any leak is a bug)
- Zombie objects

### 4. Network Template

Measures WebSocket and HTTP performance.

**Instruments:**
- Network
- Time Profiler

**Workflow:**
1. Start recording
2. Send message and wait for response
3. Trigger reconnection
4. Load session history
5. Stop and analyze

**What to Look For:**
- Connection establishment time
- Message round-trip latency
- Reconnection overhead
- Payload sizes

---

## XCTest Performance Tests

### Launch Performance

```swift
class LaunchPerformanceTests: XCTestCase {
    func testColdLaunch() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    func testWarmLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        app.terminate()

        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)]) {
            app.launch()
        }
    }
}
```

### Scroll Performance

```swift
class ScrollPerformanceTests: XCTestCase {
    func testScrollWith500Messages() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--load-mock-session", "500-messages"]
        app.launch()

        let messageList = app.scrollViews["messageList"]

        let metrics: [XCTMetric] = [
            XCTOSSignpostMetric.scrollingAndDecelerationMetric,
            XCTOSSignpostMetric.scrollDraggingMetric
        ]

        measure(metrics: metrics) {
            messageList.swipeUp(velocity: .fast)
            messageList.swipeUp(velocity: .fast)
            messageList.swipeDown(velocity: .fast)
            messageList.swipeDown(velocity: .fast)
        }
    }
}
```

### Memory Performance

```swift
class MemoryPerformanceTests: XCTestCase {
    func testMemoryStability() throws {
        measure(metrics: [XCTMemoryMetric()]) {
            // Load large session
            let store = MessageStore()
            store.loadMessages(projectPath: "/test", count: 500)

            // Simulate usage
            for _ in 0..<10 {
                store.appendMessage(.mock())
            }

            // Clear
            store.clearMessages(projectPath: "/test")
        }
    }

    func testNoLeaksAfterNavigation() throws {
        measure(metrics: [XCTMemoryMetric()]) {
            let app = XCUIApplication()
            app.launch()

            // Navigate to chat
            app.buttons["project1"].tap()

            // Navigate back
            app.buttons["Back"].tap()

            // Repeat 10 times
            for _ in 0..<10 {
                app.buttons["project1"].tap()
                app.buttons["Back"].tap()
            }
        }
    }
}
```

### Baseline Configuration

```swift
class PerformanceBaselineTests: XCTestCase {
    override func measure(metrics: [XCTMetric], automaticallyStartMeasuring: Bool = true, for block: () -> Void) {
        // Configure baselines
        let options = XCTMeasureOptions()
        options.iterationCount = 5

        super.measure(metrics: metrics, options: options, block: block)
    }
}
```

---

## Profiling Workflow

### Weekly Profiling

| Day | Focus | Actions |
|-----|-------|---------|
| Monday | Launch | Profile cold/warm launch, compare to baseline |
| Wednesday | Scroll | Profile 500-message scroll, check hitch rate |
| Friday | Memory | Run 30-minute session, check for leaks/growth |

### Pre-Release Profiling

1. **Day 1: Full benchmark suite**
   - All Instruments templates
   - All XCTest performance tests
   - Compare to previous release

2. **Day 2: Regression analysis**
   - Identify any regressions
   - File issues for blockers
   - Document acceptable regressions

3. **Day 3: Optimization sprint**
   - Fix blocker regressions
   - Verify fixes with profiling
   - Update baselines if needed

---

## Optimization Patterns

### View Rendering

```swift
// ✅ Lazy rendering
LazyVStack {
    ForEach(messages) { message in
        MessageCard(message: message)
    }
}

// ❌ Eager rendering
VStack {
    ForEach(messages) { message in
        MessageCard(message: message)
    }
}
```

### Image Handling

```swift
// ✅ Sized images
Image(uiImage: image)
    .resizable()
    .frame(width: 100, height: 100)

// ❌ Full-size then scale
Image(uiImage: fullSizeImage)
    .resizable()
    .aspectRatio(contentMode: .fit)
```

### Expensive Computations

```swift
// ✅ Cached computation
@Observable
final class ViewModel {
    var messages: [Message] = []

    var displayMessages: [Message] {
        messages.filter { $0.shouldDisplay }
    }
}

// ❌ Computed in body
var body: some View {
    let filtered = messages.filter { $0.shouldDisplay } // Every render!
    ForEach(filtered) { ... }
}
```

### Memory Management

```swift
// ✅ Weak references in closures
Task { [weak self] in
    guard let self else { return }
    await self.process()
}

// ❌ Strong capture
Task {
    await self.process() // Retains self
}
```

---

## Regression Detection

### Automated Baselines

Store baselines in `PERFORMANCE-BASELINES.md`:

```markdown
# Performance Baselines

Last updated: 2026-01-03
Device: iPhone 17 Pro (iOS 26.2)
Build: 2.0.0 (202601031430)

## Launch

| Metric | Baseline | Tolerance |
|--------|----------|-----------|
| Cold launch | 1.2s | ±0.2s |
| Warm launch | 0.3s | ±0.1s |

## Scroll (500 messages)

| Metric | Baseline | Tolerance |
|--------|----------|-----------|
| Hitch rate | 0.5% | ±0.5% |
| Dropped frames | 2 | ±3 |

## Memory

| Metric | Baseline | Tolerance |
|--------|----------|-----------|
| Idle | 65MB | ±15MB |
| 500 messages | 150MB | ±30MB |
```

### CI Integration (Future)

```yaml
# .github/workflows/performance.yml (future)
name: Performance Tests
on:
  pull_request:
    branches: [main]

jobs:
  performance:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Performance Tests
        run: |
          xcodebuild test \
            -scheme CodingBridge \
            -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
            -only-testing:CodingBridgeTests/PerformanceTests

      - name: Compare to Baselines
        run: ./scripts/compare-baselines.sh
```

---

## Acceptance Criteria

- [ ] All Instruments templates configured
- [ ] XCTest performance tests implemented
- [ ] Performance baselines documented
- [ ] Weekly profiling workflow defined
- [ ] Pre-release profiling checklist complete
- [ ] Optimization patterns documented
- [ ] Cold launch < 1.5s verified
- [ ] 500-message scroll at 60fps verified
- [ ] Memory stable over 1-hour session verified

## Testing

- [ ] Run all Instruments templates successfully
- [ ] XCTest performance tests pass
- [ ] Baselines match targets
- [ ] No memory leaks detected
- [ ] No scroll hitches > 3 per minute
