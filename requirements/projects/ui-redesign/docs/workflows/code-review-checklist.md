# Code Review Checklist

## Purpose

Ensure iOS 26.2 redesign changes meet quality, safety, accessibility, and performance standards.

## Required Inputs

- Issue spec + acceptance criteria
- UI screenshots/recording (for visual changes)
- Test results (unit/UI as applicable)

## Checklist

### Architecture and State

- [ ] Follows current issue spec and design decisions.
- [ ] Uses @Observable and actors (no new ObservableObject or @Published).
- [ ] @MainActor used only for UI-bound @Observable types.
- [ ] Shared mutable state is actor-isolated; no ad-hoc locks.
- [ ] Repository layer owns caching/error pipelines (no ErrorStore/TaskState/ProjectCache).

### Data and Contracts

- [ ] Message normalization runs through MessageNormalizer for history + stream.
- [ ] StreamEvent/contract changes are documented in contracts docs.
- [ ] Tool error classification uses ToolErrorClassification (no bespoke mappings).

### UI and Design

- [ ] Liquid Glass usage follows design tokens and iOS 26.2 best practices.
- [ ] Status banner behavior matches spec (streaming-only, above input).
- [ ] Message cards follow design system spacing/typography tokens.
- [ ] Project list simplified for large lists and uses cli-bridge status only.

### Accessibility

- [ ] Dynamic Type supported for all user-visible text.
- [ ] VoiceOver labels exist for icon-only controls.
- [ ] Touch targets meet 44x44pt minimum.
- [ ] Reduced Motion and high-contrast modes respected.

### Performance

- [ ] Long sessions (500+ messages) remain responsive; no O(n^2) rendering.
- [ ] Expensive views have lazy loading or caching where needed.
- [ ] Background tasks are lightweight and respect iOS limits.

### Security and Privacy

- [ ] SSH commands use proper shell quoting and $HOME (no ~).
- [ ] No secrets stored in @AppStorage or UserDefaults.
- [ ] Diagnostics/telemetry redacts file paths and message content.
- [ ] Firebase SDK not introduced (provider-agnostic only).

### Feature Flags and Diagnostics

- [ ] New features are gated when appropriate.
- [ ] Diagnostics consolidates error analytics and insights (no Firebase yet).
- [ ] Debug-only tooling is compiled out of Release builds.

### Testing and Docs

- [ ] Unit tests added/updated for model or protocol changes.
- [ ] UI tests updated for major flow changes.
- [ ] New Swift files added to Xcode project.
- [ ] Docs updated (issues, STATUS.md, README where applicable).

## Review Outcome

- [ ] Approve
- [ ] Request changes
- [ ] Follow-up issues logged
