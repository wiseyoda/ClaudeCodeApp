# Phase 0: Foundation

Foundational contracts, concurrency, design tokens, and test strategy.

## Core References

- [Execution Guardrails](../../docs/workflows/guardrails.md)
- [Build Configuration](../../docs/build/README.md)
- [Contracts (Models + API)](../../docs/contracts/README.md)
- [Data Architecture](../../docs/architecture/data/README.md)
- [Design System](../../docs/design/README.md)

## Sequencing Notes

- Recommended order: 00 → 10 → 01 → 17 → 40
- Issues 44/45/46/59/60/61/62/63 can run in parallel after 10

## Issues

- [Issue 00: Data Normalization Layer](00-data-normalization.md)
- [Issue 01: Design System Foundation](01-design-tokens.md)
- [Issue 10: @Observable + Actor Migration](10-observable-migration.md)
- [Issue 17: Liquid Glass Design System](17-liquid-glass.md)
- [Issue 40: Testing Strategy](40-testing-strategy.md)
- [Issue 44: Debug Tooling](44-debug-tooling.md)
- [Issue 45: Feature Flags](45-feature-flags.md)
- [Issue 46: Localization Strategy](46-localization.md)
- [Issue 59: Dependency Graph](59-dependency-graph.md)
- [Issue 60: Code Review Checklist](60-code-review-checklist.md)
- [Issue 61: Swift Style + DocC Standards](61-swift-style-docc.md)
- [Issue 62: Migration Helpers](62-migration-helpers.md)
- [Issue 63: Error Type Hierarchy](63-error-types.md)
