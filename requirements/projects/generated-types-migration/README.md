# Generated Types Migration

Migrate all hand-written cli-bridge types to OpenAPI-generated types.

## Files

| File | Purpose |
|------|---------|
| [HANDOFF.md](./HANDOFF.md) | **Start here** - Agent handoff with quick start |
| [PLAN.md](./PLAN.md) | 7-phase migration plan with type mapping |
| [STATUS.md](./STATUS.md) | Current progress and blockers |

## Quick Links

- [cli-bridge repo](https://github.com/wiseyoda/cli-bridge)
- [Issue #8](https://github.com/wiseyoda/cli-bridge/issues/8) - ServerMessage discriminator ✅
- [Issue #9](https://github.com/wiseyoda/cli-bridge/issues/9) - Push endpoints ✅
- [Issue #10](https://github.com/wiseyoda/cli-bridge/issues/10) - File endpoints ✅
- [Issue #11](https://github.com/wiseyoda/cli-bridge/issues/11) - Other endpoints ✅

## Goal

| Before | After |
|--------|-------|
| 75 hand-written types | 0 hand-written types |
| 96 generated types | 110+ generated types |
| 2500 lines in CLIBridgeTypes.swift | File deleted |

## Status

✅ **Ready to start** - All 4 cli-bridge issues resolved and deployed.

Start with [HANDOFF.md](./HANDOFF.md).
