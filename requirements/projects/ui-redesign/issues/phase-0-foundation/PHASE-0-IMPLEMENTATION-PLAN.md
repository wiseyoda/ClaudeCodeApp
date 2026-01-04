# Phase 0 Implementation Plan

**Version**: 1.0
**Date**: 2026-01-03
**Status**: Ready for execution
**Timeline**: 4 weeks (56 hours estimated effort)
**Critical Blocker**: Issue #10 (@Observable Migration) → unblocks Phase 1

---

## Executive Summary

Phase 0 consists of 13 foundation issues that are currently 40-80% complete. All Phase 0 issue specs now have zero TBD sections (as of 2026-01-03); this plan focuses on implementation, tests, and validation needed before Phase 1 begins.

**Key Principle**: Complete Phase 0 fully before Phase 1 code begins. Issue #10 must be bulletproof as it establishes all state management patterns for the redesign.

---

## Critical Path

```
SEQUENTIAL (Must complete in order):
  Issue #00: Data Normalization Layer (12 hrs)
    ↓
  Issue #10: @Observable + Actor Migration (16 hrs) ← PHASE 1 BLOCKER
    ↓
  Issue #62: Migration Helpers (6 hrs)

PARALLEL (Can start Week 1 afternoon or Week 2):
  Design Foundation:
    - Issue #01: Design Tokens (10 hrs)
    - Issue #17: Liquid Glass (12 hrs)

  QA Infrastructure:
    - Issue #40: Testing Strategy (14 hrs total)
    - Issue #44: Debug Tooling (8 hrs)
    - Issue #45: Feature Flags (6 hrs)
    - Issue #46: Localization (5 hrs)

  Documentation & Process:
    - Issue #59: Dependency Graph (4 hrs)
    - Issue #60: Code Review Checklist (6 hrs)
    - Issue #61: Swift Style + DocC (8 hrs)
    - Issue #63: Error Type Hierarchy (10 hrs)
```

---

## Weekly Schedule

### Week 1: Critical Foundation

**Monday-Tuesday: Issue #00 - Data Normalization Layer**
- Effort: 12 hours
- Current: 60% complete
- Gaps to fill:
  - [ ] ContentSanitizer.sanitize() algorithm with edge cases
  - [ ] MessageValidationError enum (all validation failure modes)
  - [ ] ValidatedMessage → ChatMessage field mapping table
  - [ ] Integration examples (REST + WebSocket paths)
  - [ ] Unit test suite (15+ test cases covering edge cases)

**Deliverables**:
- `CodingBridge/Normalization/MessageNormalizer.swift` (complete implementation)
- `CodingBridge/Normalization/ValidatedMessage.swift` (enhanced with mapping)
- `CodingBridgeTests/NormalizerTests.swift` (15+ unit tests)
- Spec updated with zero TBD sections (complete)

**Checkpoint**: Issue #00 complete and reviewed

---

**Wednesday-Friday: Issue #10 - @Observable + Actor Migration**
- Effort: 16 hours
- Current: 75% complete
- **CRITICAL**: This blocks Phase 1 - must be bulletproof

- Gaps to fill:
  - [ ] Execute migration scope per spec (stores, view models, views)
  - [ ] Schema versioning system (version detection, upgrade path)
  - [ ] Data migration code (UserDefaults + Keychain strategies)
  - [ ] Actor cleanup patterns with tests
  - [ ] View integration examples (5+ view types)
  - [ ] Thread Sanitizer verification (complete concurrency checking)
  - [ ] Per-file migration checklist (detailed steps)

**Deliverables**:
- `CodingBridge/Utilities/ObservationHelpers.swift` (shared helpers, optional)
- Updated `CodingBridge/AppSettings.swift` (manual persistence + migration)
- Updated `CodingBridge/SessionStore.swift` and `CodingBridge/SessionRepository.swift`
- Updated `CodingBridge/ViewModels/ChatViewModel.swift` + extensions
- Updated stores in `CodingBridge/` (CommandStore, IdeasStore, BookmarkStore, ProjectSettingsStore, SearchHistoryStore, DebugLogStore, MessageStore, StatusMessageStore)
- `CodingBridgeTests/ObservationMigrationTests.swift` (schema upgrade harness)
- Updated spec with complete migration guide
- Per-file migration checklist for all stores/ViewModels

**Checkpoint**: Issue #10 100% complete. Phase 1 now unblocked.

---

### Week 2: Design Foundation

**Monday-Wednesday: Issue #01 - Design System Foundation**
- Effort: 10 hours
- Current: 80% complete
- Gaps to fill:
  - [ ] Complete MessageDesignSystem.swift with spacing, typography, color, and animation tokens
  - [ ] Role styles for iOS 26 semantic colors
  - [ ] MessageCardCapability extensions with helpers
  - [ ] Typography scaling for Dynamic Type (AX0-AX7)
  - [ ] Integration with Theme.swift

**Deliverables**:
- `CodingBridge/Design/MessageDesignSystem.swift` (production-ready)
- `CodingBridge/Theme.swift` (bridged to design tokens)
- `CodingBridgeTests/MessageDesignSystemTests.swift` (90%+ coverage)
- Color contrast validation report (WCAG AA verified)
- Spec updated with zero TBD sections (complete)

**Checkpoint**: Design tokens implemented and testable

---

**Wednesday-Friday: Issue #17 - Liquid Glass Design System**
- Effort: 12 hours
- Current: 40% complete
- Gaps to fill:
  - [ ] LiquidGlassStyle enum with all variants (.card, .tinted, .sheet, .widget)
  - [ ] View extensions (.liquidGlass, .messageCardStyle, .toolCardStyle)
  - [ ] Role-to-GlassStyle mapping table
  - [ ] iOS 26.x workarounds documented
  - [ ] Animation transitions specified
  - [ ] Accessibility (high contrast mode fallback)
  - [ ] Replace legacy materials with system glass APIs

**Deliverables**:
- `CodingBridge/Design/LiquidGlassStyles.swift` (styles + view extensions)
- Updated `CodingBridge/Theme.swift` (glass helpers)
- Updated `CodingBridge/AppSettings.swift` (intensity setting)
- Updated glass usage in message cards + sheets
- `CodingBridgeTests/LiquidGlassTests.swift` (all variants tested)
- Updated spec with iOS 26 workarounds

**Checkpoint**: Glass effects production-ready

---

**Friday Afternoon: Issue #40 - Testing Strategy (Start)**
- Effort: 14 hours total (8 today, 6 next week)
- Current: 50% complete
- Today's work:
  - [ ] Define coverage targets per module (80%+ for redesigned code)
  - [ ] Specify 5 critical XCUITest flows with step-by-step plans
  - [ ] Create test fixture factory in `CodingBridgeTests/TestSupport/`

---

### Week 3: QA Infrastructure

**Monday-Tuesday: Issue #40 - Testing Strategy (Complete)**
- Effort: 6 hours
- Continue from Friday:
  - [ ] Performance benchmark specifications (500 msgs @ 60fps)
  - [ ] CI/CD integration plan
  - [ ] Coverage reporting setup
  - [ ] Accessibility test automation

**Deliverables**:
- `CodingBridgeTests/TestSupport/MockFactory.swift` (complete factories)
- `CodingBridgeTests/TestSupport/FixtureCatalog.swift` (shared test data)
- `CodingBridgeUITests/TestSupport/WebSocketReplay.swift` (deterministic streaming)
- `CodingBridgeUITests/CriticalFlows/` (5 flow implementations)
- Testing strategy doc with zero TBD sections (complete)
- TEST-COVERAGE.md template

**Checkpoint**: Testing framework specified

---

**Tuesday-Wednesday: Issue #44 - Debug Tooling**
- Effort: 8 hours
- Current: 30% complete
- Gaps to fill:
  - [ ] Debug menu implementation
  - [ ] Slow network simulation (delay + packet loss presets)
  - [ ] SwiftUI Instruments integration
  - [ ] Mock factories for all message types
  - [ ] #Preview definitions (15+)

**Deliverables**:
- `CodingBridge/Debug/DebugMenu.swift` (8+ toggles with state)
- `CodingBridge/Debug/MockFactory.swift` (all message roles)
- `CodingBridge/Debug/NetworkSimulation.swift` (delay/drop)
- `CodingBridge/Debug/LiquidGlassPreview.swift` (gallery)
- Debug tooling guide with workarounds

**Checkpoint**: Debug infrastructure ready

---

**Thursday: Issue #45 - Feature Flags (Local Registry + Debug Overrides)**
- Effort: 6 hours
- Current: 45% complete
- Gaps to fill:
  - [ ] Complete FeatureFlag enum (all phases)
  - [ ] Flag metadata (owner, phase, removalDate)
  - [ ] FeatureFlagProvider protocol + implementation
  - [ ] Debug menu for flag toggles

**Deliverables**:
- `CodingBridge/FeatureFlags.swift` (local registry + metadata)
- `CodingBridge/FeatureFlagProvider.swift` (protocol + local impl)
- `CodingBridge/Views/FeatureFlagsDebugView.swift`
- `Config/Version.xcconfig` (build flag toggles)
- Feature flag system guide (local overrides only)

**Checkpoint**: Feature flags infrastructure ready

---

**Friday: Issue #46 - Localization**
- Effort: 5 hours
- Current: 30% complete
- Gaps to fill:
  - [ ] String Catalog setup (CodingBridge.xcstrings)
  - [ ] String key naming convention
  - [ ] Pluralization handling
  - [ ] Localization testing approach

**Deliverables**:
- `CodingBridge/CodingBridge.xcstrings` (catalog)
- `CodingBridge/Localization/LocalizationHelper.swift`
- Localization strategy guide
- String key reference table

**Checkpoint**: Localization infrastructure ready

---

### Week 4: Documentation & Process

**Monday: Issue #59 - Dependency Graph**
- Effort: 4 hours
- Current: 20% complete
- Gaps to fill:
  - [ ] Complete Mermaid graph (all 73 issues + dependencies)
  - [ ] Critical path highlighted
  - [ ] Phase groupings with subgraphs
  - [ ] Edge labels explaining dependencies

**Deliverables**:
- `requirements/projects/ui-redesign/docs/overview/dependency-graph.md`
- Mermaid rendering (works in GitHub)
- Phase readiness checklist

**Checkpoint**: Dependency graph complete and validated

---

**Tuesday-Wednesday: Issue #60 - Code Review Checklist**
- Effort: 6 hours
- Current: 35% complete
- Gaps to fill:
  - [ ] 8 concurrency checks with examples
  - [ ] 6+ iOS 26 API checks
  - [ ] 5 accessibility checks (WCAG references)
  - [ ] 4 performance review criteria
  - [ ] 4 security review criteria
  - [ ] 5 UI consistency checks
  - [ ] Documentation review points
  - [ ] Testing expectations

**Deliverables**:
- `requirements/projects/ui-redesign/docs/workflows/code-review-checklist.md`
- Supporting guides (concurrency, iOS26, accessibility)
- PR template referencing checklist

**Checkpoint**: Code review standards established

---

**Thursday: Issue #61 - Swift Style + DocC Standards**
- Effort: 8 hours
- Current: 25% complete
- Gaps to fill:
  - [ ] Complete naming conventions (types, functions, constants, booleans)
  - [ ] Access modifier strategy
  - [ ] DocC comment templates
  - [ ] Code organization with MARK: sections
  - [ ] Swift 6 concurrency naming
  - [ ] 3+ examples per rule (correct + incorrect)

**Deliverables**:
- `requirements/projects/ui-redesign/docs/workflows/swift-style.md`
- `requirements/projects/ui-redesign/docs/workflows/naming-conventions.md`
- `requirements/projects/ui-redesign/docs/workflows/docc-standards.md`
- `requirements/projects/ui-redesign/docs/workflows/naming-conventions.md`
- `requirements/projects/ui-redesign/docs/workflows/docc-standards.md`
- Class/actor/protocol/view templates

**Checkpoint**: Swift standards adopted

---

**Friday: Issue #62 & #63 - Migration Helpers + Error Types**
- Issue #62 Effort: 6 hours
- Issue #63 Effort: 10 hours

**Issue #62 - Migration Helpers**
- Gaps to fill:
  - [ ] 5+ @Observable migration recipes
  - [ ] View property wrapper patterns
  - [ ] Navigation migration patterns
  - [ ] Persistence migration
  - [ ] Dependency injection patterns
  - [ ] 6+ common pitfalls + fixes
  - [ ] Per-file migration checklist (10+ files)

**Deliverables**:
- `requirements/projects/ui-redesign/docs/workflows/migration-guide.md`
- Recipes directory with 5+ detailed guides
- Per-file checklist for stores/ViewModels

---

**Issue #63 - Error Type Hierarchy**
- Gaps to fill:
  - [ ] Complete AppError enum (50+ cases)
  - [ ] UserFacingError mapping for all cases
  - [ ] ErrorRecoveryOption struct
  - [ ] ErrorMapper with localized messages
  - [ ] Logger integration with correlation IDs
  - [ ] Sendable + Codable conformances
  - [ ] Tool error classification
  - [ ] Unit tests (20+ error cases)

**Deliverables**:
- `CodingBridge/Core/Errors/AppError.swift` (50+ cases)
- `CodingBridge/Core/Errors/UserFacingError.swift`
- `CodingBridge/Core/Errors/ErrorMapping.swift`
- `CodingBridge/Core/Errors/ErrorLogging.swift`
- `CodingBridgeTests/ErrorTests.swift` (comprehensive)
- Error type hierarchy guide

**Checkpoint**: All 13 issues complete!

---

## Quality Gates

### Per-Issue Acceptance Criteria

Each issue must meet **100%** of these criteria before moving to next:

| Aspect | Requirement |
|--------|-------------|
| **TBD Sections** | Zero - all sections must be filled with production content |
| **Code Examples** | All examples must compile without errors |
| **Tests** | >= 80% coverage for redesigned modules, all tests pass |
| **Documentation** | Comprehensive, required links intact, no missing context |
| **Design Review** | ✓ reviewed and approved |
| **Code Review** | ✓ reviewed for style/standards |
| **Integration** | ✓ verified against related issues |

### Build Gates Before Phase 1

- [x] All 13 issues have zero TBD sections (specs complete)
- [ ] All code compiles without errors
- [ ] All tests pass (unit + UI)
- [ ] Documentation builds (no broken links)
- [ ] Code review checklist created
- [ ] Swift style guide adopted
- [ ] Dependency graph validated
- [ ] Migration helpers tested
- [ ] Feature flags build correctly
- [ ] Error types cover all error domains

---

## Deliverables by Category

### Code Files (Representative)

1. **Normalization**: `MessageNormalizer.swift`, `ValidatedMessage.swift`
2. **Observation**: `ObservationHelpers.swift`, updated `AppSettings.swift`, updated stores/view models
3. **Design**: `MessageDesignSystem.swift`, `LiquidGlassStyles.swift`
4. **Features**: `FeatureFlags.swift`, `FeatureFlagProvider.swift`
5. **Errors**: `AppError.swift`, `UserFacingError.swift`, `ErrorMapping.swift`
6. **Debug**: `DebugMenu.swift`, `MockFactory.swift`, `NetworkSimulation.swift`
7. **Tests**: `NormalizerTests.swift`, `ObservationMigrationTests.swift`, `ErrorTests.swift`

### Test Files (Representative)

- `CodingBridgeTests/TestSupport/MockFactory.swift` (mock builders)
- `CodingBridgeTests/TestSupport/FixtureCatalog.swift` (fixture sets)
- `CodingBridgeUITests/TestSupport/WebSocketReplay.swift` (streaming harness)
- `CodingBridgeTests/Unit/` (250+ unit tests)
- `CodingBridgeUITests/CriticalFlows/` (5 XCUITest flows)
- `CodingBridgeTests/Performance/` (benchmark setup)

### Documentation Files (13+ total)

1. **Issue #00**: Data Normalization spec (updated)
2. **Issue #01**: Design Tokens spec (updated)
3. **Issue #10**: Observable Migration spec + guide
4. **Issue #17**: Liquid Glass spec + workarounds guide
5. **Issue #40**: Testing Strategy spec + coverage targets
6. **Issue #44**: Debug Tooling spec + user guide
7. **Issue #45**: Feature Flags spec + registry
8. **Issue #46**: Localization spec + guide
9. **Issue #59**: Dependency Graph (Mermaid + analysis)
10. **Issue #60**: Code Review Checklist (8 sections)
11. **Issue #61**: Swift Style Guide + Naming Conventions + DocC
12. **Issue #62**: Migration Helpers Guide (5+ recipes)
13. **Issue #63**: Error Type Hierarchy (50+ cases)

---

## Risk Mitigation

### High-Risk Items

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Issue #10 delays | Medium | Critical | Start Day 1, pair programming, daily review |
| Schema migration bugs | Medium | Critical | Comprehensive test harness, upgrade path testing |
| Incomplete design tokens | Low | High | Daily design review, iOS HIG validation |
| Test coverage gaps | Low | High | Automated coverage reporting, PR gates |
| Circular doc dependencies | Low | Medium | Validate links daily, dependency matrix |

---

## Success Metrics

Phase 0 is **complete and successful** when:

✅ **Documentation**
- [x] All 13 issue specs have zero TBD sections (specs complete)
- [ ] Every spec has concrete code examples
- [ ] All patterns documented with before/after
- [ ] No cross-references requiring external docs

✅ **Code**
- [ ] All code files compile without errors
- [ ] All code follows Swift style guide
- [ ] All code has DocC documentation
- [ ] No compiler warnings

✅ **Tests**
- [ ] Unit tests pass 100%
- [ ] UI tests pass 100%
- [ ] Coverage ≥80% for redesigned modules
- [ ] Performance benchmarks established

✅ **Architecture**
- [ ] Dependency graph validated (no cycles)
- [ ] Error types cover all domains
- [ ] State management patterns clear
- [ ] Data normalization complete

✅ **Team Readiness**
- [ ] All developers understand Phase 0 patterns
- [ ] No ambiguity about how to structure Phase 1 code
- [ ] Code review standards established
- [ ] Testing expectations clear

✅ **Phase 1 Unblocked**
- [ ] Issue #10 (@Observable) 100% complete
- [ ] Design tokens ready for use
- [ ] Error handling system established
- [ ] Testing framework specified

---

## Implementation Approach

### Start Conditions

- [ ] All developers have read this plan
- [ ] Phase 0 Foundation Assessment reviewed and approved
- [ ] Development environment set up (Xcode 26.2, iOS 26.2 simulator)
- [ ] Git branch created for Phase 0 work

### Work Sequencing

1. **Day 1 Morning**: Issue #00 (Data Normalization) begins
2. **Day 1 Afternoon**: Issue #10 (@Observable) begins (parallel team)
3. **Day 3 End**: Issue #00 complete, review + approval
4. **Day 5 End**: Issue #10 complete, review + approval (Phase 1 now unblocked)
5. **Week 2**: Parallel work on design + QA infrastructure
6. **Week 3**: Complete QA + debug infrastructure
7. **Week 4**: Documentation + process (low-priority parallel work)

### Daily Standup Cadence

**Critical Path** (Issues #00, #10, #62):
- Daily 15-min standup
- Blockers escalated immediately
- Daily progress review

**Parallel Work** (Issues #01, #17, #40, #44, #45, #46, #59, #60, #61, #63):
- 3x per week standup
- Weekly progress review

### Review Gates

| Milestone | Reviewer | Criteria |
|-----------|----------|----------|
| Issue #00 | Lead | Zero TBD, tests pass, examples compile |
| Issue #10 | Lead + Concurrency Expert | Zero TBD, Thread Sanitizer clean, migration tested |
| Design Issues (#01, #17) | Design Lead | WCAG AA verified, iOS 26 compliance |
| QA Issues (#40, #44, #45, #46) | QA Lead | Coverage targets met, fixtures complete |
| Doc Issues (#59-#63) | Docs Reviewer | Links valid, examples current |

---

## Next Steps

1. **Today**: Approve this plan
2. **Monday**: Begin Issue #00 + #10
3. **Wednesday**: Review Issue #00
4. **Friday**: Review Issue #10 (if complete)
5. **Week 2**: Begin design + QA parallel work
6. **Week 4**: Final review, Phase 1 kickoff

---

## Related Documents

- [Phase 0 Status](../../STATUS.md) - Current status tracking
- [Phase 0 Issues](README.md) - Issue index
- [Execution Guardrails](../../docs/workflows/guardrails.md) - Development rules
- [Architecture](../../docs/architecture/README.md) - Architectural documentation

---

**Questions?** Use issue specs and STATUS.md for the canonical guidance.

**Ready to execute?** Begin with Issue #00 on Day 1.
