# Permission Approval Banner Implementation

**Status:** 🔧 DEBUGGING - Implementation complete, testing in progress
**Last Updated:** 2025-12-28

---

## Problem Statement

When `permissionMode` is not `bypassPermissions`, Claude CLI requires interactive approval for certain tools (like Bash commands). Previously:
- The claudecodeui backend didn't have a `canUseTool` callback
- Without the callback, the SDK just returned errors ("This command requires approval")
- The iOS app showed these as error messages instead of actionable approval prompts

**Solution implemented:** Both backend and iOS app now support interactive permission approval via WebSocket messages.

---

## Solution Overview

**Two-part implementation:**
1. **Backend update** - Fork claudecodeui, add `canUseTool` callback to forward permission requests
2. **iOS app update** - Show approval banner and send responses

---

## Current Status

### Phase 2: iOS App - COMPLETE ✅

| Task | Status | File(s) |
|------|--------|---------|
| Add ApprovalRequest/ApprovalResponse structs | ✅ Done | `CodingBridge/Models.swift` |
| Add permission message handling | ✅ Done | `CodingBridge/WebSocketManager.swift` |
| Create ApprovalBannerView component | ✅ Done | `CodingBridge/Views/ApprovalBannerView.swift` |
| Add to Xcode project | ✅ Done | `CodingBridge.xcodeproj/project.pbxproj` |
| Integrate banner in ChatView | ✅ Done | `CodingBridge/ChatView.swift` |

### Phase 1: Backend (claudecodeui fork) - COMPLETE ✅

| Task | Status | Notes |
|------|--------|-------|
| Clone claudecodeui to container | ✅ Done | `~/workspace/claudecodeui` |
| Add `canUseTool` callback | ✅ Done | `server/claude-sdk.js` |
| Handle permission responses | ✅ Done | `server/index.js` - `permission-response` handler |
| Deploy fork with pm2 | ✅ Done | Runs from local fork instead of npm package |
| Update QNAP-CONTAINER.md | ✅ Done | Documented the new setup |

---

## iOS Implementation Details

### Models.swift Additions

```swift
// ApprovalRequest - represents pending permission request
struct ApprovalRequest: Identifiable, Equatable {
    let id: String          // requestId from server
    let toolName: String    // "Bash", "Read", "Write", etc.
    let input: [String: Any]
    let receivedAt: Date

    var toolIcon: String { ... }        // SF Symbol for tool
    var displayTitle: String { ... }    // Tool name
    var displayDescription: String { ... } // Command/path preview

    static func from(_ data: [String: Any]) -> ApprovalRequest? { ... }
}

// ApprovalResponse - sent back to server
struct ApprovalResponse: Encodable {
    let type: String = "permission-response"
    let requestId: String
    let behavior: String  // "allow" or "deny"
    let alwaysAllow: Bool
}
```

### WebSocketManager.swift Additions

```swift
// New properties
@Published var pendingApproval: ApprovalRequest?
var onApprovalRequest: ((ApprovalRequest) -> Void)?

// New message handler (in handleMessage switch)
case "permission-request":
    if let request = ApprovalRequest.from(dataDict) {
        pendingApproval = request
        onApprovalRequest?(request)
    }

// New methods
func sendApprovalResponse(requestId: String, allow: Bool, alwaysAllow: Bool)
func approvePendingRequest(alwaysAllow: Bool = false)
func denyPendingRequest()
```

### ApprovalBannerView.swift (New File)

Compact banner with:
- Tool icon + name
- Command/path preview (truncated)
- Three buttons: Approve (green), Always Allow (cyan), Deny (red)
- Uses CLITheme colors
- Animated transitions

### ChatView.swift Integration

```swift
// In statusAndInputView, after UnifiedStatusBar:
if let approval = wsManager.pendingApproval {
    ApprovalBannerView(
        request: approval,
        onApprove: { wsManager.approvePendingRequest(alwaysAllow: false) },
        onAlwaysAllow: { wsManager.approvePendingRequest(alwaysAllow: true) },
        onDeny: { wsManager.denyPendingRequest() }
    )
}
```

---

## Backend Implementation (Completed)

### Deployment

The local fork is deployed at `/home/dev/workspace/claudecodeui` on the QNAP container.

```bash
# Current pm2 configuration
DATABASE_PATH=/home/dev/.cloudcli-data/auth.db PORT=8080 pm2 start /home/dev/workspace/claudecodeui/server/cli.js --name claude-ui
```

### Key Changes Made

**1. server/claude-sdk.js** - Added `canUseTool` callback:

```javascript
// Add at top of file
const pendingPermissions = new Map();

// Helper to create deferred promise
function createDeferredPromise() {
    let resolve, reject;
    const promise = new Promise((res, rej) => {
        resolve = res;
        reject = rej;
    });
    return { promise, resolve, reject };
}

// In queryClaudeSDK function, modify the query call:
const queryInstance = query({
    prompt: finalCommand,
    options: {
        ...sdkOptions,
        canUseTool: async (toolName, input) => {
            // Skip if bypassing permissions
            if (sdkOptions.permissionMode === 'bypassPermissions') {
                return { behavior: 'allow', updatedInput: input };
            }

            const requestId = crypto.randomUUID();
            const { promise, resolve } = createDeferredPromise();

            pendingPermissions.set(requestId, { resolve, toolName, input });

            // Send permission request to client
            ws.send(JSON.stringify({
                type: 'permission-request',
                requestId,
                toolName,
                input
            }));

            // Wait for client response (5 minute timeout)
            try {
                const response = await Promise.race([
                    promise,
                    new Promise((_, reject) =>
                        setTimeout(() => reject(new Error('Permission timeout')), 300000)
                    )
                ]);

                pendingPermissions.delete(requestId);

                return response.behavior === 'allow'
                    ? { behavior: 'allow', updatedInput: input }
                    : { behavior: 'deny', message: 'User denied permission' };
            } catch (error) {
                pendingPermissions.delete(requestId);
                return { behavior: 'deny', message: error.message };
            }
        }
    }
});

// Add export for handling responses
function handlePermissionResponse(requestId, behavior, alwaysAllow) {
    const pending = pendingPermissions.get(requestId);
    if (pending) {
        pending.resolve({ behavior, alwaysAllow });
    }
}

// Export the handler
export { queryClaudeSDK, handlePermissionResponse, ... };
```

**2. server/index.js** - Added WebSocket message handler:

```javascript
// Import the handler
import { handlePermissionResponse } from './claude-sdk.js';

// In WebSocket message handler:
ws.on('message', (data) => {
    const message = JSON.parse(data);

    if (message.type === 'permission-response') {
        handlePermissionResponse(
            message.requestId,
            message.behavior,
            message.alwaysAllow || false
        );
        return;
    }

    // ... existing message handling
});
```

---

## Message Protocol

### Server → Client: Permission Request

```json
{
    "type": "permission-request",
    "requestId": "uuid-string",
    "toolName": "Bash",
    "input": {
        "command": "git status",
        "description": "Show git status"
    }
}
```

### Client → Server: Permission Response

```json
{
    "type": "permission-response",
    "requestId": "uuid-string",
    "behavior": "allow",
    "alwaysAllow": false
}
```

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| "Always Allow" scope | Session-only | Simpler, no persistence needed |
| Backend approach | Fork and customize | Full control, can merge upstream |
| Queue handling | One request at a time | Matches CLI behavior |
| Banner location | Above status bar | Visible but not intrusive |

---

## Current Debugging Status (2025-12-28)

### What's Done
- ✅ Backend code modified (`server/claude-sdk.js` with `canUseTool` callback)
- ✅ WebSocket handler added (`server/index.js` handles `permission-response`)
- ✅ iOS app has `ApprovalBannerView` and WebSocket handling
- ✅ Fork pushed to https://github.com/wiseyoda/claudecodeui
- ✅ pm2 running from local fork with correct cwd (`/home/dev/workspace/claudecodeui`)

### Issue Observed
When testing with bypass permissions OFF:
- Multiple `git status` tool calls appear in the iOS app
- No approval banner is shown
- Task eventually aborts with "Claude Code process exited with code 1"

### Logs Showed (before pm2 restart with correct cwd)
```
SDK query error: Error: Claude Code process exited with code 1
```
Stack traces pointed to `/usr/local/lib/node_modules/@siteboon/claude-code-ui/node_modules/` (wrong path)

### Fix Applied
- Restarted pm2 from the correct directory:
```bash
cd ~/workspace/claudecodeui && DATABASE_PATH=/home/dev/.cloudcli-data/auth.db PORT=8080 pm2 start server/cli.js --name claude-ui
```
- Verified `exec cwd` is now `/home/dev/workspace/claudecodeui`
- Cleared logs with `pm2 flush claude-ui`

### Next Steps
1. Test again with bypass permissions OFF
2. Check fresh logs for `[PERMISSION]` log entries (which indicate canUseTool is being called)
3. If no `[PERMISSION]` logs appear, the canUseTool callback may not be invoked by the SDK
4. May need to investigate SDK documentation for correct callback signature

### Debug Commands
```bash
# Check logs for permission-related entries
ssh claude-dev "pm2 logs claude-ui --lines 100 --nostream | grep -i permission"

# Watch logs in real-time
ssh claude-dev "pm2 logs claude-ui"

# Check pm2 config
ssh claude-dev "pm2 show claude-ui | grep -E 'script path|exec cwd'"
```

---

## Testing Checklist

Once debugging is complete:

- [ ] Turn OFF bypass permissions mode
- [ ] Send a message that triggers a Bash command
- [ ] Verify approval banner appears
- [ ] Test "Approve" button - command should execute
- [ ] Test "Deny" button - command should be rejected
- [ ] Test "Always Allow" - subsequent same-tool requests should auto-approve
- [ ] Verify banner disappears after action
- [ ] Test multiple rapid requests (should queue)

---

## References

- [Claude Agent SDK Permissions](https://platform.claude.com/docs/en/agent-sdk/permissions)
- [claudecodeui GitHub](https://github.com/siteboon/claudecodeui)
- Plan file: `~/.claude/plans/deep-munching-key.md`
