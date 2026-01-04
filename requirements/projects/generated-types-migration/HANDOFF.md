# Agent Handoff: Generated Types Migration

> Start Date: 2026-01-01
> Status: Ready to begin Phase 1

## Context

We're migrating all hand-written cli-bridge types to OpenAPI-generated types. The cli-bridge team has completed all prerequisite work:

- ✅ #8 - ServerMessage now uses `oneOf` with discriminator (generates proper Swift enum)
- ✅ #9 - Push notification endpoints added to OpenAPI
- ✅ #10 - File/directory endpoints added to OpenAPI
- ✅ #11 - Other missing endpoints added to OpenAPI (just deployed)

## Your Task

Execute the 7-phase migration plan in [PLAN.md](./PLAN.md).

## Quick Start

### Phase 1: Regenerate Types

```bash
cd /Users/ppatterson/dev/CodingBridge

# Regenerate all types from updated OpenAPI spec
./scripts/regenerate-api-types.sh

# Verify new types were generated (should be 110+ files, up from 96)
ls CodingBridge/Generated/*.swift | wc -l

# Check for key new types
ls CodingBridge/Generated/ | grep -E "ServerMessage|PushRegister|FileEntry|FileList"

# Build to verify no conflicts
xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build
```

### Phase 2: Create Typealiases

Update `CodingBridge/CLIBridgeTypesMigration.swift` with typealiases for ALL hand-written types. Reference the type mapping table in [PLAN.md](./PLAN.md).

### Phases 3-7

Follow the detailed instructions in [PLAN.md](./PLAN.md).

## Key Files

| File | Purpose |
|------|---------|
| `CLIBridgeTypes.swift` | Hand-written types to replace (~2500 lines, 75 types) |
| `CLIBridgeTypesMigration.swift` | Typealiases and extensions (add more here) |
| `CLIBridgeManager.swift` | WebSocket handling (update in Phase 3) |
| `CLIBridgeAPIClient.swift` | REST API calls (update in Phase 4) |
| `Generated/` | Auto-generated types (regenerate in Phase 1) |

## CLI Bridge Server

- **URL:** `http://172.20.0.2:3100`
- **OpenAPI Spec:** `http://172.20.0.2:3100/openapi.json`
- **Swagger UI:** `http://172.20.0.2:3100/docs`

## Important Notes

1. **Build after each phase** - Verify no regressions
2. **Run tests after Phase 2** - All existing tests should pass with typealiases
3. **Keep CLIBridgeTypes.swift until Phase 6** - Typealiases provide safety net
4. **Update STATUS.md** - Mark phases complete as you go

## Success Criteria

- [ ] 110+ generated types (up from 96)
- [ ] Zero hand-written protocol types
- [ ] `CLIBridgeTypes.swift` deleted
- [ ] All tests pass
- [ ] App works correctly with cli-bridge

## Commands Reference

```bash
# Build
xcodebuild -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build

# Test
xcodebuild test -project CodingBridge.xcodeproj -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'

# Find remaining CLI* usages
grep -r "CLI[A-Z]" CodingBridge/*.swift --include="*.swift" | \
  grep -v "CLIBridgeTypes\|CLIBridgeTypesMigration\|CLITheme\|CLIDateFormatter"

# Regenerate types
./scripts/regenerate-api-types.sh
```

## Questions?

- Check [PLAN.md](./PLAN.md) for detailed phase instructions
- Check [STATUS.md](./STATUS.md) for current progress
- cli-bridge API docs at `http://172.20.0.2:3100/docs`
