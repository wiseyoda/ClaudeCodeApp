# Generated Types Migration Status

> Last updated: 2026-01-03

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
| 1. Regenerate | ✅ Complete | Regenerated from OpenAPI (157 types in `CodingBridge/Generated/`) |
| 2. Typealiases | ✅ Complete | CLI* aliases centralized in `CLIBridgeAppTypes.swift` (31 total) |
| 3. CLIBridgeManager | ✅ Complete | Uses generated `ServerMessage`/`ClientMessage` and stream handling |
| 4. CLIBridgeAPIClient | ⏳ In Progress | Still uses custom CLI* request/response wrappers |
| 5. Views/Stores | ⏳ In Progress | UI still consumes CLI* wrappers (`CLIStreamContent`, `CLIStoredMessage`) |
| 6. Remove Types | ⏳ In Progress | Hand-written protocol wrappers remain in app/API client layers |
| 7. Clean Up | ⏳ In Progress | Docs and migration notes still need updates |

---

## Current Stats

| Metric | Before | Target | Current |
|--------|--------|--------|---------|
| Generated types | 96 | 110+ | 157 |
| Hand-written CLI* types (app + API client) | 75 | 0 | 36 |
| `CLIBridgeTypes.swift` lines | 2500 | 0 | 0 |
| Typealiases created | 3 | As needed | 31 |

---

## Blockers

None. Remaining work is code migration, not external dependencies.

---

## Revisit Checklist

- Dedicated refactor window available (touches many call sites).
- WebSocket + REST integration tests can be run against a stable backend.
- OpenAPI spec has been stable for at least one release cycle.
- No imminent UI/feature release that would amplify regression risk.

---

## Notes

- `CLIBridgeTypes.swift` is removed; app-specific and compatibility types live in `CLIBridgeAppTypes.swift`
- `CLIStreamContent`/`CLIStoredMessage` remain as custom wrappers over generated `StreamMessage`/`StoredMessage`
- `CLIBridgeAPIClient.swift` still defines CLI* request/response structs (e.g., projects/sessions/metrics)
- Generated enum case names (`.type*`) still require call-site updates to remove wrappers
