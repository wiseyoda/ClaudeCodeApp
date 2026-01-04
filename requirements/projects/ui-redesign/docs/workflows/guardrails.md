# Execution Guardrails

## Spec Hierarchy (resolve conflicts)

1. `../../README.md` (entrypoint) + `../../STATUS.md`
2. `../build/README.md` (build settings)
3. `../contracts/models/README.md` + `../contracts/api/README.md` (contracts)
4. `../architecture/data/README.md` + `../architecture/ui/README.md`
5. `../design/README.md`
6. Issue specs
7. Existing code

## Definition of Done (per issue)

- [ ] Acceptance criteria met
- [ ] iOS 26 APIs used (no compatibility shims)
- [ ] Design tokens + Liquid Glass applied
- [ ] Swift 6 concurrency rules followed (@Observable, actors, @MainActor)
- [ ] Security checklist applied for settings/SSH/file/API changes
- [ ] Tests updated when models/protocols change
- [ ] Accessibility checked (Dynamic Type, VoiceOver)
- [ ] Performance noted for long chat sessions (scroll, memory)
- [ ] CHANGELOG.md updated or release notes captured for user-visible changes
- [ ] Status dashboard updated

## Issue Hygiene (when editing or adding)

- Required fields: Goal, Scope/Non-goals, Dependencies, Touch Set, Interface Definitions, Edge Cases, Acceptance Criteria, Tests
- Use `../../issues/ISSUE-TEMPLATE.md` as the baseline for new issues
- If scope changes, update the issue spec and note it in `../../STATUS.md`

## Integration Gates (end of each phase)

- Build passes on iPhone 17 Pro (iOS 26.2)
- Smoke test: launch, connect, send message, scroll, open settings
- `../../STATUS.md` updated with risks and remaining gaps
