# Issue 59: Dependency Graph

**Phase:** 0 (Foundation)
**Priority:** Medium
**Status:** Not Started
**Depends On:** None
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Goal

Provide a comprehensive Mermaid dependency graph that visualizes issue dependencies for the UI redesign project. This enables understanding of critical paths, parallel work opportunities, and phase boundaries.

## Scope

- In scope:
  - Mermaid flowchart of all 73 issues
  - Dependency edges showing blocking relationships
  - Phase groupings
  - Critical path identification
- Out of scope:
  - Automated dependency validation
  - Integration with project management tools
  - Dynamic graph generation

## Non-goals

- Real-time synchronization with issue status
- Effort estimates (no time-based planning)

## Dependencies

- None (foundational issue)

## Touch Set

- Files to create:
  - `requirements/projects/ui-redesign/docs/overview/dependency-graph.md`
- Files to modify:
  - `requirements/projects/ui-redesign/README.md` (add link)

## Dependency Graph

### Phase 0: Foundation

```mermaid
flowchart TD
    subgraph Phase0["Phase 0: Foundation"]
        I00[00: Data Normalization]
        I01[01: Design Tokens]
        I10[10: @Observable Migration]
        I17[17: Liquid Glass]
        I40[40: Testing Strategy]
        I44[44: Debug Tooling]
        I45[45: Feature Flags]
        I46[46: Localization]
        I59[59: Dependency Graph]
        I60[60: Code Review Checklist]
        I61[61: Swift Style + DocC]
        I62[62: Migration Helpers]
        I63[63: Error Types]
    end

    I10 --> I62
    I00 --> I10
```

### Phase 1: Navigation & Layout

```mermaid
flowchart TD
    subgraph Phase0["Phase 0"]
        I00[00: Data Normalization]
        I10[10: @Observable Migration]
        I17[17: Liquid Glass]
    end

    subgraph Phase1["Phase 1: Navigation"]
        I23[23: Navigation Architecture]
        I24[24: Sidebar & Project List]
        I25[25: iPad Layouts]
    end

    I10 --> I23
    I17 --> I23
    I23 --> I24
    I23 --> I25
```

### Phase 2: Core Views

```mermaid
flowchart TD
    subgraph Phase1["Phase 1"]
        I23[23: Navigation Architecture]
        I17[17: Liquid Glass]
    end

    subgraph Phase2["Phase 2: Core Views"]
        I03[03: Message Protocol & Router]
        I04[04: ChatCardView]
        I05[05: ToolCardView]
        I06[06: SystemCardView]
        I11[11: Virtualized Scroll]
        I26[26: Chat View Redesign]
        I64[64: Rich Text Editing]
    end

    I23 --> I26
    I17 --> I26
    I26 --> I03
    I03 --> I04
    I03 --> I05
    I03 --> I06
    I26 --> I11
    I26 --> I64
```

### Phase 3: Interactions & Status

```mermaid
flowchart TD
    subgraph Phase2["Phase 2"]
        I03[03: Message Protocol & Router]
        I26[26: Chat View Redesign]
    end

    subgraph Phase3["Phase 3: Interactions"]
        I02[02: Reusable Components]
        I08[08: Stream Interaction Handler]
        I09[09: Card Status Banners]
        I14[14: Subagent Breadcrumbs]
        I52[52: Error Recovery UI]
        I70[70: Status Messages]
    end

    I03 --> I08
    I26 --> I08
    I08 --> I09
    I08 --> I14
    I08 --> I52
    I17 --> I02
    I17 --> I70
    I26 --> I70
    I27 --> I70
```

### Phase 4-6: Settings, Secondary Views, Sheets

```mermaid
flowchart TD
    subgraph Phase3["Phase 3"]
        I08[08: Stream Interaction Handler]
    end

    subgraph Phase4["Phase 4: Settings"]
        I27[27: Settings Redesign]
        I28[28: Quick Settings]
        I29[29: Project Settings]
    end

    subgraph Phase5["Phase 5: Secondary Views"]
        I30[30: Terminal Redesign]
        I31[31: File Browser Redesign]
        I32[32: Session Picker Redesign]
        I33[33: Global Search Redesign]
        I57[57: Export & Share]
    end

    subgraph Phase6["Phase 6: Sheets"]
        I34[34: Sheet System]
        I35[35: Command Picker]
        I36[36: Ideas Drawer]
        I37[37: Help & Onboarding]
        I71[71: Todo Progress Drawer]
    end

    I17 --> I27
    I08 --> I27
    I27 --> I28
    I27 --> I29

    I26 --> I30
    I26 --> I31
    I26 --> I32
    I32 --> I57
    I26 --> I33

    I34 --> I35
    I34 --> I36
    I34 --> I37
    I05 --> I71
    I34 --> I71
```

### Phase 7: Advanced Features

```mermaid
flowchart TD
    subgraph Phase5["Phase 5"]
        I32[32: Session Picker Redesign]
    end

    subgraph Phase7["Phase 7: Advanced"]
        I12[12: Message Retry]
        I13[13: Smart Tool Grouping]
        I16[16: Swipe Actions]
        I53[53: Offline Mode]
        I69[69: Voice Input]
    end

    I08 --> I12
    I05 --> I13
    I26 --> I16
    I32 --> I53
    I26 --> I69
```

### Phase 8: iOS 26 Platform

```mermaid
flowchart TD
    subgraph Phase7["Phase 7"]
        I53[53: Offline Mode]
    end

    subgraph Phase8["Phase 8: Platform"]
        I15[15: iOS 26 Features]
        I18[18: Interactive Widgets]
        I19[19: Control Center]
        I20[20: Live Activities]
        I21[21: App Intents & Siri]
        I22[22: Keyboard Shortcuts]
        I42[42: Spotlight Integration]
        I43[43: Handoff & Universal Links]
        I54[54: Push Notifications]
        I55[55: App Shortcuts]
        I56[56: iCloud Sync]
        I66[66: State Restoration]
        I67[67: Rich Notifications]
        I68[68: Share Extension]
        I72[72: Background Continuity]
    end

    I21 --> I55
    I29 --> I56
    I23 --> I66
    I43 --> I66
    I54 --> I67
    I57 --> I68
    I20 --> I54
    I26 --> I72
    I66 --> I72
```

### Phase 9: Polish & Integration

```mermaid
flowchart TD
    subgraph Phase8["Phase 8"]
        I54[54: Push Notifications]
        I21[21: App Intents]
    end

    subgraph Phase9["Phase 9: Polish"]
        I07[07: Integration & Cleanup]
        I38[38: Accessibility]
        I39[39: Animations & Transitions]
        I41[41: Pointer & Trackpad]
        I47[47: Crash Reporting]
        I48[48: Telemetry & Monitoring]
        I49[49: Privacy Manifest]
        I50[50: Release & Beta Pipeline]
        I51[51: App Store Assets]
        I58[58: Performance Profiling]
        I65[65: DeclaredAgeRange]
    end

    I44 --> I50
    I45 --> I50
    I40 --> I58
    I48 --> I58
    I49 --> I65
```

### Complete Dependency Graph

```mermaid
flowchart TD
    %% Phase 0 - Foundation
    subgraph P0["Phase 0: Foundation"]
        I00[00: Data Norm]
        I01[01: Tokens]
        I10[10: Observable]
        I17[17: Glass]
        I40[40: Testing]
        I44[44: Debug]
        I45[45: Flags]
        I46[46: L10n]
        I59[59: DepGraph]
        I60[60: Review]
        I61[61: Style]
        I62[62: Migrate]
        I63[63: Errors]
    end

    %% Phase 1 - Navigation
    subgraph P1["Phase 1: Navigation"]
        I23[23: NavArch]
        I24[24: Sidebar]
        I25[25: iPad]
    end

    %% Phase 2 - Core Views
    subgraph P2["Phase 2: Core Views"]
        I03[03: Router]
        I04[04: ChatCard]
        I05[05: ToolCard]
        I06[06: SysCard]
        I11[11: VirtScroll]
        I26[26: ChatView]
        I64[64: RichText]
    end

    %% Phase 3 - Interactions
    subgraph P3["Phase 3: Interactions"]
        I02[02: Components]
        I08[08: Interact]
        I09[09: Banners]
        I14[14: Breadcrumbs]
        I52[52: ErrorUI]
        I70[70: StatusMsg]
    end

    %% Dependencies
    I00 --> I10
    I10 --> I62
    I10 --> I23
    I17 --> I23
    I23 --> I24
    I23 --> I25
    I23 --> I26
    I17 --> I26
    I26 --> I03
    I03 --> I04
    I03 --> I05
    I03 --> I06
    I26 --> I11
    I26 --> I64
    I03 --> I08
    I26 --> I08
    I08 --> I09
    I08 --> I14
    I08 --> I52
    I17 --> I70
    I26 --> I70

    %% Styling
    classDef foundation fill:#e1f5fe
    classDef navigation fill:#f3e5f5
    classDef core fill:#e8f5e9
    classDef interact fill:#fff3e0
    class I00,I01,I10,I17,I40,I44,I45,I46,I59,I60,I61,I62,I63 foundation
    class I23,I24,I25 navigation
    class I03,I04,I05,I06,I11,I26,I64 core
    class I02,I08,I09,I14,I52,I70 interact
```

## Critical Path

The critical path determines the minimum time to complete the project:

```
00 → 10 → 23 → 26 → 03 → 08 → [Phase 4+]
```

| Step | Issue | Description |
|------|-------|-------------|
| 1 | #00 | Data Normalization (enables consistent message handling) |
| 2 | #10 | @Observable Migration (enables all new state management) |
| 3 | #23 | Navigation Architecture (enables new layout) |
| 4 | #26 | Chat View Redesign (main user-facing view) |
| 5 | #03 | Message Protocol & Router (enables new cards) |
| 6 | #08 | Stream Interaction Handler (enables interactions) |

### Parallel Work Opportunities

These issues can be worked on in parallel once their dependencies are met:

| Parallel Track | Issues | Prerequisites |
|----------------|--------|---------------|
| Design System | #01, #17 | None |
| Tooling | #44, #45, #46, #59, #60, #61 | None |
| Cards | #04, #05, #06 | #03 |
| iPad | #24, #25 | #23 |
| Settings | #27, #28, #29 | #08, #17 |
| Platform | #18, #19, #20, #21, #22 | #26 |

## Issue Dependency Matrix

| Issue | Depends On | Blocks |
|-------|------------|--------|
| #00 | - | #10 |
| #01 | - | - |
| #02 | #17 | - |
| #03 | #26 | #04, #05, #06, #08 |
| #04 | #03 | - |
| #05 | #03 | #13 |
| #06 | #03 | - |
| #07 | All | - |
| #08 | #03, #26 | #09, #12, #14, #27, #52 |
| #09 | #08 | - |
| #10 | #00 | #23, #62 |
| #11 | #26 | - |
| #12 | #08 | - |
| #13 | #05 | - |
| #14 | #08 | - |
| #15 | - | - |
| #16 | #26 | - |
| #17 | - | #02, #23, #26, #27 |
| #18 | - | - |
| #19 | - | - |
| #20 | - | #54 |
| #21 | - | #55 |
| #22 | - | - |
| #23 | #10, #17 | #24, #25, #26, #66 |
| #24 | #23 | - |
| #25 | #23 | - |
| #26 | #23, #17 | #03, #08, #11, #16, #30, #31, #32, #33, #64, #69 |
| #27 | #08, #17 | #28, #29 |
| #28 | #27 | - |
| #29 | #27 | #56 |
| #30 | #26 | - |
| #31 | #26 | - |
| #32 | #26 | #53, #57 |
| #33 | #26 | - |
| #34 | - | #35, #36, #37 |
| #35 | #34 | - |
| #36 | #34 | - |
| #37 | #34 | - |
| #38 | - | - |
| #39 | - | - |
| #40 | - | #58 |
| #41 | - | - |
| #42 | - | - |
| #43 | - | #66 |
| #44 | - | #50 |
| #45 | - | #50 |
| #46 | - | - |
| #47 | - | - |
| #48 | - | #58 |
| #49 | - | #65 |
| #50 | #44, #45 | - |
| #51 | - | - |
| #52 | #08 | - |
| #53 | #32 | - |
| #54 | #20 | #67 |
| #55 | #21 | - |
| #56 | #29 | - |
| #57 | #32 | #68 |
| #58 | #40, #48 | - |
| #59 | - | - |
| #60 | - | - |
| #61 | - | - |
| #62 | #10 | - |
| #63 | - | - |
| #64 | #26 | - |
| #65 | #49 | - |
| #66 | #23, #43 | - |
| #67 | #54 | - |
| #68 | #57 | - |
| #69 | #26 | - |
| #70 | #17, #26, #27 | - |
| #71 | #05, #34 | - |
| #72 | #26, #66 | - |

## Acceptance Criteria

- [ ] Complete Mermaid graph with all 73 issues
- [ ] Dependency edges accurately reflect issue specs
- [ ] Critical path identified
- [ ] Parallel work opportunities documented
- [ ] Dependency matrix for quick reference
- [ ] Graph renders correctly in GitHub/GitLab

## Testing

Manual: Verify graph renders in VS Code Mermaid preview and GitHub markdown.
