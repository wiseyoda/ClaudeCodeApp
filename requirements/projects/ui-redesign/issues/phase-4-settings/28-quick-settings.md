# Issue 28: Quick Settings Sheet

**Phase:** 4 (Settings & Configuration)
**Priority:** Medium
**Status:** Not Started
**Depends On:** Issue #17 (Liquid Glass), Issue #27 (Settings)

## Goal

Redesign the quick settings sheet as a compact, frequently-used settings panel with Liquid Glass styling.

## Scope
- In scope: TBD.
- Out of scope: TBD.

## Non-goals
- TBD.

## Dependencies
- Depends On: Issue #17 (Liquid Glass), Issue #27 (Settings).
- Add runtime or tooling dependencies here.

## Touch Set
- Files to create: TBD.
- Files to modify: TBD.

## Interface Definitions
- List new or changed models, protocols, and API payloads.

## Edge Cases
- TBD.

## Tests
- [ ] Unit tests updated or added.
- [ ] UI tests updated or added (if user flows change).
## Design

```
┌─────────────────────────────────────────────┐
│              Quick Settings                 │
├─────────────────────────────────────────────┤
│ MODEL                                       │
│ ┌─────────────────────────────────────────┐ │
│ │ ◉ Sonnet    ○ Opus    ○ Haiku          │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ THINKING                                    │
│ ┌─────────────────────────────────────────┐ │
│ │ ○ Normal  ◉ Think  ○ Hard  ○ Harder    │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ 🔓 Skip Permissions                 ○   │ │
│ ├─────────────────────────────────────────┤ │
│ │ 💭 Show Thinking                    ●   │ │
│ ├─────────────────────────────────────────┤ │
│ │ 📜 Auto-scroll                      ●   │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│         [ All Settings ]                    │
└─────────────────────────────────────────────┘
```

## Implementation

### QuickSettingsSheet

```swift
struct QuickSettingsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var settings: AppSettings

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Model picker
                ModelPickerSection(selection: $settings.defaultModel)

                // Thinking mode
                ThinkingModeSection(selection: $settings.thinkingMode)

                // Quick toggles
                QuickTogglesSection(settings: settings)

                Spacer()

                // Link to full settings
                Button {
                    dismiss()
                    // Navigate to full settings
                } label: {
                    Text("All Settings")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Quick Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(.glass)
    }
}
```

### ModelPickerSection

```swift
struct ModelPickerSection: View {
    @Binding var selection: ClaudeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Picker("Model", selection: $selection) {
                ForEach(ClaudeModel.allCases, id: \.self) { model in
                    Text(model.displayName).tag(model)
                }
            }
            .pickerStyle(.segmented)
        }
        .glassEffect()
    }
}
```

### ThinkingModeSection

```swift
struct ThinkingModeSection: View {
    @Binding var selection: ThinkingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Thinking")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ThinkingMode.allCases, id: \.self) { mode in
                        ThinkingModeChip(
                            mode: mode,
                            isSelected: selection == mode,
                            action: { selection = mode }
                        )
                    }
                }
            }
        }
    }
}

struct ThinkingModeChip: View {
    let mode: ThinkingMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.selection()
            action()
        }) {
            Text(mode.displayName)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.accentColor : Color.clear)
        .foregroundStyle(isSelected ? .white : .primary)
        .clipShape(Capsule())
        .glassEffect()
    }
}
```

### QuickTogglesSection

```swift
struct QuickTogglesSection: View {
    @Bindable var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            ToggleRow(
                title: "Skip Permissions",
                icon: "lock.open",
                isOn: $settings.skipPermissions,
                tint: .orange
            )

            Divider()

            ToggleRow(
                title: "Show Thinking",
                icon: "thought.bubble",
                isOn: $settings.showThinkingBlocks
            )

            Divider()

            ToggleRow(
                title: "Auto-scroll",
                icon: "arrow.down.to.line",
                isOn: $settings.autoScrollEnabled
            )
        }
        .glassEffect()
    }
}

struct ToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    var tint: Color = .accentColor

    var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: icon)
        }
        .tint(tint)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
```

## Files to Create

```
CodingBridge/Features/Settings/
├── QuickSettingsSheet.swift       # ~80 lines
├── ModelPickerSection.swift       # ~30 lines
├── ThinkingModeSection.swift      # ~60 lines
└── QuickTogglesSection.swift      # ~50 lines
```

## Files to Modify

| File | Changes |
|------|---------|
| Current `QuickSettingsSheet.swift` | Replace with new implementation |

## Acceptance Criteria

- [ ] Compact sheet with medium detent
- [ ] Segmented model picker
- [ ] Horizontal scrolling thinking modes
- [ ] Quick toggle rows
- [ ] Link to full settings
- [ ] Glass effect on sections
- [ ] Haptic feedback on selection
- [ ] Build passes

## Testing

```swift
struct QuickSettingsTests: XCTestCase {
    func testModelSelection() {
        let settings = AppSettings()
        settings.defaultModel = .sonnet

        XCTAssertEqual(settings.defaultModel, .sonnet)

        settings.defaultModel = .opus
        XCTAssertEqual(settings.defaultModel, .opus)
    }

    func testThinkingModeSelection() {
        let settings = AppSettings()

        settings.thinkingMode = .thinkHard
        XCTAssertEqual(settings.thinkingMode, .thinkHard)
    }
}
```
