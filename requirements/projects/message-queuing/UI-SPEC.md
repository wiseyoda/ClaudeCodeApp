# Message Queuing UI Specification

## Design Principles

1. **Seamless**: Queuing should feel like a natural extension of sending
2. **Unobtrusive**: Queue panel doesn't clutter the main chat experience
3. **Informative**: User always knows what's queued and what's executing
4. **Controllable**: Easy access to cancel, reorder, edit, and prioritize

---

## Component Specifications

### 1. Input Area Changes

#### Current State (Busy)
```
┌─────────────────────────────────────────────────┐
│ [Disabled input field - grayed out]      [Send] │
└─────────────────────────────────────────────────┘
```

#### New State (Busy)
```
┌─────────────────────────────────────────────────┐
│ [Active input field - white]         [⏸ Queue] │
└─────────────────────────────────────────────────┘
```

**Changes:**
- Input field remains active when agent is busy
- Send button changes to "Queue" icon (pause/stack icon)
- Button tint changes from blue to orange when queuing

#### Urgent Mode
Long-press on Queue button reveals urgent option:

```
┌─────────────────────────────────────────────────┐
│ [Type a message...]                  [⏸ Queue] │
└─────────────────────────────────────────────────┘
                                            │
                                    ┌───────┴───────┐
                                    │ ⚡ Queue Urgent │
                                    │ ⏸ Queue Normal │
                                    └───────────────┘
```

Alternatively: Small toggle next to input field:
```
┌─────────────────────────────────────────────────┐
│ [⚡] [Type a message...]             [⏸ Queue] │
└─────────────────────────────────────────────────┘
```
- Lightning bolt toggles urgent mode
- Orange tint when urgent mode active

---

### 2. Queue Status Indicator

Small badge in the navigation area showing queue count.

#### Location: Chat Header
```
┌─────────────────────────────────────────────────┐
│ ← Session Name                    [🗂 3] [⚙️]  │
├─────────────────────────────────────────────────┤
│                                                 │
│              Chat messages...                   │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Badge Behavior:**
- Hidden when queue is empty
- Shows count: `[🗂 3]`
- Tapping opens queue panel
- Animates (pulse) when message added
- Orange tint when queue has urgent messages

---

### 3. Queue Panel

Collapsible panel between header and chat messages.

#### Collapsed State
```
┌─────────────────────────────────────────────────┐
│ ← Session Name                              ⚙️  │
├─────────────────────────────────────────────────┤
│ 📥 Queue (3)                              ▼    │
├─────────────────────────────────────────────────┤
│                                                 │
│              Chat messages...                   │
│                                                 │
└─────────────────────────────────────────────────┘
```

#### Expanded State
```
┌─────────────────────────────────────────────────┐
│ ← Session Name                              ⚙️  │
├─────────────────────────────────────────────────┤
│ 📥 Queue (3)                              ▲    │
├─────────────────────────────────────────────────┤
│ ≡ ⚡ Run the unit tests             ✏️ ✕      │
│ ≡    Fix any type errors            ✏️ ✕      │
│ ≡    Commit the changes             ✏️ ✕      │
├─────────────────────────────────────────────────┤
│           [ Clear All ]                         │
├─────────────────────────────────────────────────┤
│                                                 │
│              Chat messages...                   │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Elements:**
- `≡` - Drag handle for reordering
- `⚡` - Urgent indicator (orange lightning)
- Message preview (truncated if long)
- `✏️` - Edit button
- `✕` - Cancel/remove button
- Clear All button with destructive styling

#### Empty State
```
┌─────────────────────────────────────────────────┐
│ 📥 Queue (0)                              ▲    │
├─────────────────────────────────────────────────┤
│                                                 │
│       No messages in queue                      │
│                                                 │
│    Send messages while the agent is busy        │
│    to add them to the queue.                    │
│                                                 │
├─────────────────────────────────────────────────┤
```

---

### 4. Queued Message Row

#### Normal Message
```
┌─────────────────────────────────────────────────┐
│ ≡  Run the unit tests and fix any f...  ✏️  ✕ │
│    📷                                    2m ago │
└─────────────────────────────────────────────────┘
```

#### Urgent Message
```
┌─────────────────────────────────────────────────┐
│ ≡ ⚡ Deploy to production immediately   ✏️  ✕ │
│                                          1m ago │
└─────────────────────────────────────────────────┘
```
- Orange left border
- Lightning bolt icon

#### Currently Executing
```
┌─────────────────────────────────────────────────┐
│ ▶  Running the tests...                        │
│    ████████████░░░░░░░░                        │
└─────────────────────────────────────────────────┘
```
- Indeterminate progress bar
- No edit/cancel buttons while executing
- Animated pulse effect

#### Failed Message
```
┌─────────────────────────────────────────────────┐
│ ⚠️  Run the tests                       ✏️  ✕ │
│    Error: Connection lost                       │
│    [ Retry ] [ Skip ]                          │
└─────────────────────────────────────────────────┘
```
- Red left border
- Error message displayed
- Retry and Skip action buttons

---

### 5. Edit Message Sheet

Modal sheet for editing queued message content.

```
┌─────────────────────────────────────────────────┐
│ Edit Queued Message                    [Cancel] │
├─────────────────────────────────────────────────┤
│                                                 │
│ ┌─────────────────────────────────────────────┐ │
│ │ Run the unit tests and fix any failing     │ │
│ │ tests. Make sure all type checks pass.     │ │
│ │                                            │ │
│ │                                            │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│ Priority: [Normal ▼]                            │
│                                                 │
│              [ Save Changes ]                   │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Elements:**
- Multi-line text editor with current content
- Priority picker (Normal / Urgent)
- Save button (disabled if no changes)
- Cancel to dismiss without saving

---

### 6. Queue Feedback Toast

Brief toast notification when message is queued.

```
┌─────────────────────────────────────────────────┐
│              Chat messages...                   │
│                                                 │
│    ┌─────────────────────────────────┐         │
│    │ ✓ Message queued (3 in queue)   │         │
│    └─────────────────────────────────┘         │
│                                                 │
├─────────────────────────────────────────────────┤
│ [Type a message...]                  [⏸ Queue] │
└─────────────────────────────────────────────────┘
```

- Appears for 2 seconds
- Slides up from bottom
- Tapping opens queue panel

---

### 7. Queue Full Warning

Alert when trying to queue beyond limit.

```
┌─────────────────────────────────────────────────┐
│                                                 │
│    ┌─────────────────────────────────┐         │
│    │ ⚠️ Queue Full                    │         │
│    │                                  │         │
│    │ Maximum 10 messages allowed.     │         │
│    │ Cancel a message or wait for    │         │
│    │ the queue to process.           │         │
│    │                                  │         │
│    │        [ Open Queue ]            │         │
│    │        [ OK ]                    │         │
│    └─────────────────────────────────┘         │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## Color Palette

| Element | Color | Usage |
|---------|-------|-------|
| Queue button (queuing) | Orange (#FF9500) | Indicates queue mode |
| Urgent indicator | Orange (#FF9500) | Lightning bolt, border |
| Failed message | Red (#FF3B30) | Error border, icon |
| Executing message | Blue (#007AFF) | Progress indicator |
| Normal text | Primary label | Message content |
| Secondary text | Secondary label | Timestamps, hints |

---

## Animations

### Message Queued
1. Input clears with fade
2. Toast slides up (0.3s ease-out)
3. Queue badge pulses once
4. Haptic: light impact

### Queue Expanded/Collapsed
1. Chevron rotates 180°
2. Panel height animates (0.25s ease-in-out)
3. Message rows fade in staggered (0.05s each)

### Message Reorder
1. Dragged row elevates (shadow)
2. Other rows shift with spring animation
3. Drop with settle bounce

### Execution Start
1. Row background pulses blue
2. Progress bar appears
3. Haptic: medium impact

### Execution Complete
1. Row slides out left
2. Next row slides up
3. Badge count decrements
4. Haptic: success notification

### Execution Failed
1. Row shakes briefly
2. Error appears with fade
3. Red border animates in
4. Haptic: error notification

---

## Accessibility

### VoiceOver Labels

| Element | Label |
|---------|-------|
| Queue button | "Queue message" / "Send message" (context-dependent) |
| Queue badge | "Queue, 3 messages pending" |
| Queue panel | "Message queue, 3 messages" |
| Message row | "Queued message: [content], [priority], queued [time] ago" |
| Drag handle | "Reorder, drag to change position" |
| Edit button | "Edit message" |
| Cancel button | "Remove from queue" |
| Urgent toggle | "Mark as urgent" / "Mark as normal" |

### Alternative Reorder

For users who can't drag, provide context menu:

```
┌─────────────────────────────────────────────────┐
│ ≡  Run the unit tests                   ✏️  ✕ │
│                              ┌─────────────────┐ │
│                              │ ⬆️ Move Up      │ │
│                              │ ⬇️ Move Down    │ │
│                              │ ⚡ Make Urgent   │ │
│                              │ ✏️ Edit         │ │
│                              │ ✕  Remove       │ │
│                              └─────────────────┘ │
└─────────────────────────────────────────────────┘
```

---

## Settings Integration

Add to Settings sheet:

```
┌─────────────────────────────────────────────────┐
│ Message Queue                                   │
├─────────────────────────────────────────────────┤
│ Maximum queue size              [10 ▼]          │
│ Show queue panel by default     [Toggle Off]    │
│ Haptic feedback                 [Toggle On]     │
└─────────────────────────────────────────────────┘
```

**Options:**
- Max queue size: Picker (5, 10, 15, 20)
- Show queue panel: Auto-expand when messages queued
- Haptic feedback: Enable/disable queue haptics

---

## Edge Cases

### Queue Panel While Scrolling
- Panel stays fixed at top
- Chat content scrolls beneath
- Panel casts subtle shadow over content

### Very Long Message in Queue
- Truncate to 2 lines with ellipsis
- Full content visible in edit sheet
- VoiceOver reads full content

### Multiple Sessions
- Each session has independent queue
- Switching sessions loads that session's queue
- Badge shows current session's count only

### App Backgrounded
- Queue persists to disk
- Processing pauses (connection disconnects)
- Resumes on foreground

### Rapid Queuing
- Each message gets unique position
- No duplicate prevention (user might want duplicates)
- Toast shows updated count each time
