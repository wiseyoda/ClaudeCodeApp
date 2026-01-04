---
number: 45
title: Feature Flags
phase: phase-0-foundation
priority: High
depends_on: null
acceptance_criteria: 7
files_to_touch: 3
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 45: Feature Flags

**Phase:** 0 (Foundation)
**Priority:** High
**Status:** Not Started
**Depends On:** None
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Required Documentation

Before starting work on this issue, review these architecture and design documents:

### Core Architecture
- **[State Management](../../docs/architecture/ui/07-state-management.md)** - AppState for feature flag storage
- **[System Overview](../../docs/architecture/data/01-system-overview.md)** - Architecture context

### Foundation
- **[Design Decisions](../../docs/overview/design-decisions.md)** - Feature decisions that may need flags

### Workflows
- **[Execution Guardrails](../../docs/workflows/guardrails.md)** - Development rules and constraints

## Goal

Implement a feature flag system that enables incremental rollout of iOS 26 redesign features, A/B testing capabilities, and safe deployment with instant rollback.

## Scope

- In scope:
  - Local feature flag registry
  - Debug menu for flag overrides
  - Per-flag metadata (owner, phase, removal date)
  - Flag gating utilities
  - Build configuration integration
  - Firebase-ready provider abstraction (no SDK integration yet)
- Out of scope:
  - Remote configuration service (Firebase, LaunchDarkly)
  - Server-driven flag updates
  - Analytics integration (Issue #48)

## Non-goals

- Real-time flag synchronization
- User segmentation / percentage rollouts
- Experimentation framework

## Dependencies

- None (foundational issue)

## Touch Set

- Files to create:
  - `CodingBridge/Core/FeatureFlags.swift`
  - `CodingBridge/Views/Debug/FeatureFlagsDebugView.swift`
- Files to modify:
  - `CodingBridge/Views/Debug/DiagnosticsView.swift` (add flags section)
  - `Config/Version.xcconfig` (add build flags)

---

## Feature Flag Registry

### FeatureFlags Enum

```swift
/// Feature flags for incremental iOS 26 redesign rollout.
///
/// Each flag gates a feature that can be toggled without code changes.
/// Use ``isEnabled(_:)`` to check flag state in production code.
enum FeatureFlag: String, CaseIterable, Identifiable, Sendable {
    // MARK: - Phase 0: Foundation
    case liquidGlassDesign = "liquid_glass_design"
    case observableMigration = "observable_migration"

    // MARK: - Phase 1: Navigation
    case navigationSplitView = "navigation_split_view"
    case sidebarRedesign = "sidebar_redesign"
    case iPadLayouts = "ipad_layouts"

    // MARK: - Phase 2: Core Views
    case chatViewRedesign = "chat_view_redesign"
    case messageCardSystem = "message_card_system"
    case virtualizedScroll = "virtualized_scroll"

    // MARK: - Phase 3: Interactions
    case streamInteractions = "stream_interactions"
    case cardStatusBanners = "card_status_banners"
    case subagentBreadcrumbs = "subagent_breadcrumbs"

    // MARK: - Phase 4: Settings
    case settingsRedesign = "settings_redesign"
    case quickSettings = "quick_settings"

    // MARK: - Phase 5: Secondary Views
    case terminalRedesign = "terminal_redesign"
    case fileBrowserRedesign = "file_browser_redesign"
    case sessionPickerRedesign = "session_picker_redesign"
    case exportShare = "export_share"

    // MARK: - Phase 6: Sheets
    case sheetSystem = "sheet_system"
    case commandPicker = "command_picker"
    case ideasDrawer = "ideas_drawer"

    // MARK: - Phase 7: Advanced
    case messageRetry = "message_retry"
    case smartToolGrouping = "smart_tool_grouping"
    case offlineMode = "offline_mode"
    case voiceInput = "voice_input"

    // MARK: - Phase 8: Platform
    case interactiveWidgets = "interactive_widgets"
    case controlCenter = "control_center"
    case liveActivities = "live_activities"
    case appIntents = "app_intents"
    case appShortcuts = "app_shortcuts"
    case iCloudSync = "icloud_sync"
    case richNotifications = "rich_notifications"
    case shareExtension = "share_extension"

    var id: String { rawValue }
}
```

### Flag Metadata

```swift
/// Metadata for a feature flag.
struct FeatureFlagInfo: Sendable {
    let flag: FeatureFlag
    let displayName: String
    let description: String
    let phase: Int
    let owner: String
    let defaultEnabled: Bool
    let removalTarget: String?  // Version when flag should be removed

    static let registry: [FeatureFlag: FeatureFlagInfo] = [
        .liquidGlassDesign: FeatureFlagInfo(
            flag: .liquidGlassDesign,
            displayName: "Liquid Glass Design",
            description: "Enable iOS 26 Liquid Glass visual style",
            phase: 0,
            owner: "design",
            defaultEnabled: false,
            removalTarget: "3.0"
        ),
        .navigationSplitView: FeatureFlagInfo(
            flag: .navigationSplitView,
            displayName: "Navigation Split View",
            description: "Use NavigationSplitView for iPad layout",
            phase: 1,
            owner: "navigation",
            defaultEnabled: false,
            removalTarget: "3.0"
        ),
        .chatViewRedesign: FeatureFlagInfo(
            flag: .chatViewRedesign,
            displayName: "Chat View Redesign",
            description: "Enable redesigned chat view with card system",
            phase: 2,
            owner: "chat",
            defaultEnabled: false,
            removalTarget: "3.0"
        ),
        // ... remaining flags
    ]
}
```

### FeatureFlagManager

```swift
/// Manages feature flag state and overrides.
@MainActor @Observable
final class FeatureFlagManager {
    static let shared = FeatureFlagManager()

    @ObservationIgnored
    private let defaults = UserDefaults.standard

    @ObservationIgnored
    private let overrideKeyPrefix = "ff_override_"

    private(set) var overrides: [FeatureFlag: Bool] = [:]

    private init() {
        loadOverrides()
    }

    /// Check if a feature flag is enabled.
    ///
    /// Resolution order:
    /// 1. Debug override (if set)
    /// 2. Build configuration (DEBUG vs RELEASE)
    /// 3. Flag default value
    func isEnabled(_ flag: FeatureFlag) -> Bool {
        // Debug override takes precedence
        if let override = overrides[flag] {
            return override
        }

        // Build configuration
        #if DEBUG
        return debugDefault(for: flag)
        #else
        return releaseDefault(for: flag)
        #endif
    }

    /// Set a debug override for a flag.
    func setOverride(_ flag: FeatureFlag, enabled: Bool?) {
        if let enabled {
            overrides[flag] = enabled
            defaults.set(enabled, forKey: overrideKeyPrefix + flag.rawValue)
        } else {
            overrides.removeValue(forKey: flag)
            defaults.removeObject(forKey: overrideKeyPrefix + flag.rawValue)
        }
    }

    /// Clear all debug overrides.
    func clearAllOverrides() {
        for flag in FeatureFlag.allCases {
            defaults.removeObject(forKey: overrideKeyPrefix + flag.rawValue)
        }
        overrides.removeAll()
    }

    private func loadOverrides() {
        for flag in FeatureFlag.allCases {
            let key = overrideKeyPrefix + flag.rawValue
            if defaults.object(forKey: key) != nil {
                overrides[flag] = defaults.bool(forKey: key)
            }
        }
    }

    private func debugDefault(for flag: FeatureFlag) -> Bool {
        // In debug builds, enable flags for phases 0-2 by default
        guard let info = FeatureFlagInfo.registry[flag] else { return false }
        return info.phase <= 2
    }

    private func releaseDefault(for flag: FeatureFlag) -> Bool {
        // In release builds, use explicit default
        guard let info = FeatureFlagInfo.registry[flag] else { return false }
        return info.defaultEnabled
    }
}
```

---

### FeatureFlagProvider (Firebase-ready)

```swift
/// Provider abstraction for future remote config (Firebase after redesign).
protocol FeatureFlagProvider: Sendable {
    func loadFlags() async throws -> [FeatureFlag: Bool]
    func refresh() async
}

/// Local-only provider used in redesign (no remote config).
struct LocalFeatureFlagProvider: FeatureFlagProvider {
    func loadFlags() async throws -> [FeatureFlag: Bool] { [:] }
    func refresh() async { }
}
```

---

## Usage Patterns

### Basic Gating

```swift
// In a View
struct ChatView: View {
    @State private var flagManager = FeatureFlagManager.shared

    var body: some View {
        if flagManager.isEnabled(.chatViewRedesign) {
            NewChatView()
        } else {
            LegacyChatView()
        }
    }
}
```

### Computed Property

```swift
struct MessageCard: View {
    private var useLiquidGlass: Bool {
        FeatureFlagManager.shared.isEnabled(.liquidGlassDesign)
    }

    var body: some View {
        content
            .if(useLiquidGlass) { view in
                view.glassEffect()
            }
    }
}
```

### View Modifier

```swift
extension View {
    @ViewBuilder
    func featureGated(_ flag: FeatureFlag) -> some View {
        if FeatureFlagManager.shared.isEnabled(flag) {
            self
        }
    }

    @ViewBuilder
    func withFeature<Content: View>(
        _ flag: FeatureFlag,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if FeatureFlagManager.shared.isEnabled(flag) {
            content()
        } else {
            self
        }
    }
}

// Usage
Button("Export")
    .featureGated(.exportShare)

oldImplementation
    .withFeature(.chatViewRedesign) {
        newImplementation
    }
```

---

## Debug Interface

### FeatureFlagsDebugView

```swift
struct FeatureFlagsDebugView: View {
    @State private var flagManager = FeatureFlagManager.shared
    @State private var searchText = ""
    @State private var selectedPhase: Int?

    private var filteredFlags: [FeatureFlag] {
        FeatureFlag.allCases.filter { flag in
            let matchesSearch = searchText.isEmpty ||
                flag.rawValue.localizedCaseInsensitiveContains(searchText)
            let matchesPhase = selectedPhase == nil ||
                FeatureFlagInfo.registry[flag]?.phase == selectedPhase
            return matchesSearch && matchesPhase
        }
    }

    var body: some View {
        List {
            Section {
                Button("Reset All Overrides", role: .destructive) {
                    flagManager.clearAllOverrides()
                }
            }

            Section("Phase Filter") {
                Picker("Phase", selection: $selectedPhase) {
                    Text("All").tag(nil as Int?)
                    ForEach(0..<10, id: \.self) { phase in
                        Text("Phase \(phase)").tag(phase as Int?)
                    }
                }
                .pickerStyle(.segmented)
            }

            ForEach(filteredFlags) { flag in
                FlagRow(flag: flag, manager: flagManager)
            }
        }
        .searchable(text: $searchText)
        .navigationTitle("Feature Flags")
    }
}

struct FlagRow: View {
    let flag: FeatureFlag
    let manager: FeatureFlagManager

    private var info: FeatureFlagInfo? {
        FeatureFlagInfo.registry[flag]
    }

    private var isOverridden: Bool {
        manager.overrides[flag] != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(info?.displayName ?? flag.rawValue)
                    .font(.headline)

                if isOverridden {
                    Text("Override")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { manager.isEnabled(flag) },
                    set: { manager.setOverride(flag, enabled: $0) }
                ))
            }

            if let description = info?.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if let phase = info?.phase {
                    Label("Phase \(phase)", systemImage: "number")
                }
                if let owner = info?.owner {
                    Label(owner, systemImage: "person")
                }
                if let removal = info?.removalTarget {
                    Label("Remove in v\(removal)", systemImage: "trash")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contextMenu {
            if isOverridden {
                Button("Clear Override") {
                    manager.setOverride(flag, enabled: nil)
                }
            }
        }
    }
}
```

---

## Build Configuration

### xcconfig Flags

```xcconfig
// Config/FeatureFlags.xcconfig

// Enable all Phase 0-1 features for internal builds
PHASE_0_FEATURES = 1
PHASE_1_FEATURES = 1

// Disable experimental features in release
#if RELEASE
PHASE_2_FEATURES = 0
PHASE_3_FEATURES = 0
#else
PHASE_2_FEATURES = 1
PHASE_3_FEATURES = 1
#endif

SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) PHASE_0_FEATURES=$(PHASE_0_FEATURES) PHASE_1_FEATURES=$(PHASE_1_FEATURES)
```

### Compile-Time Gating

```swift
// For completely removing code paths
#if PHASE_2_FEATURES
struct NewChatView: View {
    // Implementation
}
#endif
```

---

## Flag Lifecycle

### Adding a New Flag

1. Add case to `FeatureFlag` enum with appropriate phase marker
2. Add metadata to `FeatureFlagInfo.registry`
3. Document the flag in issue spec
4. Implement gating logic in code
5. Test both enabled and disabled states

### Graduating a Flag

1. Ensure flag has been enabled in production for 2+ releases
2. Remove gating logic, keeping new implementation
3. Remove legacy code path
4. Remove flag from enum and registry
5. Update removal target in CHANGELOG

### Flag Removal Checklist

- [ ] All users on new code path for 2+ versions
- [ ] No reported issues with new implementation
- [ ] Legacy code fully removed
- [ ] Tests updated to only test new path
- [ ] Flag removed from enum
- [ ] CHANGELOG updated

---

## Edge Cases

- **Flag checked before manager initialized**: Use defaults, log warning
- **Unknown flag from persisted storage**: Ignore, clean up on load
- **Conflicting flags**: Document dependencies, validate at startup
- **Flag state during animation**: Cache value for duration

## Acceptance Criteria

- [ ] FeatureFlag enum with all phases
- [ ] FeatureFlagInfo metadata for each flag
- [ ] FeatureFlagManager with override support
- [ ] Debug view for flag inspection/override
- [ ] View modifier utilities for gating
- [ ] Build configuration integration
- [ ] Flag lifecycle documentation

## Testing

```swift
class FeatureFlagTests: XCTestCase {
    func testDefaultState() {
        let manager = FeatureFlagManager()
        // Phase 0 enabled by default in debug
        XCTAssertTrue(manager.isEnabled(.liquidGlassDesign))
    }

    func testOverride() {
        let manager = FeatureFlagManager()
        manager.setOverride(.liquidGlassDesign, enabled: false)
        XCTAssertFalse(manager.isEnabled(.liquidGlassDesign))

        manager.setOverride(.liquidGlassDesign, enabled: nil)
        XCTAssertTrue(manager.isEnabled(.liquidGlassDesign))
    }

    func testClearAllOverrides() {
        let manager = FeatureFlagManager()
        manager.setOverride(.liquidGlassDesign, enabled: false)
        manager.setOverride(.navigationSplitView, enabled: true)

        manager.clearAllOverrides()

        XCTAssertTrue(manager.overrides.isEmpty)
    }
}
```
