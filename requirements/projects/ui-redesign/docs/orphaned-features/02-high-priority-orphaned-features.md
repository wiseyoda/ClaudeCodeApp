# High Priority Orphaned Features


### 6. GitStatusCoordinator - REMOVE (CLI-BRIDGE SHOULD HANDLE GIT STATUS)

**File:** `Managers/GitStatusCoordinator.swift` (11,144 bytes)

**What it does:**

- Multi-repo git status checking
- Intermediate `.checking` state visualization
- Coordinated refresh across all repos in a project

**Decision:** Remove client-side git status. Use cli-bridge status only. Display branch/dirty/ahead-behind/conflicts when available; "unknown" is acceptable until reported.

---

### 7. LocalCommand System - NEED!

**Files:**

- `Models/LocalCommand.swift` (5,097 bytes)
- Logic in `ViewModels/ChatViewModel+SlashCommands.swift`

**What it does:**

- Client-side slash commands that execute locally (not sent to Claude):
  - `/exit`, `/clear`, `/compact`, `/bump`, `/agents`
  - `/usage`, `/mcp`, `/model`, `/resume`, `/init`
  - `/help`, `/doctor`, `/stats`, `/login`, `/theme`, `/plugin`
- `localCommand` and `localCommandStdout` message roles

**Decision:** Keep and enhance. Add a command palette with autocomplete (especially for iPad hardware keyboard). Allow iPhone-specific handling. Display results as system cards.

---

### 8. SystemMessage Types - NEED!

**File:** `Models/SystemMessage.swift` (7,838 bytes)

**What it does:**

- System message subtypes with metadata:
  - `stop_hook_summary`
  - `compact_boundary`
  - `local_command`
  - `api_error`
  - `unknown`

**Decision:** Follow iOS 26.2 best-practice patterns with differentiated rendering. Map types to UI:
- `stop_hook_summary`: collapsible summary card
- `compact_boundary`: compact divider
- `local_command`: local output card
- `api_error`: distinct error card
- `unknown`: fallback system card

---

### 9. OfflineActionQueue - NEED!

**File:** `Managers/OfflineActionQueue.swift` (4,706 bytes)

**What it does:**

- Queues approval actions when offline
- JSON persistence for later processing
- Sync when connectivity returns

**Decision:** Favor cli-bridge replay/timeout behavior; keep client-side handling lightweight. If offline, replay to last state and prompt only when user input is needed. If too long, show cli-bridge timeout message. Note: Firebase integration is planned after redesign; do not build Firebase-specific logic now.

---

### 10. HapticManager (Centralized) - NEED!

**File:** `Utilities/HapticManager.swift` (1,965 bytes)

**What it does:**

- Centralized haptic feedback system
- Impact variants: light, medium, heavy, rigid, soft
- Notification types: success, warning, error
- Selection feedback

**Decision:** Follow iOS 26.2 best-practice haptics. Keep a centralized manager with a global toggle in Settings.

---
