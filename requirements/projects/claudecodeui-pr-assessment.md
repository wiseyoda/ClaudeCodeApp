# claudecodeui PR Assessment

Systematic assessment of all PRs for viability to merge into wiseyoda/claudecodeui fork.

**Total PRs**: 124
**Last Updated**: 2025-12-28

## Assessment Legend

| Field | Description |
|-------|-------------|
| **Status** | `open` = still open, `merged` = merged to upstream, `closed` = closed without merge |
| **Viability** | `✅ Merge` / `🔍 Review` / `⏸️ Hold` / `❌ Skip` / `⬜ TBD` |
| **Priority** | `P1` Critical / `P2` High / `P3` Medium / `P4` Low |
| **Category** | Bug fix, Feature, Security, Infra, i18n, UI, etc. |

---

## Open PRs (27 total)

### Critical Priority (P1)

| # | Title | Author | Created | Category | Viability | Notes |
|---|-------|--------|---------|----------|-----------|-------|
| 249 | permission dialog | dima-m711 | 2025-11-30 | Feature | ✅ Merge | 32 commits, permission approval + ExitPlanMode |
| 212 | feat: Auto-Compact Token Monitoring - Prevent Context Loss in Long Sessions | shockstricken | 2025-10-19 | Feature | 🔍 Review | Token budget monitoring, auto-compress |
| 160 | fix(sidebar): refresh on session-created; stabilize streaming and navigation | xavierliang | 2025-08-17 | Bug fix | ⏸️ Hold | Streaming stability, session refresh |

---

## Detailed P1 Assessments

### PR #249: Permission Dialog System ✅ MERGE

**Verdict**: ✅ **MERGE** - High quality, recently rebased, directly addresses our needs

#### Summary
| Metric | Value |
|--------|-------|
| Commits | 32 |
| Base | Recently rebased with main |
| Conflicts | None (clean merge) |
| Files Added | 29 new files |
| Files Modified | ~15 files |

#### What It Implements
1. **Permission Manager Service** (`server/services/permissionManager.js`)
   - Queue-based permission request handling
   - Session-scoped caching with LRU eviction
   - Timeout handling with configurable duration
   - Statistics tracking (approved/denied/timed out)

2. **Plan Approval System** (`server/services/planApprovalManager.js`)
   - ExitPlanMode detection and handling
   - Inline plan approval UI
   - Permission mode selection (acceptEdits, default, reject)
   - Session persistence across page refreshes

3. **WebSocket Integration** (`server/services/permissionWebSocketHandler.js`)
   - Real-time permission request/response via WebSocket
   - Session-aware routing
   - JSON validation and security hardening

4. **Frontend Components**
   - `PermissionDialog.jsx` - Tool approval dialog
   - `PlanApprovalDialog.jsx` - Plan review/approval UI
   - `PermissionContext.jsx` - State management
   - `PlanApprovalContext.jsx` - Plan state management

5. **Comprehensive Documentation**
   - 10+ spec files documenting phases and implementation
   - Security audit documentation
   - Missing integration notes

#### Solves These iOS Workarounds
- ✅ Permission approval UI (Issue #22)
- ✅ Plan mode exit approval (Issue #22)
- ✅ Non-bypass mode approval flow

#### Code Quality Assessment
| Aspect | Rating | Notes |
|--------|--------|-------|
| Architecture | ⭐⭐⭐⭐⭐ | Clean separation, event-driven |
| Security | ⭐⭐⭐⭐⭐ | Session isolation, cache TTL, JSON validation |
| Documentation | ⭐⭐⭐⭐⭐ | Extensive specs and plans |
| Testing | ⭐⭐⭐ | Test script included, needs more |
| Maintainability | ⭐⭐⭐⭐ | Well-structured, good logging |

#### Integration Effort
- **Estimated effort**: Low - clean merge expected
- **Risk**: Low - recently rebased, comprehensive implementation

#### Action Plan
```bash
cd ~/workspace/claudecodeui
git checkout main
git merge pr-249
# Resolve any minor conflicts
git push origin main
```

---

### PR #212: Auto-Compact Token Monitoring 🔍 REVIEW

**Verdict**: 🔍 **REVIEW** - Valuable feature, but significant conflicts due to old base

#### Summary
| Metric | Value |
|--------|-------|
| Commits | 5 |
| Base | a100648 (Release 1.8.12) |
| Behind main | **97 commits** |
| Conflicts | HIGH - uses deprecated claude-cli.js |

#### What It Implements
1. **Token Budget Parsing**
   - Parses `<system_warning>` tags from Claude CLI output
   - Extracts used/total/remaining token counts
   - Handles comma-formatted numbers

2. **Auto-Compact Trigger**
   - Configurable threshold (default 30,000 tokens)
   - 5-minute cooldown to prevent loops
   - Per-session settings storage

3. **Frontend Components** (in old architecture)
   - Token budget indicator (pie chart visualization)
   - Auto-compact notifications
   - Settings UI for threshold configuration

#### Problem: Architecture Mismatch
The PR is based on `claude-cli.js` architecture, but main branch now uses `claude-sdk.js`:

```
PR #212 uses:     server/claude-cli.js (deleted in main)
Main branch uses: server/claude-sdk.js (new architecture)
```

This means the core implementation cannot be directly merged.

#### Solves These iOS Workarounds
- ⚠️ Token budget monitoring (need to reimplement for SDK)
- ⚠️ Context loss prevention (need to reimplement)

#### Code Quality Assessment
| Aspect | Rating | Notes |
|--------|--------|-------|
| Architecture | ⭐⭐⭐ | Good, but wrong base |
| Implementation | ⭐⭐⭐⭐ | Clean token parsing logic |
| Documentation | ⭐⭐⭐⭐ | Good feature proposal docs |
| Portability | ⭐⭐ | Needs significant rework |

#### Integration Effort
- **Estimated effort**: HIGH - need to port to SDK architecture
- **Risk**: Medium - core logic is sound, but needs adaptation

#### Action Plan
1. **Don't merge directly** - will cause massive conflicts
2. **Extract valuable logic**:
   - `parseSystemWarnings()` - token parsing
   - `shouldTriggerAutoCompact()` - threshold logic
   - Frontend components (may be reusable)
3. **Reimplement for claude-sdk.js**:
   - Hook into SDK output stream
   - Add token tracking to WebSocket messages
   - Port frontend components

```bash
# Review but don't merge
git checkout pr-212
# Extract and adapt:
# - server/claude-cli.js (token parsing logic only)
# - src/components/TokenBudgetIndicator.jsx
# - src/components/AutoCompactNotification.jsx
```

---

### PR #160: Session Refresh & Streaming Stabilization ⏸️ HOLD

**Verdict**: ⏸️ **HOLD** - Even older base, but has Chinese commits - may need translation

#### Summary
| Metric | Value |
|--------|-------|
| Commits | 9 |
| Base | 3c9a4ca (CLI injection fix) |
| Behind main | **102 commits** |
| Conflicts | VERY HIGH |

#### What It Implements
1. **Streaming Ownership Guard**
   - Session-scoped refs to prevent cross-session contamination
   - `activeCursorStreamSessionIdRef` for tracking active session

2. **Sidebar Refresh on session-created**
   - 800ms delayed refresh
   - Cancel-on-update logic to prevent infinite loops

3. **Navigation Stabilization**
   - Auto-nav only from root path
   - Prevents double-handling and flicker

4. **Model Updates** (Chinese commit messages)
   - Cursor model name updates
   - Additional model mappings

#### Problem: Severe Conflicts
- 102 commits behind main
- Uses old file structure
- Some commits have Chinese messages (may need translation)

#### Solves These iOS Workarounds
- ⚠️ Streaming stability (already partially fixed in main?)
- ⚠️ Session refresh issues (need to verify current state)

#### Code Quality Assessment
| Aspect | Rating | Notes |
|--------|--------|-------|
| Bug fixes | ⭐⭐⭐⭐ | Addresses real issues |
| Portability | ⭐ | Severe conflict risk |
| Documentation | ⭐⭐ | Limited, some Chinese |

#### Integration Effort
- **Estimated effort**: VERY HIGH - may need complete rewrite
- **Risk**: High - conflicts likely to cause issues

#### Action Plan
1. **Don't merge** - too far behind
2. **Check if issues still exist** in current main:
   ```bash
   # Test streaming stability in current build
   # If issues present, consider reimplementing fixes
   ```
3. **If needed, extract logic only**:
   - Streaming ownership guard pattern
   - Session refresh timing logic

---

## P1 Assessment Summary

| PR | Verdict | Effort | Action |
|----|---------|--------|--------|
| #249 | ✅ Merge | Low | Direct merge |
| #212 | 🔍 Review | High | Extract & reimplement |
| #160 | ⏸️ Hold | Very High | Check if still needed |

### Recommended Order
1. **Merge #249 first** - clean merge, high value
2. **Evaluate #212 logic** - port to SDK if needed
3. **Test current main** - verify if #160 issues exist before porting

### High Priority (P2)

| # | Title | Author | Created | Category | Viability | Notes |
|---|-------|--------|---------|----------|-----------|-------|
| 259 | fix: correctly decode project paths containing hyphens | xuiltul | 2025-12-13 | Bug fix | ✅ Merge | smartDecodeProjectPath() - only 4 commits behind |
| 257 | Fix issue: Broken pasted image upload | panta82 | 2025-12-09 | Bug fix | 🔍 Review | Check if already fixed in main |
| 157 | fix: Session summary update functionality not working | Yippine | 2025-08-15 | Bug fix | ❌ Skip | 160 commits behind, obsolete architecture |
| 255 | fix: apply originalPath config to auto-detected projects | kabaken | 2025-12-09 | Bug fix | ✅ Merge | originalPath override - 8 commits behind |
| 228 | fix(projects): Convert special characters other than English letters and numbers to - | LeoZheng1738 | 2025-11-06 | Bug fix | 🔍 Review | Aggressive encoding change - evaluate impact |

---

## Detailed P2 Assessments

### PR #259: Hyphen Path Decoding ✅ MERGE

**Verdict**: ✅ **MERGE** - Excellent fix, minimal conflicts

#### Summary
| Metric | Value |
|--------|-------|
| Commits | 1 |
| Behind main | **4 commits** (very recent) |
| Conflicts | Minimal |
| Core change | `smartDecodeProjectPath()` function |

#### What It Fixes
The naive `projectName.replace(/-/g, '/')` breaks hyphenated project names:
- Input: `-home-dev-AI-Schreiber`
- Wrong: `/home/dev/AI/Schreiber`
- Correct: `/home/dev/AI-Schreiber`

#### Implementation (Smart Multi-Strategy)
```javascript
async function smartDecodeProjectPath(projectName) {
  // 1. Try simple decode first, check if path exists
  const simpleDecode = '/' + parts.join('/');
  if (await pathExists(simpleDecode)) return simpleDecode;

  // 2. Find deepest existing parent directory
  // 3. Treat remaining parts as project name with hyphens
  // 4. Use PascalCase heuristics for project name detection
  // 5. Handle common directory patterns (home, dev, opt, etc.)
}
```

#### Code Quality
| Aspect | Rating | Notes |
|--------|--------|-------|
| Correctness | ⭐⭐⭐⭐⭐ | Filesystem verification |
| Robustness | ⭐⭐⭐⭐ | Multiple fallback strategies |
| Performance | ⭐⭐⭐ | Async file checks (acceptable) |

#### Integration Effort
- **Estimated effort**: Low - very recent base
- **Risk**: Low - isolated change to one function

#### Action Plan
```bash
git checkout main
git merge pr-259
# Minor conflicts possible, resolve and test
```

---

### PR #257: Image Upload Fix 🔍 REVIEW

**Verdict**: 🔍 **REVIEW** - Verify if already fixed in main

#### Summary
| Metric | Value |
|--------|-------|
| Commits | 1 |
| Behind main | **7 commits** |
| Core change | FormData Content-Type handling |

#### What It Fixes
`authenticatedFetch` always set `Content-Type: application/json`, breaking multipart form uploads.

#### The Fix
```javascript
// Only set Content-Type if body is not FormData
if (!(options.body instanceof FormData)) {
  defaultHeaders['Content-Type'] = 'application/json';
}
```

#### Status Check Needed
The fix may already exist in main. Verify before merging:
```bash
grep -A5 "FormData" src/utils/api.js
```

#### Additional Changes
PR also removes Codex-related code (provider routing). Evaluate if this is desired.

#### Action Plan
1. Check if fix already in main
2. If not, cherry-pick just the FormData fix
3. Ignore Codex removal if not needed

---

### PR #157: Session Summary Update ❌ SKIP

**Verdict**: ❌ **SKIP** - Too old, architecture mismatch

#### Summary
| Metric | Value |
|--------|-------|
| Commits | Multiple |
| Behind main | **160 commits** |
| Files changed | 100 files |
| Deletions | 28,055 lines |

#### Why Skip
- Based on pre-SDK architecture
- Deletes `claude-sdk.js`, brings back `claude-cli.js`
- Removes TaskMaster, many modern features
- Would require complete rewrite

#### Original Issue
Session title editing didn't save due to missing prop connection.

#### Alternative
If this bug still exists in main, implement the fix manually:
```javascript
// In App.jsx
const handleUpdateSessionSummary = async (projectName, sessionId, summary) => {
  await api.updateSessionSummary(projectName, sessionId, summary);
  // Refresh project list
};

// Pass to Sidebar
<Sidebar onUpdateSessionSummary={handleUpdateSessionSummary} />
```

---

### PR #255: originalPath Config Override ✅ MERGE

**Verdict**: ✅ **MERGE** - Clean addition, useful feature

#### Summary
| Metric | Value |
|--------|-------|
| Commits | 1 |
| Behind main | **8 commits** |
| Core change | Config-based path override |

#### What It Adds
Allows users to manually specify `originalPath` in `project-config.json` to override auto-detected paths:

```javascript
// In extractProjectDirectory()
const config = await loadProjectConfig();
if (config[projectName]?.originalPath) {
  const customPath = config[projectName].originalPath;
  projectDirectoryCache.set(projectName, customPath);
  return customPath;
}
```

#### Use Case
When auto-detection fails or user wants a specific path mapping.

#### Code Quality
| Aspect | Rating | Notes |
|--------|--------|-------|
| Implementation | ⭐⭐⭐⭐ | Clean, non-invasive |
| Utility | ⭐⭐⭐⭐ | Solves real edge cases |

#### Action Plan
```bash
git checkout main
git merge pr-255
```

---

### PR #228: Special Character Encoding 🔍 REVIEW

**Verdict**: 🔍 **REVIEW** - Breaking change, evaluate impact

#### Summary
| Metric | Value |
|--------|-------|
| Commits | 1 |
| Behind main | **34 commits** |
| Core change | Path encoding regex |

#### What It Changes
```javascript
// Before (current)
const projectName = absolutePath.replace(/\//g, '-');
// Encodes: /home/dev/project → -home-dev-project

// After (PR)
const projectName = absolutePath.replace(/[^a-zA-Z0-9]/g, '-');
// Encodes: /home/dev/project → -home-dev-project (same)
// Encodes: /home/dev/my.project → -home-dev-my-project (different!)
```

#### Impact Analysis
| Character | Before | After |
|-----------|--------|-------|
| `/` | `-` | `-` |
| `.` | `.` | `-` |
| `_` | `_` | `-` |
| ` ` (space) | ` ` | `-` |
| `@` | `@` | `-` |

#### Concerns
1. **Breaking change** - existing projects with dots/underscores would get new encodings
2. **Migration needed** - old project directories won't be found
3. **May conflict with PR #259** - different hyphen handling approaches

#### Recommendation
- **Don't merge directly** - breaking change
- Consider if this is actually needed
- If needed, implement migration path for existing projects

---

## P2 Assessment Summary

| PR | Verdict | Effort | Action |
|----|---------|--------|--------|
| #259 | ✅ Merge | Low | Direct merge - hyphen path fix |
| #257 | 🔍 Review | Low | Check if already fixed |
| #157 | ❌ Skip | N/A | Too old, implement manually if needed |
| #255 | ✅ Merge | Low | Direct merge - config override |
| #228 | 🔍 Review | Medium | Evaluate breaking change impact |

### Recommended Merge Order
1. **Merge #259** - Hyphen path fix (most important)
2. **Merge #255** - Config override (complements #259)
3. **Verify #257** - Check if fix exists in main
4. **Evaluate #228** - Decide if breaking change is worth it

### Medium Priority (P3)

| # | Title | Author | Created | Category | Viability | Notes |
|---|-------|--------|---------|----------|-----------|-------|
| 271 | Feat/rtl support | AlexSuprun | 2025-12-27 | i18n | ✅ Merge | RTL text detection - 4 commits behind |
| 266 | Bump Opus version, make Opus default | DanieleSalatti | 2025-12-25 | Feature | 🔍 Review | Changes default model - evaluate |
| 250 | feat: Add codeblock highlight support in ChatInterface | ZhenhongDu | 2025-12-01 | UI | ✅ Merge | Prism.js syntax highlighting - 10 behind |
| 244 | [FixBug] Desktop "New Project" button hidden | ybalbert001 | 2025-11-26 | Bug fix | ✅ Merge | Fixes conditional rendering bug |
| 241 | feat: add Docker deployment support | FarisHijazi | 2025-11-24 | Infra | ✅ Merge | Dockerfile + docker-compose - 10 behind |
| 238 | feat: add sub-directory deployment support | yingca1 | 2025-11-22 | Infra | 🔍 Review | Base path config for reverse proxy |
| 236 | feat: Model Provider configuration sync | DawnLck | 2025-11-19 | Feature | 🔍 Review | Syncs to ~/.claude/settings.json |
| 235 | feat: Comprehensive i18n support | DawnLck | 2025-11-18 | i18n | 🔍 Review | EN/Chinese - 10 behind, large change |
| 202 | Feat: PAM authentication support | vitalivu992 | 2025-09-29 | Security | ❌ Skip | 102 behind + security concerns |
| 196 | feat: Electron support for desktop | dnviti | 2025-09-11 | Feature | ❌ Skip | 152 behind - too old |
| 184 | feat: Add Japanese translation | Utakata | 2025-08-28 | i18n | ❌ Skip | 157 behind - depends on #235 |
| 175 | feat: AUTH_DISABLED env variable | iamriajul | 2025-08-24 | Feature | ⏸️ Hold | 157 behind - useful but needs rebase |
| 148 | feat: Docker support (alternative) | JokerRun | 2025-08-12 | Infra | ❌ Skip | 165 behind - use #241 instead |
| 35 | feat: Thinking mode selector | lvalics | 2025-07-11 | Feature | ❌ Skip | 265 behind - obsolete |

---

## Detailed P3 Assessments

### Recent PRs (4-10 commits behind) - Likely Mergeable

#### PR #271: RTL Support ✅ MERGE

| Metric | Value |
|--------|-------|
| Behind main | **4 commits** |
| Commits | 4 (2 merge commits) |

**What it adds**: Automatic RTL (right-to-left) text direction detection for Hebrew, Arabic, etc.

**Implementation**: Adds CSS direction detection and a dev control script.

**Verdict**: ✅ **MERGE** - Recent, clean, useful for i18n

---

#### PR #266: Opus Default Model 🔍 REVIEW

| Metric | Value |
|--------|-------|
| Behind main | **4 commits** |
| Core change | `model || 'sonnet'` → `model || 'opus'` |

**What it changes**: Changes default model from Sonnet to Opus.

**Considerations**:
- Opus is more expensive
- May not be desired default for all users
- Also removes permission-related code (conflicts with #249)

**Verdict**: 🔍 **REVIEW** - Evaluate if Opus default is desired. May conflict with #249.

---

#### PR #250: Codeblock Syntax Highlighting ✅ MERGE

| Metric | Value |
|--------|-------|
| Behind main | **10 commits** |
| Dependencies | `react-syntax-highlighter`, `prism` |

**What it adds**:
- Prism.js-based syntax highlighting
- Language label on code blocks
- `oneDark` theme

**Code quality**: Clean implementation, adds packages.

**Verdict**: ✅ **MERGE** - Nice UI enhancement

---

#### PR #244: New Project Button Fix ✅ MERGE

| Metric | Value |
|--------|-------|
| Behind main | **10 commits** |
| Bug | Button hidden when `projects.length === 0` |

**What it fixes**: "New Project" button was inside `projects.length > 0` conditional, making it impossible to create first project.

**Verdict**: ✅ **MERGE** - Real bug fix, simple change

---

#### PR #241: Docker Deployment ✅ MERGE

| Metric | Value |
|--------|-------|
| Behind main | **10 commits** |
| Files added | `Dockerfile`, `docker-compose.yml`, `.dockerignore` |

**What it adds**:
- Multi-stage Dockerfile
- docker-compose with health checks
- Proper .dockerignore

**Verdict**: ✅ **MERGE** - Clean Docker setup, useful for QNAP deployment

---

#### PR #238: Sub-directory Deployment 🔍 REVIEW

| Metric | Value |
|--------|-------|
| Behind main | **10 commits** |
| Use case | Deploy to `/claudeui/` path behind reverse proxy |

**What it adds**: BASE_URL/base path configuration for Vite and WebSocket.

**Considerations**: Port change from 3001 to 3002 in one place - verify consistency.

**Verdict**: 🔍 **REVIEW** - Useful for reverse proxy setups

---

#### PR #236: Model Provider Sync 🔍 REVIEW

| Metric | Value |
|--------|-------|
| Behind main | **10 commits** |
| Commits | 5 |

**What it adds**: Syncs model provider configuration to `~/.claude/settings.json`.

**Considerations**: Larger change (35 files), includes formatting refactors.

**Verdict**: 🔍 **REVIEW** - Evaluate scope of changes

---

#### PR #235: i18n Support 🔍 REVIEW

| Metric | Value |
|--------|-------|
| Behind main | **10 commits** |
| Languages | English, Chinese |
| Files | `src/i18n/en.json`, `src/i18n/zh.json`, `src/i18n/index.jsx` |

**What it adds**:
- Full i18n infrastructure
- 250+ translation keys
- Language switcher
- localStorage persistence

**Considerations**:
- Large change (43 files)
- Touches many components
- Foundation for #184 (Japanese) and #271 (RTL)

**Verdict**: 🔍 **REVIEW** - Comprehensive but large scope

---

### Old PRs (100+ commits behind) - Skip or Hold

#### PR #202: PAM Authentication ❌ SKIP

| Metric | Value |
|--------|-------|
| Behind main | **102 commits** |
| Security issue | Uses `su` command (vulnerable) |

**Why skip**: Security concerns (pam_rootok bypass, no TTY support). Would need proper PAM library for production.

---

#### PR #196: Electron Desktop ❌ SKIP

| Metric | Value |
|--------|-------|
| Behind main | **152 commits** |
| Files | 96 files changed |

**Why skip**: Too old to merge. If Electron is needed, start fresh or find more recent fork.

---

#### PR #184: Japanese Translation ❌ SKIP

| Metric | Value |
|--------|-------|
| Behind main | **157 commits** |
| Dependency | Requires #235 (i18n infrastructure) |

**Why skip**: Too old. If Japanese needed, implement after merging #235.

---

#### PR #175: AUTH_DISABLED ⏸️ HOLD

| Metric | Value |
|--------|-------|
| Behind main | **157 commits** |
| Feature | Bypass auth with `AUTH_DISABLED=true` |

**Why hold**: Useful feature for Tailscale-protected deployments, but needs complete rewrite due to age. Consider reimplementing the logic (~20 lines).

---

#### PR #148: Docker (Alternative) ❌ SKIP

| Metric | Value |
|--------|-------|
| Behind main | **165 commits** |

**Why skip**: Use #241 instead - more recent and cleaner.

---

#### PR #35: Thinking Mode Selector ❌ SKIP

| Metric | Value |
|--------|-------|
| Behind main | **265 commits** |

**Why skip**: Oldest open PR. Architecture completely changed. Frontend-only feature could be reimplemented if needed.

---

## P3 Assessment Summary

| PR | Verdict | Behind | Action |
|----|---------|--------|--------|
| #271 | ✅ Merge | 4 | RTL support |
| #250 | ✅ Merge | 10 | Syntax highlighting |
| #244 | ✅ Merge | 10 | New Project button fix |
| #241 | ✅ Merge | 10 | Docker deployment |
| #266 | 🔍 Review | 4 | Opus default - evaluate |
| #238 | 🔍 Review | 10 | Base path - useful for proxies |
| #236 | 🔍 Review | 10 | Settings sync - large scope |
| #235 | 🔍 Review | 10 | i18n - large but foundational |
| #175 | ⏸️ Hold | 157 | AUTH_DISABLED - reimplement |
| #202 | ❌ Skip | 102 | PAM - security issues |
| #196 | ❌ Skip | 152 | Electron - too old |
| #184 | ❌ Skip | 157 | Japanese - needs #235 first |
| #148 | ❌ Skip | 165 | Docker - use #241 |
| #35 | ❌ Skip | 265 | Thinking mode - obsolete |

### P3 Merge Order (if proceeding)
1. **#244** - Bug fix (simple)
2. **#271** - RTL support (small)
3. **#250** - Syntax highlighting (enhances UI)
4. **#241** - Docker (infrastructure)

---

## Detailed P4 Assessments

All P4 PRs are 150-260+ commits behind main. Most use the deprecated `claude-cli.js` architecture and would require complete rewrites. Assessed for ideas worth extracting.

### PR #169: Dynamic Claude CLI Resolution ❌ SKIP

| Metric | Value |
|--------|-------|
| Behind main | **157 commits** |
| Commits | 2 |
| Files | 31 (major refactor) |

**What it does**: Adds dynamic resolution of claude CLI path using `which claude` and environment variables.

**Why skip**:
- Uses deprecated `server/claude-cli.js` (removed in favor of `claude-sdk.js`)
- 31 files changed with UI component refactoring unrelated to CLI resolution
- The useful logic (CLI path resolution) is ~10 lines and can be extracted

**If needed**: Extract the `which claude` logic (~10 lines in `claude-cli.js`) and add to SDK.

---

### PR #165: Claude Launcher Environment Variable ⏸️ HOLD

| Metric | Value |
|--------|-------|
| Behind main | **160 commits** |
| Commits | 1 |
| Files | 2 (README.md, server/claude-cli.js) |

**What it adds**: `CLAUDE_LAUNCHER` env variable to specify custom launcher (e.g., `npx`, `bunx`).

**Implementation** (simple):
```javascript
const launcher = process.env.CLAUDE_LAUNCHER || 'npx';
const claudeProcess = spawn(launcher, ['claude', ...args]);
```

**Why hold**:
- Too far behind to merge directly
- But the concept is useful and trivial to reimplement
- Only 2 files touched

**Action**: Reimplement in `claude-sdk.js` if this flexibility is needed.

---

### PR #158: Cloudflare/Deno Deployment ❌ SKIP

| Metric | Value |
|--------|-------|
| Behind main | **162 commits** |
| Commits | 12 |
| Files | 33 |

**What it adds**: Cloudflare Pages + Workers deployment with Deno runtime.

**Why skip**:
- Completely different deployment architecture
- We use QNAP container (Node.js), not Cloudflare
- 162 commits behind - would be massive merge conflict

**If needed**: Consider as reference for future Cloudflare deployment.

---

### PR #125: Markdown Rendering ❌ SKIP

| Metric | Value |
|--------|-------|
| Behind main | **200 commits** |
| Commits | 18 |
| Files | 29 |

**What it adds**:
- CodeBlock component with syntax highlighting
- GitHub OAuth authentication (unrelated bundling)
- Various UI components

**Why skip**:
- 200 commits behind - severe conflicts
- Merged PRs #215, #224, #250 already added markdown improvements
- Also includes unrelated GitHub OAuth (use #29/merged auth instead)

**Superseded by**: #215 (markdown), #224 (KaTeX math), #250 (syntax highlighting)

---

### PR #108: Hierarchical Settings File Support 🔍 REVIEW

| Metric | Value |
|--------|-------|
| Behind main | **213 commits** |
| Commits | 3 |
| Files | 6 |

**What it adds**: Settings resolution order matching Claude CLI:
1. Local `.claude/settings.json` (project-level)
2. Global `~/.claude/settings.json` (user-level)
3. Environment variables

**Why review**:
- Useful concept for Claude CLI compatibility
- Only 6 files changed (manageable)
- Logic could be extracted and reimplemented

**Key code** (extractable):
```javascript
const loadSettings = async () => {
  const localSettings = await loadJsonFile('.claude/settings.json');
  const globalSettings = await loadJsonFile('~/.claude/settings.json');
  return { ...globalSettings, ...localSettings, ...envSettings };
};
```

**Action**: Extract concept and reimplement for SDK architecture if needed.

---

### PR #104: Internationalization (i18n) Support ❌ SKIP

| Metric | Value |
|--------|-------|
| Behind main | **218 commits** |
| Commits | 13 |
| Files | 64 |

**What it adds**: Early i18n implementation with EN/Chinese support.

**Why skip**:
- Superseded by PR #235 (more complete i18n)
- 218 commits behind - massive conflicts
- #235 is only 10 commits behind and more comprehensive

**Use instead**: PR #235 for i18n needs.

---

### PR #89: TTS Voice Notifications and Claude Code Hooks ⏸️ HOLD

| Metric | Value |
|--------|-------|
| Behind main | **230 commits** |
| Commits | 3 |
| Files | 18 |

**What it adds**:
- Text-to-Speech notifications when Claude completes tasks
- Claude Code hooks integration (webhooks for task completion)
- Audio settings panel in UI

**Why hold**:
- Interesting feature for accessibility/multitasking
- Too far behind to merge directly
- Uses deprecated `claude-cli.js`

**Worth extracting**:
- `audioNotifications.js` - TTS service abstraction
- `AudioNotificationSettings.jsx` - Settings UI pattern
- Webhook integration for task completion events

**Action**: If voice notifications desired, reimplement using extracted patterns.

---

### PR #67: CLAUDE.md File Detection ❌ SKIP

| Metric | Value |
|--------|-------|
| Behind main | **238 commits** |
| Commits | 5 |
| Files | 3 |

**What it adds**:
- Detects `CLAUDE.md` files in projects
- Shows icon indicator in sidebar
- Icon guide documentation

**Why skip**:
- Already merged as PR #222 (`feat(chat): add CLAUDE.md support`)
- 238 commits behind
- Functionally superseded

**Superseded by**: PR #222 (merged)

---

### PR #63: Tunnelmole Integration ❌ SKIP

| Metric | Value |
|--------|-------|
| Behind main | **240 commits** |
| Commits | 2 |
| Files | 8 |

**What it adds**: Tunnelmole (ngrok alternative) for remote access without port forwarding.

**Why skip**:
- We use Tailscale for secure remote access (better solution)
- Tunnelmole exposes to public internet (security concern)
- 240 commits behind - would require rewrite

**Alternative**: Continue using Tailscale for private network access.

---

### PR #57: Comprehensive Docker Compose ❌ SKIP

| Metric | Value |
|--------|-------|
| Behind main | **242 commits** |
| Commits | 21 |
| Files | 29 |

**What it adds**:
- Development and production Docker Compose configs
- Multi-stage Dockerfile
- Various deployment scripts

**Why skip**:
- 242 commits behind - severe conflicts
- PR #241 (only 10 behind) provides cleaner Docker setup
- Overlapping functionality

**Use instead**: PR #241 for Docker deployment.

---

### PR #40: Docker Support (Earliest) ❌ SKIP

| Metric | Value |
|--------|-------|
| Behind main | **260 commits** |
| Commits | 3 |
| Files | 4 |

**What it adds**: Basic Dockerfile and docker-compose.yml.

**Why skip**:
- Oldest Docker PR (260 commits behind)
- Superseded by #57 (21 commits), #148 (165 behind), and #241 (10 behind)
- PR #241 is the clear winner for Docker support

**Use instead**: PR #241

---

## P4 Assessment Summary

| PR | Verdict | Behind | Action |
|----|---------|--------|--------|
| #165 | ⏸️ Hold | 160 | Reimplement launcher config (~10 lines) |
| #108 | 🔍 Review | 213 | Extract settings hierarchy concept |
| #89 | ⏸️ Hold | 230 | Extract TTS patterns if needed |
| #169 | ❌ Skip | 157 | Uses deprecated architecture |
| #158 | ❌ Skip | 162 | Different deployment target |
| #125 | ❌ Skip | 200 | Superseded by #215, #224, #250 |
| #104 | ❌ Skip | 218 | Superseded by #235 |
| #67 | ❌ Skip | 238 | Superseded by merged #222 |
| #63 | ❌ Skip | 240 | Tailscale is better |
| #57 | ❌ Skip | 242 | Use #241 instead |
| #40 | ❌ Skip | 260 | Use #241 instead |

### P4 Key Takeaways
- **No direct merges** - all too far behind
- **Useful concepts** to extract: launcher config, settings hierarchy, TTS notifications
- **Docker**: Use #241 (P3) instead of any P4 Docker PRs
- **i18n**: Use #235 (P3) instead of #104

---

## Complete Assessment Summary

### PRs to Merge (Recommended Order)

| Order | PR | Priority | Behind | Category | Effort |
|-------|-----|----------|--------|----------|--------|
| 1 | #249 | P1 | 0 | Permission Dialog | Low |
| 2 | #259 | P2 | 4 | Hyphen Path Fix | Low |
| 3 | #255 | P2 | 8 | originalPath Config | Low |
| 4 | #271 | P3 | 4 | RTL Support | Low |
| 5 | #244 | P3 | 10 | New Project Button Fix | Low |
| 6 | #250 | P3 | 10 | Syntax Highlighting | Low |
| 7 | #241 | P3 | 10 | Docker Deployment | Low |

### PRs to Review (Evaluate Before Merging)

| PR | Priority | Behind | Category | Concern |
|----|----------|--------|----------|---------|
| #212 | P1 | 97 | Token Monitoring | Architecture mismatch |
| #257 | P2 | 7 | Image Upload | May already be fixed |
| #228 | P2 | 34 | Special Chars | Breaking change |
| #266 | P3 | 4 | Opus Default | Conflicts with #249 |
| #238 | P3 | 10 | Base Path | Verify port consistency |
| #236 | P3 | 10 | Settings Sync | Large scope |
| #235 | P3 | 10 | i18n | Large but foundational |
| #108 | P4 | 213 | Settings Hierarchy | Extract concept only |

### PRs to Hold (Reimplement If Needed)

| PR | Priority | Feature | Effort to Reimplement |
|----|----------|---------|----------------------|
| #160 | P1 | Streaming Stability | Medium - check if still needed |
| #175 | P3 | AUTH_DISABLED | Low - ~20 lines |
| #165 | P4 | Launcher Config | Low - ~10 lines |
| #89 | P4 | TTS Notifications | Medium - extract patterns |

### PRs to Skip (52 total)

All other open PRs (100+ commits behind) and closed-not-merged PRs - use superseding PRs or reimplement if needed.

### Low Priority (P4)

| # | Title | Author | Created | Category | Viability | Notes |
|---|-------|--------|---------|----------|-----------|-------|
| 169 | feat: Add dynamic resolution for claude cli | MakingMofongo | 2025-08-21 | Feature | ❌ Skip | 157 behind, uses claude-cli.js |
| 165 | feat: add an environment variable to configure claude launcher | roykim98 | 2025-08-17 | Feature | ⏸️ Hold | 160 behind, but simple 2-file change |
| 158 | Create deno.yml | you112ef | 2025-08-15 | Infra | ❌ Skip | Cloudflare/Deno deployment - 162 behind |
| 125 | Render markdown | y4mau | 2025-07-28 | UI | ❌ Skip | 200 behind, superseded by merged PRs |
| 108 | feat: Add hierarchical settings file support | kosukesaigusa | 2025-07-22 | Feature | 🔍 Review | 213 behind, but useful concept |
| 104 | feat: Add internationalization (i18n) support | gowerlin | 2025-07-20 | i18n | ❌ Skip | 218 behind, superseded by #235 |
| 89 | feat: Add TTS Voice Notifications and Claude Code Hooks | AlyssonM | 2025-07-16 | Feature | ⏸️ Hold | 230 behind, but interesting feature |
| 67 | feat: Claude.md file detection and icon guide | lvalics | 2025-07-14 | Feature | ❌ Skip | 238 behind, already merged as #222 |
| 63 | feat: Add Tunnelmole integration for remote access | dario-valles | 2025-07-14 | Infra | ❌ Skip | 240 behind, Tailscale is better |
| 57 | feat: Add comprehensive Docker Compose support | krzemienski | 2025-07-13 | Infra | ❌ Skip | 242 behind, use #241 instead |
| 40 | Add Docker support with Dockerfile and docker-compose.yml | adityak74 | 2025-07-11 | Infra | ❌ Skip | 260 behind, use #241 instead |

---

## Closed PRs - Merged (45 total)

These are already in upstream (verify your fork has them):

| # | Title | Author | Merged | Category | In Fork? |
|---|-------|--------|--------|----------|----------|
| 253 | Update App.jsx | viper151 | 2025-12-07 | Fix | ⬜ Check |
| 227 | feat(projects): add project creation wizard with enhanced UX | viper151 | 2025-11-04 | Feature | ⬜ Check |
| 226 | fix(Sidebar): The undefined setShowSuggestions method removed | LeoZheng1738 | 2025-11-04 | Bug fix | ⬜ Check |
| 225 | fix: fix image viewer return 401 error | atelierai | 2025-11-04 | Bug fix | ⬜ Check |
| 224 | feat: support math rendering with KaTeX | Henry-Jessie | 2025-11-05 | Feature | ⬜ Check |
| 223 | Feature/cli commands | viper151 | 2025-11-02 | Feature | ⬜ Check |
| 222 | feat(chat): add CLAUDE.md support | viper151 | 2025-11-01 | Feature | ⬜ Check |
| 220 | feat(agent): add automated branch and PR creation | viper151 | 2025-10-31 | Feature | ⬜ Check |
| 218 | feat: UI updates to ChatInterface component | viper151 | 2025-10-31 | UI | ⬜ Check |
| 216 | Feature/edit diff | viper151 | 2025-10-31 | Feature | ⬜ Check |
| 215 | Add markdown improvements: inline code, tables, copy button | DumoeDss | 2025-10-31 | UI | ⬜ Check |
| 211 | feat: Implement slash command menu with fixed positioning | joshwilhelmi | 2025-10-30 | Feature | ⬜ Check |
| 208 | feat: Multiple features, improvements, and bug fixes | joshwilhelmi | 2025-10-30 | Feature | ⬜ Check |
| 205 | Make authentication database path configurable | werdnum | 2025-10-30 | Feature | ⬜ Check |
| 203 | feat: Improve accessibility and refactor settings | SyedaAnshrahGillani | 2025-10-01 | UI | ⬜ Check |
| 197 | Feat: Use environment variable for Claude path | johnhenry | 2025-09-23 | Feature | ⬜ Check |
| 188 | fix: iOS PWA status bar overlap issue | takumi3488 | 2025-09-15 | Bug fix | ⬜ Check |
| 183 | Integration with TaskMaster AI | viper151 | 2025-08-28 | Feature | ⬜ Check |
| 182 | Fix: Prevent CLI option injection in --print argument | Jerry-Terrasse | 2025-09-23 | Security | ⬜ Check |
| 156 | Fix: making code block render properly in light mode | viper151 | 2025-08-15 | Bug fix | ⬜ Check |
| 155 | fix: A bug where creation error when there is no .claude directory | viper151 | 2025-08-15 | Bug fix | ⬜ Check |
| 152 | fix: Force newer node-gyp for modern python system | akhdanfadh | 2025-08-15 | Bug fix | ⬜ Check |
| 147 | feat: Update version to 1.7.0 and usage limit message | viper151 | 2025-08-12 | Feature | ⬜ Check |
| 146 | Cursor cli | viper151 | 2025-08-12 | Feature | ⬜ Check |
| 144 | refactor: remove unnecessary project fetching | viper151 | 2025-08-11 | Refactor | ⬜ Check |
| 142 | feat: Local/Project MCPs and Import from JSON | viper151 | 2025-08-11 | Feature | ⬜ Check |
| 141 | style: remove revert rule causing unexpected transparency | dorage | 2025-08-11 | UI | ⬜ Check |
| 133 | Fix command escaping in claude-cli.js | WolCarlos | 2025-08-01 | Security | ⬜ Check |
| 119 | Update vite.config.js for websocket proxy configuration | ismaslov | 2025-08-06 | Config | ⬜ Check |
| 112 | Remove executable permissions from non-script files | Difocd | 2025-08-06 | Cleanup | ⬜ Check |
| 97 | fix(sidebar): display project name instead of full path | mkdir3 | 2025-08-01 | UI | ⬜ Check |
| 66 | feat: Publish branch functionality | viper151 | 2025-07-14 | Feature | ⬜ Check |
| 65 | feat: Add delete functionality for untracked files | viper151 | 2025-07-14 | Feature | ⬜ Check |
| 62 | feat: add ctrl+enter send option & fix IME problem | sarashinanikki | 2025-07-21 | Feature | ⬜ Check |
| 55 | fix: resolve React errors and localStorage quota issues | krzemienski | 2025-07-23 | Bug fix | ⬜ Check |
| 51 | Fix: Prevent race condition in user registration | Mirza-Samad-Ahmed-Baig | 2025-07-23 | Bug fix | ⬜ Check |
| 48 | Added starred project and UX enhancements | viper151 | 2025-07-12 | Feature | ⬜ Check |
| 46 | feat: Add image upload with drag & drop, clipboard paste | lvalics | 2025-07-12 | Feature | ⬜ Check |
| 44 | feat: Add project search filter to sidebar | lvalics | 2025-07-12 | Feature | ⬜ Check |
| 37 | feat: Add file metadata display with view modes | lvalics | 2025-07-12 | Feature | ⬜ Check |
| 36 | feat: Add project sorting by date option | lvalics | 2025-07-12 | Feature | ⬜ Check |
| 34 | Plan mode and upgrading to Vite 7 | viper151 | 2025-07-11 | Feature | ⬜ Check |
| 29 | Login | viper151 | 2025-07-10 | Feature | ⬜ Check |
| 7 | add node-fetch dependency | dcardamo | 2025-07-08 | Deps | ⬜ Check |
| 2 | Dev | viper151 | 2025-07-04 | Initial | ⬜ Check |

---

## Closed PRs - Not Merged (52 total)

These were closed without merging - may contain useful ideas or code:

### Worth Reviewing

| # | Title | Author | Created | Category | Notes |
|---|-------|--------|---------|----------|-------|
| 258 | Feature/terminal enhancements | sammykenny2 | 2025-12-11 | Feature | Terminal improvements |
| 252 | feat: add Claude Opus 4.5 model selection | vdaubry | 2025-12-06 | Feature | Model selection |
| 246 | Add warning log for unknown WebSocket message types | terrylica | 2025-11-26 | Debug | Useful for debugging |
| 237 | feat: add sub-directory deployment support | yingca1 | 2025-11-22 | Infra | Superseded by #238 |
| 232 | Add multiple providers for claude code (z.ai) | maksm | 2025-11-14 | Feature | Multi-provider support |
| 219 | CodeRabbit Generated Unit Tests | coderabbitai[bot] | 2025-10-31 | Tests | Vitest infrastructure |
| 186 | Fix: Resolve syntax error preventing dev startup | ghrud92 | 2025-08-29 | Bug fix | Startup fix |
| 174 | feat: Add automatic RTL/Hebrew text support | AlexSuprun | 2025-08-23 | i18n | Earlier RTL attempt |
| 172 | feat: Add Electron desktop application wrapper | AlexSuprun | 2025-08-23 | Feature | Earlier Electron attempt |
| 159 | fix(cursor): stabilize live updates for streaming | xavierliang | 2025-08-16 | Bug fix | Superseded by #160 |
| 149 | feat: migrate to Authentik OIDC authentication | teddylabdog | 2025-08-13 | Security | OIDC auth |
| 136 | feat: Add intelligent Claude CLI version detection | pbastos | 2025-08-05 | Feature | Version management |
| 129 | feat: Enhanced Claude Code UI with Complete Transparency | flamaso | 2025-07-30 | Feature | UI transparency |
| 128 | fix: Handle Japanese IME Enter key issue | macrocro | 2025-07-29 | Bug fix | IME handling |
| 127 | feat: add aws spot instance deployment | y4mau | 2025-07-29 | Infra | AWS deployment |
| 123 | Add GitHub OAuth authentication | y4mau | 2025-07-28 | Security | OAuth support |
| 121 | feat: Add dynamic port finding | y4mau | 2025-07-26 | Feature | Port management |
| 116 | fix: project path resolution for hyphenated names | NeaByteLab | 2025-07-23 | Bug fix | Earlier hyphen fix |
| 110 | feat: Add Windows Native Support | yuu1111 | 2025-07-22 | Feature | Windows support |
| 105 | feat: Add comprehensive deployment system Linux/WSL | gowerlin | 2025-07-20 | Infra | Linux deployment |
| 103 | feat: 建立獨立執行封裝與部署系統 | gowerlin | 2025-07-20 | Infra | Chinese docs |
| 100 | add docker setup and add pull app | yagi2 | 2025-07-18 | Infra | Docker + pull |
| 99 | Add BASE_PATH Support for Reverse Proxy | LintaoAmons | 2025-07-18 | Infra | Reverse proxy |
| 92 | Fix: Stop button now reliably cancels Claude generation | IDevSharma1 | 2025-07-16 | Bug fix | Cancel generation |
| 42 | Checkpoints and other enhancements | viper151 | 2025-07-12 | Feature | Checkpoints |
| 26 | feat(config): unify CORS and Vite allowedHosts | LucasRoesler | 2025-07-10 | Config | CORS config |
| 22 | Add project sorting options to Tools settings | lvalics | 2025-07-09 | Feature | Sorting options |
| 6 | feat: add starred projects feature to sidebar | absir1949 | 2025-07-07 | Feature | Earlier starred |

### Skip (Duplicates, Abandoned, or Superseded)

| # | Title | Author | Reason |
|---|-------|--------|--------|
| 254 | Claude/fix cloud command shadowing... | ibrahimshadev | Garbled title, unclear |
| 193 | Circleci project setup | evgenygurin | CI config only |
| 180 | Frontend UI changes | jayadeepk | Generic, no details |
| 176 | Add claude GitHub actions | ghrud92 | Auto-generated |
| 171 | feat: Add Electron desktop wrapper | AlexSuprun | Duplicate of #172 |
| 167 | Add claude GitHub actions | Llompi | Auto-generated |
| 166 | feat: add allowedHosts env var | roykim98 | Similar to merged |
| 163 | Update README.md | yangchen0991 | README only |
| 162 | style: Improve PWA experience | dorage | Superseded by #188 |
| 161 | Fix: version matching regex | dorage | Minor |
| 139 | Dev | bosenger | Generic dev branch |
| 124 | Render markdown | y4mau | Duplicate of #125 |
| 102 | Auto-translate README and Wiki | openaitx-system | Auto-generated |
| 30 | Develop | edapinheiro | Generic dev branch |
| 25 | Login feature | coruhoorhan | Superseded by #29 |
| 24 | Added basic auth with token | RuKapSan | Superseded |
| 23 | primeiro commit | edapinheiro | Initial/test |

---

## Assessment Workflow

### Step 1: Review Open PRs (P1 first)

For each PR, determine:
1. **Does it solve a problem we have?** (Check against `claudecodeui-upgrades.md`)
2. **Is the implementation quality good?**
3. **Are there conflicts with our changes?**
4. **Estimated effort to integrate?**

### Step 2: Verify Merged PRs

```bash
# On claude-dev
cd ~/workspace/claudecodeui
git log --oneline | head -50
# Verify key merged PRs are present
```

### Step 3: Evaluate Closed-Not-Merged

Some may have valuable code even if not merged:
- Check if superseded by better implementation
- Check if conflicts were the issue (may be resolvable now)
- Check if maintainer feedback can be addressed

---

## Quick Commands

```bash
# Fetch a specific PR for review
git fetch upstream pull/NUMBER/head:pr-NUMBER
git checkout pr-NUMBER

# Compare PR to main
git diff main..pr-NUMBER --stat
git diff main..pr-NUMBER -- server/  # Just server changes
git diff main..pr-NUMBER -- src/     # Just frontend changes

# See PR commit history
git log main..pr-NUMBER --oneline

# Cherry-pick specific commits
git cherry-pick <sha>

# Merge entire PR
git merge pr-NUMBER
```

---

## Category Summary

| Category | Open | Merged | Closed |
|----------|------|--------|--------|
| Feature | 15 | 25 | 18 |
| Bug fix | 7 | 12 | 8 |
| Infra/Docker | 6 | 2 | 10 |
| i18n | 4 | 0 | 1 |
| Security | 1 | 2 | 2 |
| UI | 2 | 6 | 2 |
| Config | 1 | 2 | 3 |
| Tests | 0 | 0 | 1 |
| Other | 1 | 6 | 7 |

---

## Next Steps

1. [x] Complete viability assessment for all P1 PRs ✅
2. [x] Complete viability assessment for all P2 PRs ✅
3. [x] Complete viability assessment for all P3 PRs ✅
4. [x] Complete viability assessment for all P4 PRs ✅
5. [ ] Verify all merged PRs are in fork
6. [ ] Begin merging PRs in recommended order (start with #249)
7. [ ] Test after each merge
8. [ ] Document any custom modifications needed

### Merge Execution Plan

```bash
cd ~/workspace/claudecodeui

# 1. Ensure fork is up to date with upstream
git fetch upstream
git checkout main
git merge upstream/main

# 2. Merge PRs in order (fetch each first)
git fetch upstream pull/249/head:pr-249
git merge pr-249  # Permission Dialog (P1)

# Test and verify

git fetch upstream pull/259/head:pr-259
git merge pr-259  # Hyphen Path Fix (P2)

# Continue with remaining PRs...
```
