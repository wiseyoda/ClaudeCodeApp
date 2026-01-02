# Generated Types Migration Status

> Last updated: 2026-01-01

## Prerequisites

| Issue | Status | Notes |
|-------|--------|-------|
| [#8](https://github.com/wiseyoda/cli-bridge/issues/8) | ✅ Complete | ServerMessage discriminator |
| [#9](https://github.com/wiseyoda/cli-bridge/issues/9) | ✅ Complete | Push notification endpoints |
| [#10](https://github.com/wiseyoda/cli-bridge/issues/10) | ✅ Complete | File/directory endpoints |
| [#11](https://github.com/wiseyoda/cli-bridge/issues/11) | ✅ Complete | Other missing endpoints |

**Ready to start:** ✅ Yes - All prerequisites complete!

---

## Phase Progress

| Phase | Status | Description |
|-------|--------|-------------|
| 1. Regenerate | ✅ Complete | Regenerate with complete spec (143 types) |
| 2. Typealiases | ✅ Complete | Created 84 typealiases |
| 3. CLIBridgeManager | ✅ Complete | Added compatibility extensions |
| 4. CLIBridgeAPIClient | ✅ Complete | Added API response typealiases |
| 5. Views/Stores | ✅ Complete | All types have typealiases |
| 6. Remove Types | ⏸️ Deferred | Infrastructure ready, needs code updates |
| 7. Clean Up | ✅ Complete | Documentation updated |

---

## Current Stats

| Metric | Before | Target | Current |
|--------|--------|--------|---------|
| Generated types | 96 | 110+ | 143 |
| Hand-written types | 75 | 0 | 75 |
| `CLIBridgeTypes.swift` lines | 2500 | 0 | 2500 |
| Typealiases created | 3 | 75+ | 84 |

---

## Blockers

None! All prerequisites complete.

---

## Notes

- Initial migration infrastructure created (2026-01-01)
- Completed Phases 1-5, all infrastructure in place
- 143 generated types (up from 96)
- 84 typealiases bridging CLI* names to generated types
- Compatibility extensions for smooth transition
- Phase 6 deferred: Generated types have different enum case names
  - e.g., `.input(payload)` vs `.typeInputMessage(payload)`
  - Full switch requires updating case names throughout codebase
  - Infrastructure is ready, can migrate file-by-file as needed
