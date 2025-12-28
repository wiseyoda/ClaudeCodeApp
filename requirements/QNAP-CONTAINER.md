# QNAP Claude-Dev Container Configuration

> Complete documentation for the Claude Code development container running on QNAP NAS.

## Quick Reference

| Item | Value |
|------|-------|
| Container Name | `claude-dev` |
| QNAP Host | `192.168.0.199` (Tailscale: `10.0.3.2`) |
| SSH Access | `ssh claude-dev` or `ssh claude-dev-fwd` |
| WebUI | `http://10.0.3.2:8080` |
| Docker Path | `/share/CACHEDEV1_DATA/.qpkg/container-station/bin/docker` |
| Config Dir | `/share/dev/claude-dev/` |

## Persistence Architecture

### Persisted Directories (SAFE on rebuild)

| Container Path | Host Path | Purpose |
|----------------|-----------|---------|
| `/home/dev/workspace` | `/share/dev/claude-dev/workspace/` | Code projects |
| `/home/dev/.claude` | `/share/dev/claude-dev/claude-settings/` | Claude CLI config, credentials, history |
| `/home/dev/.config` | `/share/dev/claude-dev/config/` | App configs |
| `/home/dev/.pm2` | `/share/dev/claude-dev/pm2/` | PM2 process config |
| `/home/dev/.npm` | `/share/dev/claude-dev/npm-cache/` | npm cache (953MB) |
| `/home/dev/.cloudcli-data` | `/share/dev/claude-dev/cloudcli-data/` | CloudCLI auth database (API keys, logins) |
| `/home/dev/.ssh/*` | `/share/dev/claude-dev/ssh/` | SSH keys |
| `/home/dev/.gitconfig` | `/share/dev/claude-dev/home/.gitconfig` | Git config |
| `/home/dev/.bashrc` | `/share/dev/claude-dev/home/.bashrc` | Shell config |
| `/home/dev/.tmux.conf` | `/share/dev/claude-dev/home/.tmux.conf` | Tmux config |

### Critical Files

| File | Location | Notes |
|------|----------|-------|
| `.claude.json` | Inside `/home/dev/.claude/` | Symlinked to `~/.claude.json` by entrypoint |
| `.credentials.json` | Inside `/home/dev/.claude/` | Anthropic API credentials |
| `auth.db` | `/home/dev/.cloudcli-data/auth.db` | WebUI login/API keys - **CRITICAL** |
| `dump.pm2` | Inside `/home/dev/.pm2/` | PM2 process list |

## Installed Packages

### Global npm Packages

| Package | Version | Purpose |
|---------|---------|---------|
| `@anthropic-ai/claude-code` | 2.0.76 | Claude CLI |
| `@siteboon/claude-code-ui` | 1.12.0 | WebUI (cloudcli command) |
| `pm2` | 6.0.14 | Process manager |

### System Packages

| Package | Purpose |
|---------|---------|
| `openssh-server` | SSH access |
| `git`, `curl`, `wget` | Core tools |
| `vim`, `nano` | Editors |
| `tmux` | Terminal multiplexer |
| `htop`, `lsof`, `procps` | Process monitoring |
| `jq` | JSON processing |
| `rsync`, `file` | File utilities |
| `iproute2` | Networking (ip command) |
| `python3`, `build-essential` | npm native module compilation |

## Custom claudecodeui Fork

We use a fork of [siteboon/claudecodeui](https://github.com/siteboon/claudecodeui) with custom modifications for interactive permission approval.

**Fork Repository:** https://github.com/wiseyoda/claudecodeui

### Location

| Path | Description |
|------|-------------|
| `/home/dev/workspace/claudecodeui/` | Local fork source code |
| `/home/dev/workspace/claudecodeui/server/` | Backend server code |
| `/home/dev/workspace/claudecodeui/dist/` | Built frontend |

### Git Remotes

| Remote | URL | Purpose |
|--------|-----|---------|
| `origin` | `git@github.com:wiseyoda/claudecodeui.git` | Your fork (push changes here) |
| `upstream` | `git@github.com:siteboon/claudecodeui.git` | Original repo (pull updates) |

### Custom Modifications

**Session API Improvements:**
- `server/index.js`: Added `/api/projects/:name/sessions` endpoint with pagination
- `server/index.js`: Added `sessionType` field for filtering (display/agent/helper)
- `server/index.js`: Added `sessions-updated` WebSocket events for real-time updates
- Cache headers: 30s for projects, 15s for sessions

**Permission Approval System** (added 2025-12-28):
- `server/claude-sdk.js`: Added `canUseTool` callback for interactive permission requests
- `server/index.js`: Added WebSocket handler for `permission-response` messages
- Enables iOS app to show approval banner instead of error messages when bypass permissions is OFF

**Message Enhancements:**
- `textContent` normalized field for simpler message rendering
- `?batch=<ms>` WebSocket parameter for streaming batching

### Updating from Upstream

```bash
# SSH into container
ssh claude-dev
cd ~/workspace/claudecodeui

# Fetch and merge upstream changes
git fetch upstream
git merge upstream/main

# Resolve any conflicts (our changes are in server/claude-sdk.js and server/index.js)
# Reinstall dependencies if package.json changed
npm install

# Rebuild frontend
npm run build

# Restart PM2
pm2 restart claude-ui

# Push merged changes to your fork
git push origin main
```

### Re-applying Custom Changes After Merge

After merging upstream changes, re-apply custom modifications if they were overwritten. Check the git diff and ensure:
1. `handlePermissionResponse` is exported from `server/claude-sdk.js`
2. `canUseTool` callback is added to the SDK query options
3. `permission-response` handler exists in `server/index.js`

## Services

### PM2 Managed Process

```
claude-ui (local fork) → port 8080
```

**Critical**: PM2 must be started with these environment variables and the local fork path:
```bash
DATABASE_PATH=/home/dev/.cloudcli-data/auth.db PORT=8080 pm2 start /home/dev/workspace/claudecodeui/server/cli.js --name claude-ui
```

PM2 auto-restarts on crash and persists across container restarts via `dump.pm2`.

### SSH Daemon

- Port 22 (container) → mapped by QNAP
- Key-based auth only (password disabled)
- Root login disabled

## Known Issues & Fixes

### Issue: EBUSY on .claude.json

**Symptom**: Claude CLI crashes with `EBUSY: resource busy or locked, rename '.claude.json'`

**Cause**: `.claude.json` was bind-mounted as a separate file from `.claude` directory.
Node.js atomic writes create temp file then rename, which fails across mount boundaries.

**Fix**: Remove separate file mount from docker-compose.yml, use symlink in entrypoint:
```bash
# In entrypoint.sh
ln -sf /home/dev/.claude/.claude.json /home/dev/.claude.json
```

### Issue: Auth Database / API Keys Lost on Rebuild

**Symptom**: After container rebuild, WebUI shows "No API keys created yet"

**Cause**: `auth.db` was stored in npm global install directory (`/usr/local/lib/node_modules/@siteboon/claude-code-ui/server/database/auth.db`), not persisted.

**Fix**:
1. Mount persistent directory for cloudcli-data
2. Set `DATABASE_PATH` environment variable in docker-compose.yml AND in PM2 start command

```yaml
# docker-compose.yml
volumes:
  - /share/dev/claude-dev/cloudcli-data:/home/dev/.cloudcli-data
environment:
  - DATABASE_PATH=/home/dev/.cloudcli-data/auth.db
```

```bash
# entrypoint.sh - PM2 must explicitly get DATABASE_PATH
# Note: Uses local fork instead of global npm package
DATABASE_PATH=/home/dev/.cloudcli-data/auth.db PORT=8080 pm2 start /home/dev/workspace/claudecodeui/server/cli.js --name claude-ui
```

### Issue: PM2 Not Getting Environment Variables

**Symptom**: WebUI runs but uses wrong database (fresh instead of persisted)

**Cause**: PM2 doesn't inherit environment variables from docker-compose.yml automatically when using `su - dev -c`

**Fix**: Pass env vars explicitly in the pm2 start command:
```bash
su - dev -c "DATABASE_PATH=/home/dev/.cloudcli-data/auth.db PORT=8080 pm2 start /home/dev/workspace/claudecodeui/server/cli.js --name claude-ui"
```

**Verify**: Check PM2 environment:
```bash
docker exec -u dev claude-dev pm2 env 0 | grep -E 'DATABASE|PORT'
# Should show:
# DATABASE_PATH: /home/dev/.cloudcli-data/auth.db
# PORT: 8080
```

### Issue: Duplicate auth.db Files

**Symptom**: API keys visible in database but not in WebUI

**Cause**: Two auth.db files exist - persisted one and default one in npm directory

**Diagnosis**:
```bash
docker exec claude-dev find / -name 'auth.db' 2>/dev/null
# Should only show: /home/dev/.cloudcli-data/auth.db
# If also shows: /usr/local/lib/node_modules/.../auth.db - that's the problem
```

**Fix**: Remove the duplicate and restart:
```bash
docker exec claude-dev rm -f /usr/local/lib/node_modules/@siteboon/claude-code-ui/server/database/auth.db
docker exec -u dev claude-dev pm2 restart claude-ui
```

## Container Rebuild Procedure

### Pre-Rebuild Checklist

1. **Backup auth.db** (if migrating from old setup):
   ```bash
   DOCKER='/share/CACHEDEV1_DATA/.qpkg/container-station/bin/docker'
   $DOCKER cp claude-dev:/usr/local/lib/node_modules/@siteboon/claude-code-ui/server/database/auth.db \
     /share/dev/claude-dev/backups/auth.db.$(date +%Y%m%d)
   ```

2. **Backup current config files**:
   ```bash
   mkdir -p /share/dev/claude-dev/backups/$(date +%Y%m%d)
   cp /share/dev/claude-dev/docker-compose.yml /share/dev/claude-dev/backups/$(date +%Y%m%d)/
   cp /share/dev/claude-dev/Dockerfile /share/dev/claude-dev/backups/$(date +%Y%m%d)/
   cp /share/dev/claude-dev/entrypoint.sh /share/dev/claude-dev/backups/$(date +%Y%m%d)/
   ```

3. **Verify critical files exist on host**:
   ```bash
   ls -la /share/dev/claude-dev/claude-settings/.claude.json
   ls -la /share/dev/claude-dev/claude-settings/.credentials.json
   ls -la /share/dev/claude-dev/cloudcli-data/auth.db
   ```

### Rebuild Commands

```bash
# On QNAP (SSH as admin)
cd /share/dev/claude-dev
DOCKER='/share/CACHEDEV1_DATA/.qpkg/container-station/bin/docker'

# Stop and rebuild
$DOCKER compose down
$DOCKER compose up -d --build

# Watch startup
$DOCKER logs -f claude-dev
```

### Post-Rebuild Verification

```bash
DOCKER='/share/CACHEDEV1_DATA/.qpkg/container-station/bin/docker'

# 1. Check container health
$DOCKER ps --filter name=claude-dev
# Should show: (healthy)

# 2. Check PM2 status
$DOCKER exec -u dev claude-dev pm2 list
# Should show: claude-ui | online | 0 restarts

# 3. Verify PM2 environment variables
$DOCKER exec -u dev claude-dev pm2 env 0 | grep -E 'DATABASE|PORT'
# Should show:
# DATABASE_PATH: /home/dev/.cloudcli-data/auth.db
# PORT: 8080

# 4. Check WebUI health
$DOCKER exec claude-dev curl -s http://localhost:8080/health
# Should show: {"status":"ok",...}

# 5. Verify database location
$DOCKER exec -u dev claude-dev cloudcli status | grep -A2 'Database Location'
# Should show: /home/dev/.cloudcli-data/auth.db

# 6. Check for duplicate databases (should only be one)
$DOCKER exec claude-dev find / -name 'auth.db' 2>/dev/null
# Should ONLY show: /home/dev/.cloudcli-data/auth.db

# 7. Verify API keys exist
$DOCKER exec claude-dev sqlite3 /home/dev/.cloudcli-data/auth.db 'SELECT id, key_name FROM api_keys;'

# 8. Test SSH (from Mac)
ssh claude-dev "claude --version"

# 9. Update SSH known_hosts if needed (host key changes on rebuild)
ssh-keygen -R 10.0.3.2
ssh -o StrictHostKeyChecking=accept-new claude-dev "echo 'SSH works'"
```

### If API Keys Missing After Rebuild

```bash
# Check if PM2 has correct DATABASE_PATH
$DOCKER exec -u dev claude-dev pm2 env 0 | grep DATABASE_PATH

# If missing, restart PM2 with correct env:
$DOCKER exec -u dev claude-dev bash -c 'pm2 delete claude-ui; DATABASE_PATH=/home/dev/.cloudcli-data/auth.db PORT=8080 pm2 start /home/dev/workspace/claudecodeui/server/cli.js --name claude-ui; pm2 save'

# Remove any duplicate database
$DOCKER exec claude-dev rm -f /usr/local/lib/node_modules/@siteboon/claude-code-ui/server/database/auth.db

# Verify
$DOCKER exec -u dev claude-dev pm2 env 0 | grep DATABASE_PATH
```

## File Locations Reference

### On QNAP Host (`/share/dev/claude-dev/`)

```
claude-dev/
├── Dockerfile
├── docker-compose.yml
├── entrypoint.sh
├── backups/              # Manual backups
│   └── 20251227-152637/
│       ├── auth.db
│       ├── docker-compose.yml
│       ├── Dockerfile
│       └── entrypoint.sh
├── workspace/            # Code projects
├── claude-settings/      # ~/.claude mount
│   ├── .claude.json
│   ├── .credentials.json
│   ├── projects/
│   ├── debug/
│   └── ...
├── cloudcli-data/        # CloudCLI database (API keys, logins)
│   └── auth.db
├── config/               # ~/.config mount
├── pm2/                  # ~/.pm2 mount
├── npm-cache/            # ~/.npm mount
├── ssh/
│   └── authorized_keys
└── home/
    ├── .ssh/
    │   ├── id_ed25519
    │   └── id_ed25519.pub
    ├── .gitconfig
    ├── .bashrc
    ├── .tmux.conf
    └── claude-launcher.sh
```

### Inside Container

```
/home/dev/
├── .claude.json → .claude/.claude.json (symlink)
├── .claude/              # Full Claude config
├── .cloudcli-data/       # Database location
│   └── auth.db
├── .config/
├── .pm2/
├── .npm/
├── .ssh/
├── .gitconfig
├── .bashrc
├── .tmux.conf
├── claude-launcher.sh
└── workspace/
```

## Configuration Files

### docker-compose.yml

```yaml
services:
  claude-dev:
    build: .
    container_name: claude-dev
    hostname: claude-dev
    volumes:
      # Code and projects
      - /share/dev/claude-dev/workspace:/home/dev/workspace

      # Claude CLI configuration (all Claude data in one mount)
      - /share/dev/claude-dev/claude-settings:/home/dev/.claude
      # NOTE: .claude.json symlink created in entrypoint.sh (fixes EBUSY error)

      # CloudCLI/WebUI database (auth, API keys, login info)
      - /share/dev/claude-dev/cloudcli-data:/home/dev/.cloudcli-data

      # Application configs
      - /share/dev/claude-dev/config:/home/dev/.config
      - /share/dev/claude-dev/pm2:/home/dev/.pm2
      - /share/dev/claude-dev/npm-cache:/home/dev/.npm

      # SSH keys (read-only for security)
      - /share/dev/claude-dev/ssh/authorized_keys:/home/dev/.ssh/authorized_keys:ro
      - /share/dev/claude-dev/home/.ssh/id_ed25519:/home/dev/.ssh/id_ed25519:ro
      - /share/dev/claude-dev/home/.ssh/id_ed25519.pub:/home/dev/.ssh/id_ed25519.pub:ro

      # Shell configs (read-only)
      - /share/dev/claude-dev/home/.tmux.conf:/home/dev/.tmux.conf:ro
      - /share/dev/claude-dev/home/.bashrc:/home/dev/.bashrc:ro
      - /share/dev/claude-dev/home/claude-launcher.sh:/home/dev/claude-launcher.sh:ro

      # Git config (read-write for credential helpers)
      - /share/dev/claude-dev/home/.gitconfig:/home/dev/.gitconfig

    environment:
      - TZ=America/Chicago
      # CloudCLI database location - CRITICAL for persisting auth/API keys
      - DATABASE_PATH=/home/dev/.cloudcli-data/auth.db

    restart: unless-stopped
    network_mode: bridge

    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s
```

### Dockerfile

```dockerfile
FROM node:20-slim

# Install system packages
RUN apt-get update && apt-get install -y \
    openssh-server \
    git \
    curl \
    wget \
    sudo \
    ca-certificates \
    vim \
    nano \
    tmux \
    less \
    htop \
    lsof \
    procps \
    iproute2 \
    file \
    rsync \
    jq \
    python3 \
    build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /var/run/sshd

# Create dev user with passwordless sudo
RUN useradd -m -s /bin/bash dev \
    && echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Setup SSH directory
RUN mkdir -p /home/dev/.ssh \
    && chmod 700 /home/dev/.ssh

# Install Claude Code CLI, WebUI, and PM2
RUN npm install -g \
    @anthropic-ai/claude-code \
    @siteboon/claude-code-ui \
    pm2

# Create directories for persisted data
RUN mkdir -p /home/dev/.cloudcli-data \
    && mkdir -p /home/dev/.npm

# Set ownership
RUN chown -R dev:dev /home/dev

# SSH config - key-based auth only
RUN sed -i "s/#PermitRootLogin.*/PermitRootLogin no/" /etc/ssh/sshd_config \
    && sed -i "s/#PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config \
    && sed -i "s/#PubkeyAuthentication.*/PubkeyAuthentication yes/" /etc/ssh/sshd_config

EXPOSE 22 8080

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
```

### entrypoint.sh

```bash
#!/bin/bash
set -e

echo "[entrypoint] Starting claude-dev container..."

# CRITICAL: Create symlink for .claude.json
# Fixes EBUSY error - allows atomic file operations to work
echo "[entrypoint] Setting up .claude.json symlink..."
if [ -f /home/dev/.claude/.claude.json ]; then
    ln -sf /home/dev/.claude/.claude.json /home/dev/.claude.json
    echo "[entrypoint] ✓ Symlink created: ~/.claude.json -> ~/.claude/.claude.json"
else
    ln -sf /home/dev/.claude/.claude.json /home/dev/.claude.json
    echo "[entrypoint] Note: ~/.claude/.claude.json not found yet, symlink ready"
fi
chown -h dev:dev /home/dev/.claude.json

# Ensure proper ownership of mounted directories
echo "[entrypoint] Setting ownership..."
chown -R dev:dev /home/dev/.ssh 2>/dev/null || true
chown dev:dev /home/dev/.claude 2>/dev/null || true
chown dev:dev /home/dev/.config 2>/dev/null || true
chown dev:dev /home/dev/.pm2 2>/dev/null || true
chown dev:dev /home/dev/.npm 2>/dev/null || true
chown -R dev:dev /home/dev/.cloudcli-data 2>/dev/null || true

# CloudCLI database setup
echo "[entrypoint] Checking CloudCLI database..."
if [ ! -f /home/dev/.cloudcli-data/auth.db ]; then
    echo "[entrypoint] Note: auth.db will be created on first WebUI access"
fi

# Start Claude WebUI via PM2 (as dev user)
echo "[entrypoint] Starting Claude WebUI via PM2..."

# Delete existing process to ensure clean env vars
su - dev -c "pm2 delete claude-ui" 2>/dev/null || true

# Start with both PORT and DATABASE_PATH - CRITICAL for persistence
# Note: Uses local fork instead of global npm package for custom permission approval feature
su - dev -c "DATABASE_PATH=/home/dev/.cloudcli-data/auth.db PORT=8080 pm2 start /home/dev/workspace/claudecodeui/server/cli.js --name claude-ui" 2>/dev/null || \
    echo "[entrypoint] Warning: PM2 start returned non-zero"
echo "[entrypoint] ✓ PM2 started claude-ui"

# Save PM2 process list for resurrection on next start
su - dev -c "pm2 save" 2>/dev/null || true

# Brief wait to let PM2 process start
sleep 2

# Check if WebUI is running
if su - dev -c "pm2 list" 2>/dev/null | grep -q "claude-ui.*online"; then
    echo "[entrypoint] ✓ Claude WebUI is running on port 8080"
else
    echo "[entrypoint] ⚠ Claude WebUI may not be running, check 'pm2 logs claude-ui'"
fi

echo "[entrypoint] Starting SSH daemon..."

# Start SSH daemon (foreground - keeps container running)
exec /usr/sbin/sshd -D
```

## Troubleshooting

### Container Won't Start

```bash
DOCKER='/share/CACHEDEV1_DATA/.qpkg/container-station/bin/docker'
$DOCKER logs claude-dev
# Check for permission issues on mounts
```

### WebUI Not Responding

```bash
$DOCKER exec -u dev claude-dev pm2 logs claude-ui --lines 50
$DOCKER exec -u dev claude-dev pm2 restart claude-ui
```

### Claude CLI Crashes with EBUSY

Check that `.claude.json` is NOT separately mounted. Should be symlinked:
```bash
$DOCKER exec claude-dev ls -la /home/dev/.claude.json
# Should show: .claude.json -> /home/dev/.claude/.claude.json
```

### API Keys Not Showing in WebUI

1. Check PM2 has DATABASE_PATH:
   ```bash
   $DOCKER exec -u dev claude-dev pm2 env 0 | grep DATABASE_PATH
   ```

2. Check for duplicate databases:
   ```bash
   $DOCKER exec claude-dev find / -name 'auth.db' 2>/dev/null
   ```

3. Fix by restarting PM2 with correct env:
   ```bash
   $DOCKER exec -u dev claude-dev bash -c 'pm2 delete claude-ui; DATABASE_PATH=/home/dev/.cloudcli-data/auth.db PORT=8080 pm2 start /home/dev/workspace/claudecodeui/server/cli.js --name claude-ui; pm2 save'
   ```

### SSH Host Key Changed Warning

After container rebuild, SSH host keys change:
```bash
ssh-keygen -R 10.0.3.2
ssh -o StrictHostKeyChecking=accept-new claude-dev "echo 'SSH works'"
```

### Check Database Contents

```bash
# Install sqlite3 if needed
$DOCKER exec claude-dev apt-get update && apt-get install -y sqlite3

# View tables
$DOCKER exec claude-dev sqlite3 /home/dev/.cloudcli-data/auth.db '.tables'

# View API keys
$DOCKER exec claude-dev sqlite3 /home/dev/.cloudcli-data/auth.db 'SELECT id, key_name, created_at FROM api_keys;'

# View users
$DOCKER exec claude-dev sqlite3 /home/dev/.cloudcli-data/auth.db 'SELECT id, username FROM users;'
```

## Version History

| Date | Change |
|------|--------|
| 2025-12-28 | Switched to local claudecodeui fork for custom permission approval feature. PM2 now starts from `/home/dev/workspace/claudecodeui/server/cli.js` instead of global npm package. |
| 2025-12-27 | Fixed EBUSY error, added auth.db persistence, npm cache persistence, fixed PM2 env vars |
| 2025-12-26 | Initial container setup |
