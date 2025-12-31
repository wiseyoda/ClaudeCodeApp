# CLI Bridge Feature Request: Project & Git Management APIs

## Overview

The iOS app currently relies on SSH for several project and git management operations. To enable a fully REST API-based architecture (no SSH dependency), we request the following endpoints be added to cli-bridge.

## Requested Endpoints

### 1. Create Project

**Endpoint:** `POST /projects/create`

**Purpose:** Create a new project directory and optionally initialize it with Claude.

**Request Body:**
```json
{
  "name": "my-project",
  "baseDir": "~/workspace",  // optional, defaults to ~/workspace
  "initializeClaude": true   // optional, run `claude init` after creation
}
```

**Response:**
```json
{
  "success": true,
  "path": "/home/user/workspace/my-project",
  "initialized": true
}
```

**Errors:**
- `409 Conflict` - Project already exists
- `400 Bad Request` - Invalid project name

---

### 2. Clone Repository

**Endpoint:** `POST /projects/clone`

**Purpose:** Clone a git repository and register it as a Claude project.

**Request Body:**
```json
{
  "url": "https://github.com/user/repo.git",
  "baseDir": "~/workspace",  // optional
  "initializeClaude": true   // optional
}
```

**Response:**
```json
{
  "success": true,
  "path": "/home/user/workspace/repo",
  "initialized": true
}
```

**Errors:**
- `409 Conflict` - Repository already cloned
- `400 Bad Request` - Invalid git URL
- `502 Bad Gateway` - Git clone failed (include error message)

---

### 3. Delete Project

**Endpoint:** `DELETE /projects/{encoded-path}`

**Purpose:** Remove a project from Claude's project list (deletes `~/.claude/projects/{path}/` directory, not the actual project files).

**Response:**
```json
{
  "success": true
}
```

**Query Parameters:**
- `deleteFiles=true` - Also delete the actual project directory (dangerous, requires confirmation)

---

### 4. Git Pull

**Endpoint:** `POST /projects/{encoded-path}/git/pull`

**Purpose:** Pull latest changes from remote for a project.

**Response:**
```json
{
  "success": true,
  "message": "Already up to date.",
  "commits": 0
}
```

Or on success with changes:
```json
{
  "success": true,
  "message": "Fast-forward",
  "commits": 3,
  "files": ["src/index.ts", "package.json"]
}
```

**Errors:**
- `409 Conflict` - Merge conflicts detected
- `400 Bad Request` - Not a git repository
- `502 Bad Gateway` - Git pull failed

---

### 5. Git Status (Enhanced)

The existing `/projects` endpoint already returns basic git status. This is a request to enhance it with more details.

**Current Response:**
```json
{
  "git": {
    "branch": "main",
    "isClean": false,
    "uncommittedCount": 1
  }
}
```

**Requested Enhancement:**
```json
{
  "git": {
    "branch": "main",
    "isClean": false,
    "uncommittedCount": 1,
    "ahead": 2,           // commits ahead of remote
    "behind": 0,          // commits behind remote
    "hasUntracked": true, // has untracked files
    "hasStaged": false,   // has staged changes
    "remote": "origin",   // tracking remote
    "trackingBranch": "origin/main"
  }
}
```

---

### 6. Sub-Repository Discovery (Monorepo Support)

**Endpoint:** `GET /projects/{encoded-path}/subrepos`

**Purpose:** Discover nested git repositories within a project (for monorepo support).

**Query Parameters:**
- `maxDepth=2` - How deep to search for nested repos

**Response:**
```json
{
  "subrepos": [
    {
      "relativePath": "packages/api",
      "git": {
        "branch": "main",
        "isClean": true
      }
    },
    {
      "relativePath": "packages/web",
      "git": {
        "branch": "develop",
        "isClean": false,
        "uncommittedCount": 3
      }
    }
  ]
}
```

---

### 7. Sub-Repository Pull

**Endpoint:** `POST /projects/{encoded-path}/subrepos/{relative-path}/pull`

**Purpose:** Pull a specific sub-repository within a monorepo.

**Response:** Same as Git Pull endpoint.

---

## Priority

1. **High Priority** (blocks core functionality):
   - Git Pull (`POST /projects/{path}/git/pull`)
   - Delete Project (`DELETE /projects/{path}`)

2. **Medium Priority** (improves UX):
   - Create Project (`POST /projects/create`)
   - Clone Repository (`POST /projects/clone`)
   - Enhanced Git Status

3. **Low Priority** (advanced feature):
   - Sub-repository discovery and management

## Current Workaround

The iOS app currently shows an error message directing users to this document when these features are attempted. The app previously used SSH for these operations, but we're migrating to a fully API-based architecture.

## Contact

For questions about these requirements, please reference the iOS app codebase at:
- `CodingBridge/Views/NewProjectSheet.swift`
- `CodingBridge/Views/CloneProjectSheet.swift`
- `CodingBridge/ChatView.swift` (performAutoPull)
- `CodingBridge/ContentView.swift` (deleteProject, multi-repo functions)
