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
| `/home/dev/.cloudcli-data` | `/share/dev/claude-dev/cloudcli-data/` | CloudCLI auth database |
| `/home/dev/.ssh/*` | `/share/dev/claude-dev/ssh/` | SSH keys |
| `/home/dev/.gitconfig` | `/share/dev/claude-dev/home/.gitconfig` | Git config |
| `/home/dev/.bashrc` | `/share/dev/claude-dev/home/.bashrc` | Shell config |
| `/home/dev/.tmux.conf` | `/share/dev/claude-dev/home/.tmux.conf` | Tmux config |

### Critical Files

| File | Location | Notes |
|------|----------|-------|
| `.claude.json` | Inside `/home/dev/.claude/` | Symlinked to `~/.claude.json` by entrypoint |
| `.credentials.json` | Inside `/home/dev/.claude/` | Anthropic API credentials |
| `auth.db` | `/home/dev/.cloudcli-data/auth.db` | WebUI login/API keys |
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

## Services

### PM2 Managed Process

```
claude-ui (cloudcli start) → port 8080
```

PM2 auto-restarts on crash and persists across container restarts via `dump.pm2`.

### SSH Daemon

- Port 22 (container) → mapped by QNAP
- Key-based auth only (password disabled)
- Root login disabled

## Known Issues & Fixes

### Issue: EBUSY on .claude.json

**Cause**: `.claude.json` was bind-mounted as a separate file from `.claude` directory.
Node.js atomic writes create temp file then rename, which fails across mount boundaries.

**Fix**: Remove separate file mount, use symlink in entrypoint:
```bash
ln -sf /home/dev/.claude/.claude.json /home/dev/.claude.json
```

### Issue: Auth Database Lost on Rebuild

**Cause**: `auth.db` stored in npm global install directory, not persisted.

**Fix**: Set `DATABASE_PATH` environment variable pointing to persisted location:
```yaml
environment:
  - DATABASE_PATH=/home/dev/.cloudcli-data/auth.db
```

## Container Rebuild Procedure

### Pre-Rebuild Checklist

1. Backup auth.db (if not already persisted):
   ```bash
   docker cp claude-dev:/usr/local/lib/node_modules/@siteboon/claude-code-ui/server/database/auth.db \
     /share/dev/claude-dev/backups/auth.db.$(date +%Y%m%d)
   ```

2. Backup npm cache (if not already persisted):
   ```bash
   docker cp claude-dev:/home/dev/.npm /share/dev/claude-dev/npm-cache-backup/
   ```

3. Verify critical files exist on host:
   ```bash
   ls -la /share/dev/claude-dev/claude-settings/.claude.json
   ls -la /share/dev/claude-dev/claude-settings/.credentials.json
   ```

### Rebuild Commands

```bash
cd /share/dev/claude-dev
docker-compose down
docker-compose up -d --build
docker logs -f claude-dev  # Watch startup
```

### Post-Rebuild Verification

```bash
# Check services
docker exec claude-dev pm2 list
curl http://localhost:8080/health

# Test SSH
ssh claude-dev

# Test Claude CLI
ssh claude-dev "claude --version"
```

## File Locations Reference

### On QNAP Host (`/share/dev/claude-dev/`)

```
claude-dev/
├── Dockerfile
├── docker-compose.yml
├── entrypoint.sh
├── backups/              # Manual backups
│   └── auth.db.backup
├── workspace/            # Code projects
├── claude-settings/      # ~/.claude mount
│   ├── .claude.json
│   ├── .credentials.json
│   ├── projects/
│   ├── debug/
│   └── ...
├── cloudcli-data/        # CloudCLI database
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

## Troubleshooting

### Container Won't Start

```bash
docker logs claude-dev
# Check for permission issues on mounts
```

### WebUI Not Responding

```bash
docker exec claude-dev pm2 logs claude-ui
docker exec claude-dev pm2 restart claude-ui
```

### Claude CLI Crashes with EBUSY

Check that `.claude.json` is NOT separately mounted. Should be symlinked.

### Lost API Keys After Rebuild

Restore from backup:
```bash
cp /share/dev/claude-dev/backups/auth.db.backup \
   /share/dev/claude-dev/cloudcli-data/auth.db
docker exec claude-dev pm2 restart claude-ui
```

## Version History

| Date | Change |
|------|--------|
| 2025-12-27 | Fixed EBUSY error, added auth.db persistence, npm cache persistence |
| 2025-12-26 | Initial container setup |
