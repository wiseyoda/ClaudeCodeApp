# Critical Orphaned Features (Major Functionality at Risk)


### 1. Status Message Collection System - NEED!

**Files:**

- `Managers/StatusMessageStore.swift` (57,670 bytes)
- `Views/MessageCollectionView.swift`
- `Models/StatusMessage.swift`

**What it does:**

- Gamified status messages with rarity tiers (common/uncommon/rare/legendary)
- Collection progress tracking with progress bars per rarity
- Time-of-day filtering (morning/afternoon/evening messages)
- Seasonal variants
- Users can "collect" fun pop-culture messages shown during processing

**Risk:** Significant engagement feature with NO mention anywhere in ui-redesign.

**Decision:** Keep full system. Surface as a status banner above the input bar (visible only while streaming). Collection access lives in Settings (not from the banner).

---

### 2. Tab-Based Navigation (iPhone) vs. Sidebar Architecture - NEED!

**Files:**

- `Views/MainTabView.swift`
- `Views/HomeView.swift`

**What it does:**

- 5-tab navigation: Home, Terminal, New Project (+), Commands, Settings
- 2-column glass card grid on iPhone HomeView
- iPhone-specific UX pattern

**Risk:** The redesign replaces this with NavigationSplitView sidebar. No migration plan for iPhone-specific tab experience or HomeView card grid layout.

**Decision:** Use iOS 26.2 Liquid Glass best-practice iPhone navigation with a TabView for primary sections and a simplified Home/Projects surface. Move "New Project" to a prominent primary action (not a tab). Keep NavigationSplitView for iPad.

---

### 3. StatusBubbleView - Animated Processing Indicator - NEED!

**File:** `Views/StatusBubbleView.swift` (11,795 bytes)

**What it does:**

- Shimmer text animation effect (StatusShimmerModifier)
- Rotating fun messages with typewriter-style animated ellipsis
- Elapsed time display (shows after 10 seconds)
- Tool-colored accents based on active tool type
- AnimatedEllipsis component

**Risk:** Issue #26's StatusBarView is a simple static bar with no animations, shimmer, or fun messages.

**Decision:** Preserve animations and fun messages (part of the collection system).

---

### 4. Message Grouping/Compaction System - NEED!

**Files:**

- `Views/CompactToolView.swift` (33,065 bytes)
- `Views/ToolContentView.swift` (8,953 bytes)
- `Views/ToolParser.swift` (18,369 bytes)

**What it does:**

- Groups consecutive Read/Glob/Grep operations into single "Explored Files" display
- Terminal commands with expandable summary + full output on tap
- Web search results with collapsible list and clickable links
- File exploration grouping with error indicators

**Risk:** Issue #05 (ToolCardView) mentions tool-specific rendering but NOT the intelligent grouping/compaction logic that reduces message clutter.

**Decision:** Core behavior. Preserve grouping/compaction and integrate with tool-specific rendering.

---

### 5. WritePreviewView - NEED!

**File:** `Views/WritePreviewView.swift` (8,539 bytes)

**What it does:**

- Specialized preview for Write tool output
- Line numbers
- Indentation normalization
- 8-line preview with expand button

**Risk:** Issue #05 says "Read/Write show code blocks" but no mention of this specialized preview.

**Decision:** Reuse shared code with an extendable component. Expand should open a full-screen viewer.

---
