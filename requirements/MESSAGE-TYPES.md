# Message Types & UI Flow

Reference for cli-bridge message types and how CodingBridge should render them.

## Source of Truth

- **Claude Agent SDK (Python)**: https://platform.claude.com/docs/en/agent-sdk/python
- This document aligns with the official SDK message types

---

## Message Types

### High-Level Message Union

```
Message = UserMessage | AssistantMessage | SystemMessage | ResultMessage
```

### Content Block Union

```
ContentBlock = TextBlock | ThinkingBlock | ToolUseBlock | ToolResultBlock
```

---

## Content Block Schemas

### TextBlock

```json
{
  "text": "Hello! I'm Claude..."
}
```

### ThinkingBlock

```json
{
  "thinking": "Let me analyze this...",
  "signature": "..."
}
```

### ToolUseBlock

```json
{
  "id": "toolu_019gFKyx8H6EFEiv1GByCLke",
  "name": "Bash",
  "input": {
    "command": "git log -2 --oneline",
    "description": "Show the last 2 commits"
  }
}
```

### ToolResultBlock

```json
{
  "tool_use_id": "toolu_019gFKyx8H6EFEiv1GByCLke",
  "content": "41f4090 fix: inline StreamMessage...",
  "is_error": false
}
```

**Note**: Match `tool_use_id` to `ToolUseBlock.id` to correlate results with their tool calls.

---

## State Messages

State messages drive UI animations. They come as stream messages with type `state`.

### States

| State       | Tool Field | Meaning                |
| ----------- | ---------- | ---------------------- |
| `executing` | (none)     | Preparing to process   |
| `thinking`  | (none)     | Claude is thinking     |
| `executing` | `"Bash"`   | Running a Bash command |
| `executing` | `"Read"`   | Reading a file         |
| `executing` | `"Write"`  | Writing a file         |
| `executing` | `"Grep"`   | Searching code         |
| `executing` | `"Glob"`   | Finding files          |
| `executing` | `"Edit"`   | Editing a file         |
| `executing` | `"Task"`   | Running a subagent     |
| `idle`      | (none)     | Ready for input        |

### State Message Format

```json
{
  "type": "stream",
  "message": {
    "type": "state",
    "state": "executing",
    "tool": "Bash"
  }
}
```

---

## Stream Message Types

### Assistant Message (Streaming)

**Delta (partial) - SKIP THESE:**

```json
{
  "type": "assistant",
  "content": "I'll check",
  "delta": true
}
```

**Complete - RENDER THESE:**

```json
{
  "type": "assistant",
  "content": "I'll check the last 2 commits in your repository.",
  "delta": false
}
```

### System Messages

**Init:**

```json
{
  "type": "system",
  "content": "Session initialized with model claude-sonnet-4-5-20250929",
  "subtype": "init"
}
```

**Result:** Note: this should only be displayed if the assistant message content is different from the last assistant message content.

```json
{
  "type": "system",
  "content": "...(final response)...",
  "subtype": "result"
}
```

### Usage Message

```json
{
  "type": "usage",
  "inputTokens": 14,
  "outputTokens": 571,
  "totalCost": 0.01511175
}
```

---

## Complete Message Flow Example

```
User sends: "What did we do in the last 2 commits?"

1. state: executing              → Show "Preparing..." animation
2. system/init                   → (internal, don't display)
3. state: thinking               → Show "Thinking..." animation
4. assistant (delta=true) x N    → SKIP
5. assistant (delta=false)       → Render: "I'll check the last 2 commits..." in chat window (not status bar)
6. state: executing (tool: Bash) → Show "Running command..." animation
7. tool_use                      → Show tool card (collapsed)
8. tool_result                   → Update tool card with result
9. assistant (delta=true) x N    → SKIP
10. assistant (delta=false)      → Render: "Now let me get more details..." in chat window (not status bar)
11. state: executing (tool: Bash)→ Show "Running command..." animation
12. tool_use                     → Show tool card
13. tool_result                  → Update tool card
14. assistant (delta=true) x N   → SKIP
15. assistant (delta=false)      → Render: "## Summary of the Last 2 Commits..." in chat window (not status bar)"
16. usage                        → Update cost display
17. system/result                → Verify matches last assistant message
18. state: idle                  → Ready for input
```

---

## Real SSE Message Examples

These are actual messages captured from cli-bridge SSE streams. Use these as test fixtures.

### Connection & Session Setup

**WebSocket Connected:**
```json
{
  "type": "system",
  "message": "WebSocket connected"
}
```

**Connected Response:**
```json
{
  "type": "connected",
  "agentId": "agent_t0bxgx6g",
  "sessionId": "afb50a84-1206-4074-9784-d7552826ffaf",
  "model": "sonnet",
  "version": "0.3.2",
  "protocolVersion": "1.0"
}
```

**Model Changed:**
```json
{
  "type": "model_changed",
  "model": "haiku",
  "previousModel": "sonnet"
}
```

**Permission Mode Changed:**
```json
{
  "type": "permission_mode_changed",
  "mode": "bypassPermissions"
}
```

### State Messages

**Executing (no tool):**
```json
{
  "type": "stream",
  "message": {
    "type": "state",
    "state": "executing"
  }
}
```

**Thinking:**
```json
{
  "type": "stream",
  "message": {
    "type": "state",
    "state": "thinking"
  }
}
```

**Executing (with tool):**
```json
{
  "type": "stream",
  "message": {
    "type": "state",
    "state": "executing",
    "tool": "Bash"
  }
}
```

**Idle (may be duplicated):**
```json
{
  "type": "stream",
  "message": {
    "type": "state",
    "state": "idle"
  }
}
```

### System Messages

**Init:**
```json
{
  "type": "stream",
  "message": {
    "type": "system",
    "content": "Session initialized with model claude-haiku-4-5-20251001",
    "subtype": "init"
  }
}
```

**Result (final):**
```json
{
  "type": "stream",
  "message": {
    "type": "system",
    "content": "## Summary of the Last 2 Commits...",
    "subtype": "result"
  }
}
```

### Assistant Messages

**Delta (SKIP these):**
```json
{
  "type": "stream",
  "message": {
    "type": "assistant",
    "content": "I'll",
    "delta": true
  }
}
```

**Complete (RENDER these):**
```json
{
  "type": "stream",
  "message": {
    "type": "assistant",
    "content": "I'll check the last 2 commits in your repository.",
    "delta": false
  }
}
```

### Tool Use

**Bash:**
```json
{
  "type": "stream",
  "message": {
    "type": "tool_use",
    "id": "toolu_019gFKyx8H6EFEiv1GByCLke",
    "name": "Bash",
    "input": {
      "command": "git log -2 --oneline",
      "description": "Show the last 2 commits with their messages"
    }
  }
}
```

**Read:**
```json
{
  "type": "stream",
  "message": {
    "type": "tool_use",
    "id": "toolu_01HruYphyUQja9W8X2nLMB8U",
    "name": "Read",
    "input": {
      "file_path": "/path/to/file.swift",
      "limit": 80
    }
  }
}
```

**Grep:**
```json
{
  "type": "stream",
  "message": {
    "type": "tool_use",
    "id": "toolu_01T91BYfP7PHewUAX11JysW1",
    "name": "Grep",
    "input": {
      "pattern": "export async function|export function",
      "path": "/path/to/directory",
      "output_mode": "count"
    }
  }
}
```

### Tool Result

**Success (before v0.3.3 - tool: "unknown"):**
```json
{
  "type": "stream",
  "message": {
    "type": "tool_result",
    "id": "toolu_019gFKyx8H6EFEiv1GByCLke",
    "tool": "unknown",
    "output": "41f4090 fix: inline StreamMessage...\nd52482b release: v0.2.4...",
    "success": true,
    "isError": false
  }
}
```

**Success (v0.3.3+ - tool name correlated):**
```json
{
  "type": "stream",
  "message": {
    "type": "tool_result",
    "id": "toolu_019gFKyx8H6EFEiv1GByCLke",
    "tool": "Bash",
    "output": "41f4090 fix: inline StreamMessage...\nd52482b release: v0.2.4...",
    "success": true,
    "isError": false
  }
}
```

**Error:**
```json
{
  "type": "stream",
  "message": {
    "type": "tool_result",
    "id": "toolu_xyz",
    "tool": "Bash",
    "output": "error: command not found: xyz",
    "success": false,
    "isError": true
  }
}
```

### Usage

```json
{
  "type": "stream",
  "message": {
    "type": "usage",
    "inputTokens": 14,
    "outputTokens": 571,
    "totalCost": 0.01511175
  }
}
```

### Edge Cases to Handle

1. **Duplicate `state: idle`** - cli-bridge may send idle twice at end of turn
2. **`system/result` duplicates `assistant`** - skip if content identical
3. **`tool: "unknown"` on older versions** - fallback gracefully
4. **Long tool output** - truncate in display, full content available on expand

---

## UI State Mapping

### State Animation (Inline Chat Bubble)

Display as an inline chat bubble at the bottom of messages (like iMessage typing indicator).
Use **animated SF Symbols** and **rotating messages** for personality.

| State                     | Icon (SF Symbol)               | Animation                       |
| ------------------------- | ------------------------------ | ------------------------------- |
| `executing` (no tool)     | `hourglass`                    | `.symbolEffect(.variableColor)` |
| `thinking`                | `brain.head.profile`           | `.symbolEffect(.pulse)`         |
| `executing` + `Bash`      | `terminal`                     | `.symbolEffect(.variableColor)` |
| `executing` + `Read`      | `doc.text`                     | `.symbolEffect(.pulse)`         |
| `executing` + `Write`     | `pencil`                       | `.symbolEffect(.bounce)`        |
| `executing` + `Edit`      | `pencil.line`                  | `.symbolEffect(.bounce)`        |
| `executing` + `Grep`      | `magnifyingglass`              | `.symbolEffect(.pulse)`         |
| `executing` + `Glob`      | `folder.badge.magnifyingglass` | `.symbolEffect(.pulse)`         |
| `executing` + `Task`      | `person.2`                     | `.symbolEffect(.variableColor)` |
| `executing` + `WebFetch`  | `globe`                        | `.symbolEffect(.pulse)`         |
| `executing` + `WebSearch` | `globe.magnifyingglass`        | `.symbolEffect(.pulse)`         |
| `idle`                    | None                           | None                            |

### Animation Specification

**Ellipsis: Typing Animation**

- Dots cycle: "." → ".." → "..." → "...." → "." (repeat)
- Base interval: ~400ms per step
- Randomization: ±50ms jitter for organic feel
- Replace trailing "..." in message text with animated ellipsis

```swift
// Animated ellipsis view
struct AnimatedEllipsis: View {
    @State private var dotCount = 1

    private let timer = Timer.publish(
        every: 0.4,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {
        Text(String(repeating: ".", count: dotCount))
            .onReceive(timer) { _ in
                // Add slight randomness: 350-450ms effective interval
                let jitter = Double.random(in: -0.05...0.05)
                DispatchQueue.main.asyncAfter(deadline: .now() + jitter) {
                    dotCount = (dotCount % 4) + 1
                }
            }
    }
}

// Usage in status message
struct StatusMessageView: View {
    let baseText: String  // e.g., "💭 Thinking"

    var body: some View {
        HStack(spacing: 0) {
            Text(baseText)
            AnimatedEllipsis()
        }
    }
}
```

**Text: Shimmer Effect**

- Gradient highlight sweeps left-to-right across text
- Duration: 1.5s loop, continuous while waiting
- Colors: Clear → White(0.4 opacity) → Clear
- Width: ~80pt gradient band

```swift
// Shimmer modifier using animated gradient mask
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -100

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.4), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 80)
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 250
                }
            }
    }
}
```

**Emoji: Gentle Pulse**

- Scale: 1.0 → 1.08 → 1.0
- Duration: 2s cycle, ease-in-out
- Subtle "breathing" effect, not distracting

```swift
@State private var isPulsing = false

Text(emoji)
    .scaleEffect(isPulsing ? 1.08 : 1.0)
    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
    .onAppear { isPulsing = true }
```

**Message Transitions**

- Text crossfades (0.3s) when message rotates
- Emoji does single subtle bounce on change, then resumes pulse
- Rotation interval: 4-5 seconds (randomize slightly for organic feel)

**Elapsed Time**

- Appears after 10 seconds: "🧠 Thinking... (12s)"
- Updates every second
- Positioned at end of message

### Message Rarity System

Messages have rarity tiers that affect how often they appear. Rarer messages feel special when you see them.

| Rarity    | Weight | Color (Settings) | Description                    |
| --------- | ------ | ---------------- | ------------------------------ |
| Common    | 60%    | Gray             | Basic, everyday messages       |
| Uncommon  | 26%    | Green            | Fun, slightly quirky           |
| Rare      | 14%    | Blue             | Pop culture, clever references |
| Legendary | 1%     | Purple/Gold      | Deep cuts, Easter eggs         |

**Data Model:**

```swift
struct StatusMessage: Codable, Identifiable {
    let id: String
    let text: String
    let emoji: String
    let rarity: Rarity
    let category: Category      // thinking, executing, bash, read, etc.
    let timeOfDay: TimeOfDay?   // nil = any time
    let seasonal: Season?       // nil = year-round
    var seen: Bool = false      // Track if user has seen this

    enum Rarity: String, Codable {
        case common, uncommon, rare, legendary

        var weight: Double {
            switch self {
            case .common: return 0.60
            case .uncommon: return 0.25
            case .rare: return 0.12
            case .legendary: return 0.03
            }
        }
    }

    enum TimeOfDay: String, Codable {
        case morning    // 5am - 12pm
        case afternoon  // 12pm - 5pm
        case evening    // 5pm - 9pm
        case night      // 9pm - 5am
        case weekend    // Sat/Sun any time
    }

    enum Season: String, Codable {
        case spring, summer, fall, winter
        case halloween  // Oct 15 - Nov 1
        case christmas  // Dec 15 - Dec 26
        case newYear    // Dec 31 - Jan 2
        case valentine  // Feb 13 - Feb 15
    }
}
```

**Selection Algorithm:**

```swift
func selectMessage(for state: State, tool: String?) -> StatusMessage {
    let pool = messages
        .filter { $0.category == state.category(tool: tool) }
        .filter { $0.timeOfDay == nil || $0.timeOfDay == currentTimeOfDay }
        .filter { $0.seasonal == nil || $0.seasonal == currentSeason }

    // Weighted random selection by rarity
    return weightedRandom(pool, by: \.rarity.weight)
}
```

**Settings UI - Collection Progress:**

```
📊 Message Collection
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Common:    45/52  ████████████░░ 87%
Uncommon:  23/38  ███████░░░░░░░ 61%
Rare:      12/45  ███░░░░░░░░░░░ 27%
Legendary:  2/15  █░░░░░░░░░░░░░ 13%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total: 82/150 (55%)

[View All Messages]  [Reset Progress]
```

### Time-of-Day Messages (MVP)

These inject automatically based on current time:

```swift
// Morning (5am - 12pm)
let morningMessages = [
    ("☀️", "Good morning! Let's code...", .uncommon),
    ("☕", "Coffee and code...", .common),
    ("🌅", "Early bird gets the merge...", .rare),
    ("🐓", "Rise and shine, developer...", .uncommon),
]

// Afternoon (12pm - 5pm)
let afternoonMessages = [
    ("🌤️", "Afternoon productivity...", .common),
    ("🍽️", "Post-lunch coding...", .uncommon),
    ("⚡", "Peak hours...", .common),
]

// Evening (5pm - 9pm)
let eveningMessages = [
    ("🌆", "Evening session...", .common),
    ("🍕", "Dinner break soon?", .uncommon),
    ("🌇", "Golden hour coding...", .rare),
]

// Night (9pm - 5am)
let nightMessages = [
    ("🌙", "Burning the midnight oil...", .common),
    ("🦉", "Night owl mode...", .uncommon),
    ("⭐", "Stars are out, code flows...", .rare),
    ("🌌", "3am thoughts hit different...", .legendary),  // Only 12am-4am
    ("😴", "Sleep is for the weak...", .rare),
]

// Weekend
let weekendMessages = [
    ("🎮", "Weekend warrior...", .common),
    ("🏠", "Side project time?", .uncommon),
    ("🎉", "TGIF vibes...", .uncommon),  // Friday only
    ("😎", "No meetings today...", .rare),
]
```

### Seasonal Messages (MVP)

Unlocked during specific date ranges:

```swift
// Halloween (Oct 15 - Nov 1)
let halloweenMessages = [
    ("👻", "Boo! Ready to haunt bugs...", .uncommon),
    ("🎃", "Spooky season coding...", .common),
    ("🦇", "Something wicked this way compiles...", .rare),
    ("💀", "Skeleton code? Refactor it...", .legendary),
    ("🕷️", "Web development... get it?", .rare),
]

// Christmas (Dec 15 - Dec 26)
let christmasMessages = [
    ("🎄", "Ho ho ho, let's go...", .common),
    ("🎅", "Making a list, checking it twice...", .uncommon),
    ("❄️", "Let it snow, let it flow...", .rare),
    ("🎁", "The gift of clean code...", .uncommon),
    ("🦌", "Dashing through the code...", .legendary),
]

// New Year (Dec 31 - Jan 2)
let newYearMessages = [
    ("🎆", "New year, new codebase...", .common),
    ("🥂", "Cheers to no bugs...", .uncommon),
    ("🎊", "Fresh start...", .common),
    ("✨", "Resolution: write tests...", .rare),
]

// Valentine (Feb 13 - Feb 15)
let valentineMessages = [
    ("💕", "Code is my valentine...", .uncommon),
    ("💝", "Lovely syntax...", .rare),
    ("🌹", "Roses are red, builds are green...", .legendary),
]
```

### Rotating Status Messages

Each state has a pool of messages that rotate randomly to keep the UI fresh and fun.

**Thinking State:**

```swift
let thinkingMessages = [
    // Classic
    "💭 Thinking...",
    "🧠 Processing...",
    "🤔 Pondering...",
    "💡 Having ideas...",
    "🎯 Focusing...",
    "🔍 Analyzing...",

    // Mystical
    "🔮 Consulting the oracle...",
    "✨ Channeling wisdom...",
    "🌙 Meditating on it...",
    "🧙 Casting brain spells...",
    "🎱 Asking the magic 8-ball...",

    // Cozy
    "☕ Brewing thoughts...",
    "🍵 Steeping ideas...",
    "😴 Power napping...",
    "🛁 Thinking in the shower...",

    // Nerdy
    "⚡ Neurons firing...",
    "🧬 DNA sequencing thoughts...",
    "📊 Running simulations...",
    "🔬 Hypothesis forming...",
    "🤓 Pushing up glasses...",

    // Playful
    "🎨 Getting creative...",
    "🧩 Piecing it together...",
    "🌀 In the zone...",
    "🎪 Juggling concepts...",
    "🎭 Method acting as a developer...",

    // Food
    "🍳 Cooking up a solution...",
    "🥗 Tossing ideas around...",
    "🍕 Ordering pizza... wait, thinking...",

    // Dramatic
    "🎬 Dramatic pause...",
    "📜 Consulting ancient scrolls...",
    "🏛️ Asking the philosophers...",
    "🌌 Contemplating the universe...",

    // Honest
    "🐌 Still thinking...",
    "🦥 Taking my time...",
    "🫠 Brain is braining...",
    "💆 Mental gymnastics...",

    // Pop Culture
    "🧙 You shall not pass... yet...",           // LOTR
    "⚔️ Winter is coming... for this bug...",    // GoT
    "🪄 Accio solution...",                       // Harry Potter
    "🔮 The prophecy speaks...",                  // Matrix vibes
    "🌌 These aren't the bugs you're looking for...", // Star Wars
    "🦸 That's my secret, I'm always thinking...", // Avengers
    "💊 Taking the red pill...",                  // Matrix
    "🧝 Speaking friend and entering...",         // LOTR
    "⚡ Great Scott! I've got it!",               // Back to the Future
    "🎭 Here's looking at you, code...",          // Casablanca
    "🌀 We need to go deeper...",                 // Inception
    "🚀 To infinity and beyond... my context...", // Toy Story
    "🕷️ My spidey sense is tingling...",         // Spider-Man
    "🧊 Let it go, let it flow...",               // Frozen (sorry)
    "🎯 I am one with the code...",               // Rogue One
]
```

**Executing State (no tool):**

```swift
let executingMessages = [
    "⏳ Preparing...",
    "🚀 Warming up engines...",
    "🔧 Getting ready...",
    "⚙️ Initializing...",
    "🎬 Setting the stage...",
    "🏃 On it...",
    "📋 Checking the plan...",
    "🎪 Spinning up...",
    "🔌 Plugging things in...",
    "🎯 Locking on target...",
    "🏁 At the starting line...",
    "🎸 Tuning up...",
    "🧹 Sweeping the runway...",
    "☕ One sec, coffee break...",
    "🤸 Stretching first...",

    // Pop Culture
    "🚗 Roads? Where we're going...",            // Back to the Future
    "⚔️ And my axe!",                            // LOTR
    "🎬 Alright alright alright...",             // Dazed and Confused
    "🦖 Hold onto your butts...",                // Jurassic Park
    "🎰 Never tell me the odds...",              // Star Wars
    "🥊 Let's get ready to rumble...",           // Boxing
    "🏎️ I live my life a quarter mile at a time...", // Fast & Furious
]
```

**Bash (Terminal Commands):**

```swift
let bashMessages = [
    // Classic
    "💻 Running command...",
    "🖥️ Executing...",
    "⚡ Terminal time...",

    // Hacker vibes
    "🎮 sudo make it happen...",
    "👨‍💻 Hacking the mainframe...",
    "🕶️ I'm in...",
    "💀 rm -rf doubts...",
    "🔓 Access granted...",
    "📟 Beep boop...",

    // Dramatic
    "🎬 Running the script...",
    "🚂 Chugging along...",
    "⚙️ Gears turning...",
    "🔨 Hammering away...",

    // Playful
    "🐚 Shell yeah...",
    "🦾 Flexing terminal muscles...",
    "🎰 Pulling the lever...",
    "🎯 Firing command...",
    "🏎️ Vroom vroom...",

    // Honest
    "🤞 Fingers crossed...",
    "🙏 Please work...",
    "🎲 Rolling the dice...",
    "😅 Here goes nothing...",

    // Pop Culture
    "🕶️ I know kung fu...",                      // Matrix
    "💻 It's a Unix system, I know this!",       // Jurassic Park
    "🔴 Open the pod bay doors...",              // 2001
    "🤖 I'll be back... with results...",        // Terminator
    "🎮 All your base are belong to us...",      // Zero Wing
    "📺 PC LOAD LETTER?!",                       // Office Space
    "🔧 Have you tried turning it off and on?",  // IT Crowd
    "💾 It's not a bug, it's a feature...",      // Dev life
    "🎯 Execute Order 66...",                    // Star Wars
    "⚡ With great power comes great output...", // Spider-Man
    "🚀 Punch it, Chewie!",                      // Star Wars
    "🧙 Fly, you fools! (to the terminal)",      // LOTR
]
```

**Read (File Reading):**

```swift
let readMessages = [
    // Classic
    "📖 Reading...",
    "👀 Taking a look...",
    "📂 Exploring...",

    // Scholarly
    "🤓 Studying the archives...",
    "📚 Hitting the books...",
    "🔍 Examining closely...",
    "📜 Unrolling the scrolls...",
    "🧐 Inspecting...",

    // Casual
    "👁️ Peeking...",
    "🔦 Shining a light...",
    "🗂️ Rifling through...",
    "📑 Flipping pages...",

    // Playful
    "🕵️ Snooping around...",
    "🔎 CSI: Codebase...",
    "🐛 Bug hunting...",
    "🗺️ Following the map...",
    "🧭 Navigating...",

    // Dramatic
    "📡 Scanning...",
    "🛸 Probing files...",
    "🔬 Under the microscope...",

    // Pop Culture
    "📜 The sacred texts!",                       // Star Wars
    "🧙 The ring went here? Let me see...",       // LOTR
    "📖 It's leviOsa, not levioSA...",            // Harry Potter
    "🗺️ X marks the spot...",                    // Indiana Jones
    "👀 Enhance... enhance... enhance...",        // Every cop show ever
    "🔍 Elementary, my dear Watson...",           // Sherlock
    "📚 The truth is out there...",               // X-Files
    "🎭 Frankly my dear, let me read this...",    // Gone with the Wind
    "📂 You want the truth? You can't handle...", // A Few Good Men
    "🧝 What does my elf eyes see...",            // LOTR
    "🔮 The Mirror of Erised shows...",           // Harry Potter
]
```

**Edit/Write (File Modifications):**

```swift
let editMessages = [
    // Classic
    "✏️ Editing...",
    "📝 Writing...",
    "🔧 Making changes...",

    // Artistic
    "🎨 Painting with code...",
    "💅 Polishing...",
    "✨ Sprinkling magic...",
    "🖌️ Adding brushstrokes...",
    "🎭 Rewriting the script...",

    // Construction
    "🔨 Hammering away...",
    "🏗️ Under construction...",
    "🧱 Building...",
    "⚒️ Forging ahead...",

    // Surgical
    "🔪 Surgical precision...",
    "💉 Injecting code...",
    "🩹 Applying patches...",
    "🧬 Splicing...",

    // Playful
    "🪄 Abracadabra...",
    "🎯 Tweaking...",
    "🎹 Composing...",
    "🧵 Threading the needle...",
    "🍳 Cooking up changes...",

    // Honest
    "🤞 Hopefully not breaking things...",
    "😬 Touching production code...",
    "🎲 YOLO editing...",

    // Pop Culture
    "🧙 You have no power here... wait, I do...",  // LOTR
    "⚔️ I am altering the code. Pray I don't alter it further...", // Star Wars
    "🔮 Obliviate! (the old code)...",             // Harry Potter
    "🦸 I can do this all day...",                 // Captain America
    "🎭 After all, tomorrow is another deploy...", // Gone with the Wind
    "💀 Say 'refactor' again, I dare you...",      // Pulp Fiction
    "🌊 There can be only one (version)...",       // Highlander
    "⚡ It's alive! IT'S ALIVE!",                  // Frankenstein
    "🎯 I am inevitable (these changes)...",       // Thanos
    "🧬 Life, uh, finds a way... to compile...",   // Jurassic Park
    "🔧 We can rebuild it. Better. Stronger...",   // Six Million Dollar Man
    "🎪 You're gonna need a bigger function...",   // Jaws
]
```

**Search (Grep/Glob):**

```swift
let searchMessages = [
    // Classic
    "🔎 Searching...",
    "🔍 Looking...",
    "🗺️ Exploring...",

    // Detective
    "🕵️ Investigating...",
    "🔦 On the trail...",
    "🐕 Sniffing around...",
    "👣 Following footprints...",
    "🧩 Connecting dots...",

    // Adventure
    "🏴‍☠️ Treasure hunting...",
    "🧭 Navigating...",
    "⛏️ Mining for gold...",
    "🎣 Fishing for matches...",
    "🌋 Excavating...",

    // Tech
    "📡 Scanning frequencies...",
    "🛰️ Satellite sweep...",
    "📊 Pattern matching...",
    "🧲 Attracting results...",

    // Playful
    "👀 Where are you...",
    "🙈 Peek-a-boo...",
    "🎯 Target acquired... maybe...",
    "🔮 Divining the location...",
    "🦅 Eagle eye mode...",

    // Pop Culture
    "💍 My precious... where is it...",           // LOTR
    "🌌 These aren't the files you're looking for...", // Star Wars
    "🗺️ We named the dog Indiana...",             // Last Crusade
    "🔦 It belongs in a museum!",                  // Indiana Jones
    "🕵️ The name's Grep. James Grep...",          // Bond
    "🧭 Second star to the right...",              // Peter Pan
    "🎭 Here's Johnny! (found it)...",             // The Shining
    "🔍 Where's Waldo? More like where's code...", // Where's Waldo
    "🦁 Simba, look harder...",                    // Lion King
    "🧙 I'm going on an adventure!",               // The Hobbit
    "🎯 There is no try, only find...",            // Star Wars
    "🌊 Just keep searching, just keep searching...", // Finding Nemo
]
```

**Web (WebFetch/WebSearch):**

```swift
let webMessages = [
    // Classic
    "🌐 Fetching...",
    "📡 Reaching out...",
    "🕸️ Surfing the web...",

    // Adventure
    "🏄 Riding the waves...",
    "🚀 Launching request...",
    "🎣 Casting the net...",
    "⚓ Dropping anchor...",

    // Communication
    "📞 Calling the internet...",
    "💌 Sending a postcard...",
    "🐦 Tweeting at servers...",
    "📬 Checking the mailbox...",

    // Dramatic
    "🌊 Diving into the web...",
    "🕳️ Down the rabbit hole...",
    "🚪 Knocking on ports...",
    "🔓 Opening connections...",

    // Playful
    "🐙 Reaching out tentacles...",
    "🦑 Grabbing data...",
    "🎰 Querying the cloud gods...",
    "☁️ Asking the cloud...",
    "🌈 Following the URL rainbow...",

    // Honest
    "⏳ Waiting for response...",
    "🙄 Internet, please...",
    "🤞 Hope it's not a 404...",

    // Pop Culture
    "🐇 Follow the white rabbit...",              // Matrix
    "🌐 Welcome to the World Wide Web, Neo...",   // Matrix
    "📡 E.T. phone home...",                      // E.T.
    "🚀 Beam me up, Scotty...",                   // Star Trek
    "💌 You've got mail!",                        // You've Got Mail
    "🕸️ With great bandwidth comes great...",    // Spider-Man
    "🎭 Go ahead, make my request...",            // Dirty Harry
    "🌊 Release the packets!",                    // Clash of Titans
    "🔌 I'm jacked in...",                        // Johnny Mnemonic
    "📺 Live long and prosper, dear server...",   // Star Trek
    "🛸 Take me to your server...",               // Aliens trope
    "🎰 Shall we play a game?",                   // WarGames
]
```

**Agent (Task/Subagent):**

```swift
let agentMessages = [
    // Classic
    "🤖 Agent working...",
    "👥 Delegating...",
    "🔄 Processing...",

    // Spy themed
    "🕵️ Agent deployed...",
    "🎯 Mission in progress...",
    "📋 Briefing complete...",
    "🔐 Operation underway...",
    "🥷 Ninja mode activated...",

    // Team themed
    "👷 Calling in backup...",
    "🦸 Hero summoned...",
    "🤝 Teamwork time...",
    "📣 Rallying the troops...",
    "🎪 Bringing in specialists...",

    // Robot themed
    "🦾 Deploying minion...",
    "🔩 Assembling helper...",
    "⚡ Powering up clone...",
    "🛠️ Bot activated...",

    // Playful
    "🐜 Worker ant dispatched...",
    "🐝 Busy bee buzzing...",
    "🎭 Understudy on stage...",
    "🪆 Opening the nesting doll...",
    "🎮 Player 2 has entered...",

    // Honest
    "💼 Outsourcing this one...",
    "🏃 Running errands...",
    "📤 Passing the buck...",

    // Pop Culture
    "🦸 Avengers, assemble!",                     // Avengers
    "🧙 A wizard is never late...",               // LOTR
    "🤖 Autobots, roll out!",                     // Transformers
    "🎯 I volunteer as tribute!",                 // Hunger Games
    "⚔️ For Frodo!",                              // LOTR
    "🦇 I'm Batman. (sending Robin)...",          // Batman
    "🕷️ Get me pictures of Spider-Man!",         // J. Jonah Jameson
    "🎭 Release the Kraken! (subagent)...",       // Clash of Titans
    "🧬 Clever girl... (agent)...",               // Jurassic Park
    "🌟 Use the Force, young padawan...",         // Star Wars
    "🎪 Send in the clones!",                     // Star Wars
    "🦁 Mufasa would be proud...",                // Lion King
    "👻 Who you gonna call? Subagent!",           // Ghostbusters
    "🎯 You have my sword... and my agent...",    // LOTR
    "🚀 To the Batmobile! (subagent)...",         // Batman
]
```

**Idle/Ready State (No Animation):**

```swift
let idleMessages = [
    // Classic
    "Ready for input...",
    "Awaiting your command...",
    "What's next?",
    "Standing by...",
    "At your service...",
    "Ready when you are...",
    "Go ahead, I'm listening...",

    // Encouraging
    "Let's build something...",
    "What shall we create?",
    "Ready to help...",
    "Solid progress! What's next?",
    "On a roll! Keep going...",
    "You've got this...",
    "Another victory awaits...",

    // Casual
    "Sup?",
    "Yeah?",
    "Hmm?",
    "I'm here...",
    "Still here...",
    "Whenever you're ready...",
    "No rush...",
    "Take your time...",

    // Playful
    "Feed me prompts...",
    "My keyboard awaits...",
    "Type something, I dare you...",
    "The cursor blinks patiently...",
    "Your move...",
    "Ball's in your court...",
    "Poke me with a question...",

    // Pop Culture
    "I'm ready, I'm ready!",              // SpongeBob
    "Talk to me, Goose...",               // Top Gun
    "You talkin' to me?",                 // Taxi Driver
    "As you wish...",                     // Princess Bride
    "Make it so...",                      // Star Trek TNG
    "I'll be here...",                    // Terminator
    "Bueller? Bueller?",                  // Ferris Bueller
    "Phone home?",                        // E.T.
    "What is thy bidding?",               // Star Wars
    "Your wish is my command...",         // Aladdin
    "Speak, friend, and enter...",        // LOTR
    "The Force is with you...",           // Star Wars
    "I volunteer as tribute!",            // Hunger Games
    "Witness me!",                        // Mad Max

    // Dev Humor
    "No bugs here... yet...",
    "Commit early, commit often...",
    "Ship it?",
    "Ready to refactor...",
    "git ready...",
    "Awaiting instructions.swift",
    "// TODO: your input here",
    "Console.ReadLine()...",
    "stdin awaits...",
    "Listening on port YOU...",
]
```

---

## Tool Display Specifications

Each tool type has specific display rules. These build on existing implementations where noted.

### Bash

```
┌─────────────────────────────────────┐
│ 💻 git log -2 --oneline             │
│                              [+] ▼  │
└─────────────────────────────────────┘
```

- **Command**: Always visible
- **Result**: Collapsed by default, tap [+] to expand
- **Progress**: Show elapsed time from `progress` messages: "(5s)"
- Keep current implementation, just ensure result is collapsed

### Edit / Write

```
┌─────────────────────────────────────┐
│ ✏️ src/foo.swift                    │
│ ┌─────────────────────────────────┐ │
│ │ - old line                      │ │
│ │ + new line                      │ │
│ └─────────────────────────────────┘ │
│ +5 -2 lines                         │
└─────────────────────────────────────┘
```

- **Diff view**: Keep current implementation (red/green)
- **Summary**: Show +/- line counts below diff
- **Result**: No additional collapse needed - diff IS the result

### Read / Grep / Glob (File Discovery)

```
┌─────────────────────────────────────┐
│ 📂 Explored: file1.swift,           │
│    file2.swift, file3.swift         │
└─────────────────────────────────────┘
```

- **Files**: List coalesced file names
- **Content**: HIDDEN - do not show file contents
- Simplify current implementation to remove result display

### Task (Subagent)

```
┌─────────────────────────────────────┐
│ 🤖 Agent: code-reviewer             │
│ ┌─────────────────────────────────┐ │
│ │ 📖 Read: src/auth.swift         │ │
│ │ 🔎 Grep: "validateToken"        │ │
│ │ 📖 Read: tests/authTests.swift  │ │
│ └─────────────────────────────────┘ │
│ 12 tools · 45s                      │
└─────────────────────────────────────┘
```

- **Mini chat window**: Inline in main chat, not a drawer
- **Recent activity**: Show last 3 tool calls (scrolls as new ones come in)
- **Stats footer**: Total tools used + elapsed time
- Updates in real-time as subagent works
- Collapses to summary when complete

### TodoWrite

- Use existing **drawer** implementation
- Updates todo list in real-time
- Keep current behavior

### WebFetch

```
┌─────────────────────────────────────┐
│ 🌐 Web: platform.claude.com 🔗      │
│ 64.4KB (200 OK)                     │
└─────────────────────────────────────┘
```

- **URL**: Clickable link (opens in browser)
- **Status**: Show size and HTTP status
- **Content**: Hidden - Claude summarizes in response

### WebSearch

```
┌─────────────────────────────────────┐
│ 🔎 Search: "react hooks tutorial"   │
│ 5 results                    [+] ▼  │
└─────────────────────────────────────┘
```

- **Query**: Always visible
- **Results**: Collapsed by default, tap to expand list of links
- Each result shows title + URL

### MCP Tools (mcp**server**tool)

```
┌─────────────────────────────────────┐
│ 🔌 context7 - query-docs (MCP)      │
│ libraryId: "/anthropics/claude..."  │
│                              [+] ▼  │
└─────────────────────────────────────┘
```

- **Format**: `servername - toolname (MCP)`
- **Input**: Show key parameters inline
- **Result**: Collapsed by default, tap to expand

### Other Tools (LSP, BashOutput, etc.)

```
┌─────────────────────────────────────┐
│ 🔧 Used: LSP goToDefinition         │
└─────────────────────────────────────┘
```

- **Minimal**: Just show tool name and operation
- **Logged**: Track usage for future enhancement
- No result display

---

## Rendering Rules

### 1. Skip Delta Messages

- Ignore all `assistant` messages where `delta: true`
- Only render `assistant` messages where `delta: false`

### 2. State Drives Animation

- Animation starts on `state: executing` or `state: thinking`
- Animation changes when `state` includes `tool` field
- Animation stops on `state: idle`

### 3. Tool Cards (Optional)

- Show `tool_use` as a collapsible card
- Update with `tool_result` content when received
- Match by ID: `tool_result.tool_use_id` === `tool_use.id`

### 4. Verify Final Result

- Compare `system/result` content with last `assistant (delta=false)` message
- Only show `system/result` if it differs (should be rare)

### 5. Handle Duplicates

- `state: idle` may be sent twice - ignore duplicates
- `system/result` duplicates `assistant` message - skip if identical

---

## CLI-Bridge Enhancements

cli-bridge transforms SDK messages for easier mobile consumption.

### Tool Result

**SDK sends:**

```json
{
  "type": "tool_result",
  "tool_use_id": "toolu_...",
  "content": "...",
  "is_error": false
}
```

**cli-bridge sends:**

```json
{
  "type": "tool_result",
  "id": "toolu_...",
  "tool": "Bash",
  "output": "...",
  "isError": false
}
```

### Field Mapping

| SDK           | cli-bridge | Notes                                |
| ------------- | ---------- | ------------------------------------ |
| `tool_use_id` | `id`       | Shortened                            |
| `content`     | `output`   | Renamed                              |
| `is_error`    | `isError`  | camelCase                            |
| (none)        | `tool`     | **Added** - correlated from tool_use |

### Tool Correlation Fix (v0.3.3+)

cli-bridge now correlates tool names from `tool_use` to `tool_result`:

**Before:**

```json
{ "type": "tool_result", "id": "toolu_123", "tool": "unknown", ... }
```

**After:**

```json
{ "type": "tool_result", "id": "toolu_123", "tool": "Read", ... }
```

Implementation: `MessageProcessor` maintains a `Map<id, toolName>` registry:

- On `tool_use`: stores `id → name`
- On `tool_result`: looks up name by id, adds to message, deletes entry
- On `stopAll`: clears registry

### Progress Messages (cli-bridge only)

For long-running tools, cli-bridge emits progress updates:

```json
{ "type": "progress", "id": "toolu_123", "tool": "Bash", "elapsed": 5 }
```

Use this to show "Running command... (5s)" during execution.

### Connection Messages (cli-bridge only)

```json
{ "type": "system", "message": "WebSocket connected" }
{ "type": "connected", "agentId": "agent_xxx", "sessionId": "...", "model": "sonnet" }
```

---

## Server-Side Filtering

cli-bridge can optionally filter messages to reduce client complexity:

1. **Filter `delta: true`** - Only send `delta: false` messages
2. **Dedupe `state: idle`** - Only send once
3. **Skip `system/result`** - If identical to last assistant message

This simplifies the iOS client to:

- State handler (drives animation)
- Message handler (append complete messages)
- Tool handler (show/update tool cards)

---

## Existing Components (Reuse)

These components already exist and should be kept/enhanced:

| Component                   | File                      | What It Does                                           |
| --------------------------- | ------------------------- | ------------------------------------------------------ |
| `ExploredFilesView`         | CompactToolView.swift:339 | Groups Read/Glob/Grep → "📁 Explored: file1, file2..." |
| `TerminalCommandView`       | CompactToolView.swift:404 | "$ command" with [▸] expand, result summary, duration  |
| `groupMessagesForDisplay()` | CompactToolView.swift:53  | Groups consecutive tool messages                       |
| `DiffView`                  | (referenced)              | Edit operations show red/green diff                    |
| `TodoListView`              | (referenced)              | TodoWrite renders as task list                         |
| `CLIProcessingView`         | CLIMessageView.swift:584  | Current "Thinking..." (to be replaced)                 |
| `CLITheme.ToolType`         | Models                    | Tool icons and colors                                  |
| `ToolParser`                | ToolParser.swift          | Extract params, format content                         |

### What to Keep As-Is

- `ExploredFilesView` - already matches spec (file list, no content)
- `TerminalCommandView` - already matches spec (command visible, result collapsed, duration)
- `DiffView` - already matches spec
- `TodoListView` - already matches spec (drawer integration)
- `groupMessagesForDisplay()` - already handles Read/Glob/Grep/Bash grouping

### What to Replace

- `CLIProcessingView` → New `StatusBubbleView` with shimmer + rotating messages

### What to Add

- `StatusBubbleView` - inline chat bubble with shimmer animation
- `StatusMessages.swift` - rotating message pools
- `SubagentMiniChatView` - mini chat window for Task operations
- State tracking in ChatViewModel

---

## Design Principles: The 2Ps

### Performance

- **No jitter**: Animations must be smooth 60fps, use `@MainActor` correctly
- **No freeze**: Never block main thread, use `Task.detached` for heavy work
- **Lazy loading**: Only compute/render what's visible
- **Cache aggressively**: Pre-compute expensive values in `init`, use cached timestamps
- **Batch updates**: Don't trigger re-renders for each delta, batch state changes
- **Memory efficient**: Release resources in `deinit`, avoid retain cycles

### Polish

- **iOS 26+ native**: Use system animations, SF Symbols, Liquid Glass backgrounds
- **Consistent timing**: All animations use standard iOS curves (`.easeInOut`, `.spring`)
- **Subtle > flashy**: Animations should feel alive, not distracting
- **Responsive feedback**: Haptics on interactions, visual confirmation on actions
- **Graceful degradation**: Handle errors elegantly, never show raw errors to users

### Code Quality

- **No legacy cruft**: Remove unused code paths, don't add backwards-compat hacks
- **Single responsibility**: Each view/component does one thing well
- **Testable**: Logic in ViewModels, Views are dumb renderers
- **Thread-safe**: `@MainActor` on all `ObservableObject` classes, no race conditions

---

## Implementation Plan

### cli-bridge (Done)

- [x] Add `tool` field to `tool_result` (correlated from tool_use)
- [x] Server-side delta filtering (only send delta=false)

### iOS: Phase 1 - State Animation System

- [x] Create `StatusBubbleView` - inline chat bubble for state display
- [x] Create `StatusMessage.swift` - data model with rarity, timeOfDay, seasonal
- [x] Create `StatusMessageStore.swift` - message pools, weighted selection, seen tracking
- [x] Add state tracking to `ChatViewModel` (executing/thinking/idle + tool)
- [x] Implement shimmer animation on text (tool-colored gradient sweep, 1.8s loop)
- [x] Emoji display (static, no animation per user preference)
- [x] Handle elapsed time display (after 10s)
- [x] Message rotation every 8-12 seconds with crossfade (0.3s)
- [x] Fixed nested ObservableObject observation (objectWillChange forwarding)
- [x] Removed async dispatch latency in Combine subscriptions

### iOS: Phase 2 - Simplify Message Handling

- [ ] Remove delta accumulation logic (server filters now)
- [ ] Only render `assistant` messages where `delta: false`
- [ ] Verify `system/result` matches last assistant (skip if same)
- [ ] Handle duplicate `state: idle` messages
- [ ] Collapsible long messages (> 50 lines) with "Show more"

### iOS: Phase 3 - Tool Display Refinements

- [ ] Bash: Ensure result collapsed by default, add elapsed time
- [ ] Read/Grep/Glob: Hide content, only show file list
- [ ] Task: Mini chat window with last 3 tools + stats footer
- [ ] WebFetch: Add clickable URL with size/status
- [ ] WebSearch: Add collapsible results list
- [ ] MCP tools: Parse `mcp__server__tool` format, show nicely
- [ ] Other tools: Minimal display + logging

### iOS: Phase 4 - Chat UX Fixes

- [ ] **Fix Jump-to-bottom FAB** - floating button when scrolled up, unread badge
- [ ] **"Try again" button** - re-run last prompt (in message action bar)
- [ ] **Image full-screen zoom** - tap to expand, pinch-zoom, dismiss with swipe
- [ ] Token display per message (small badge, optional - already have total in status bar)

### iOS: Phase 5 - Rarity & Time System

- [ ] Implement time-of-day message injection (morning/afternoon/evening/night/weekend)
- [ ] Implement seasonal message injection (halloween/christmas/newYear/valentine)
- [ ] Weighted random selection by rarity
- [ ] Track "seen" messages in UserDefaults
- [ ] Settings: Message Collection progress view
- [ ] Settings: Toggle "Show mini progress" vs "Show messages"

### iOS: Phase 6 - Polish & Performance

- [ ] Assign rarity to all ~300 messages
- [ ] Fine-tune animation timing and curves
- [ ] Profile with Instruments - no dropped frames
- [ ] Test with 500+ messages - smooth scrolling
- [ ] Memory audit - no leaks, stable footprint
- [ ] Accessibility audit - VoiceOver, Dynamic Type

---

## Feature Status

### Already Implemented ✅

| Feature             | Location              |
| ------------------- | --------------------- |
| Input templates     | CommandPickerSheet    |
| Voice transcription | SpeechManager         |
| Drafts per session  | DraftInputPersistence |
| Copy with filename  | CodeBlockView         |
| Token counter       | CLIStatusBarViews     |

### MVP - Must Fix/Add 🔧

| Feature                   | Priority     | Notes                                      |
| ------------------------- | ------------ | ------------------------------------------ |
| Jump-to-bottom FAB        | **Critical** | Currently broken, essential for long chats |
| "Try again" button        | **High**     | Re-run last prompt, power user essential   |
| Collapsible long messages | **High**     | > 50 lines auto-collapse                   |
| Image full-screen zoom    | **Medium**   | Tap to expand, pinch-zoom                  |

### Future Ideas 📋

| Feature                | Complexity | Notes                             |
| ---------------------- | ---------- | --------------------------------- |
| Syntax highlighting    | Medium     | Nice-to-have if straightforward   |
| Split view (iPad)      | High       | Power user feature for coding     |
| Keyboard navigation    | Medium     | Arrow keys, Enter to expand       |
| Prompt suggestions     | High       | Had it, removed - revisit later   |
| Confidence indicators  | High       | Interesting UX experiment         |
| Context-aware messages | Medium     | Track last tool type, git status  |
| Session streaks        | Low        | "5 commits today!"                |
| Mini progress stats    | Medium     | "12 tools · 45m" inline           |
| Focus mode             | Low        | Minimal messages during deep work |
| Achievement unlocks    | Medium     | Gamification layer                |

---

## iOS 26+ Best Practices

### Animations

```swift
// Standard timing
withAnimation(.easeInOut(duration: 0.3)) { ... }

// Spring for interactive
withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { ... }

// Continuous (shimmer, pulse)
withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { ... }
```

### SF Symbol Animations

```swift
Image(systemName: "brain.head.profile")
    .symbolEffect(.pulse, options: .repeating)

Image(systemName: "terminal")
    .symbolEffect(.variableColor.iterative)
```

### Liquid Glass (iOS 26+)

```swift
.glassBackground(tint: .accent, cornerRadius: 12)
.glassCapsule(tint: .success, isInteractive: true)
```

### Thread Safety

```swift
@MainActor
class MyViewModel: ObservableObject {
    @Published var state: State = .idle

    func loadData() async {
        // Heavy work off main thread
        let result = await Task.detached {
            // CPU-intensive work here
        }.value

        // Update UI on main thread (automatic with @MainActor)
        self.state = .loaded(result)
    }
}
```

### Haptics

```swift
HapticManager.light()    // Selections, toggles
HapticManager.medium()   // Actions, confirms
HapticManager.success()  // Completions
HapticManager.error()    // Failures
```
