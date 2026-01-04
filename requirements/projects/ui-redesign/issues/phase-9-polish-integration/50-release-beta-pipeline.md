---
number: 50
title: Release and Beta Pipeline
phase: phase-9-polish-integration
status: pending
completed_by: null
completed_at: null
verified_by: null
verified_at: null
commit: null
spot_checked: false
blocked_reason: null
---

# Issue 50: Release and Beta Pipeline

**Phase:** 9 (Polish & Integration)
**Priority:** Medium
**Status:** Not Started
**Depends On:** 44 (Debug Tooling), 45 (Feature Flags)
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Goal

Define and implement a repeatable release and TestFlight beta pipeline that enables consistent, reliable app distribution with proper versioning, environment configuration, and rollback capabilities.

## Scope

- In scope:
  - Build versioning scheme
  - Release notes workflow
  - TestFlight distribution process
  - Environment configuration (dev/beta/release)
  - Rollback and hotfix procedures
  - Release checklist
- Out of scope:
  - Marketing campaigns
  - App Store listing copy (Issue #51)
  - CI/CD infrastructure setup
  - Automated testing in pipeline (Issue #40)

## Non-goals

- Full automation beyond what can be maintained
- Multiple parallel release tracks
- A/B testing infrastructure

## Dependencies

- Issue #44 (Debug Tooling) for diagnostics in release builds
- Issue #45 (Feature Flags) for gating during rollout

## Touch Set

- Files to create:
  - `scripts/release.sh`
  - `scripts/bump-version.sh`
  - `requirements/projects/ui-redesign/docs/workflows/release-pipeline.md`
- Files to modify:
  - `Config/Version.xcconfig` (versioning)
  - `CHANGELOG.md` (release notes)
  - `.github/workflows/` (if using GitHub Actions)

---

## Versioning Scheme

### Semantic Versioning

Format: `MAJOR.MINOR.PATCH` (e.g., `2.1.3`)

| Component | When to Increment | Example |
|-----------|------------------|---------|
| **MAJOR** | Breaking changes, major redesigns | 1.x → 2.0 for iOS 26 redesign |
| **MINOR** | New features, backwards-compatible | 2.0 → 2.1 for new widgets |
| **PATCH** | Bug fixes, performance improvements | 2.1 → 2.1.1 for crash fix |

### Build Number

Format: `YYYYMMDDHHMM` (timestamp-based)

Example: `202601031430` for January 3, 2026 at 2:30 PM

```bash
# Generate build number
BUILD_NUMBER=$(date +%Y%m%d%H%M)
```

### Version.xcconfig

```xcconfig
// Config/Version.xcconfig
MARKETING_VERSION = 2.0.0
CURRENT_PROJECT_VERSION = 202601031430
```

### Version Bump Script

```bash
#!/bin/bash
# scripts/bump-version.sh

set -e

BUMP_TYPE=${1:-patch}  # major, minor, or patch
VERSION_FILE="Config/Version.xcconfig"

# Read current version
CURRENT=$(grep MARKETING_VERSION "$VERSION_FILE" | cut -d= -f2 | tr -d ' ')
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

case $BUMP_TYPE in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
    *)
        echo "Usage: bump-version.sh [major|minor|patch]"
        exit 1
        ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
BUILD_NUMBER=$(date +%Y%m%d%H%M)

# Update xcconfig
cat > "$VERSION_FILE" << EOF
// Auto-generated - do not edit manually
MARKETING_VERSION = $NEW_VERSION
CURRENT_PROJECT_VERSION = $BUILD_NUMBER
EOF

echo "Bumped version to $NEW_VERSION (build $BUILD_NUMBER)"
```

---

## Release Channels

### Development (dev)

- **Purpose**: Daily development builds
- **Distribution**: Local only, Simulator
- **Feature Flags**: All enabled, overridable
- **Logging**: Verbose debug logging
- **Server**: `http://localhost:3100`

### Beta (TestFlight)

- **Purpose**: Pre-release testing
- **Distribution**: TestFlight internal/external testers
- **Feature Flags**: Staged rollout via flags
- **Logging**: Info level, crash reporting enabled
- **Server**: Production or staging

### Release (App Store)

- **Purpose**: Public distribution
- **Distribution**: App Store
- **Feature Flags**: Release-ready features only
- **Logging**: Minimal, crash reporting only
- **Server**: Production

### Build Configuration

```swift
// CodingBridge/App/BuildConfig.swift
enum BuildConfig {
    #if DEBUG
    static let environment: Environment = .development
    #elseif BETA
    static let environment: Environment = .beta
    #else
    static let environment: Environment = .release
    #endif

    enum Environment {
        case development
        case beta
        case release

        var defaultServerURL: String {
            switch self {
            case .development:
                return "http://localhost:3100"
            case .beta, .release:
                return "https://api.codingbridge.app"
            }
        }

        var isDebugLoggingEnabled: Bool {
            self == .development
        }

        var areCrashReportsEnabled: Bool {
            self != .development
        }
    }
}
```

---

## TestFlight Distribution

### Internal Testing

| Step | Action |
|------|--------|
| 1 | Archive build with Release configuration |
| 2 | Upload to App Store Connect |
| 3 | Auto-distribute to internal testers |
| 4 | Collect feedback via TestFlight |

### External Testing

| Step | Action |
|------|--------|
| 1 | Complete internal testing |
| 2 | Submit for Beta App Review |
| 3 | Add external testers via link or groups |
| 4 | Monitor crash reports and feedback |
| 5 | Iterate with new builds |

### TestFlight Groups

| Group | Purpose | Access |
|-------|---------|--------|
| **Core Team** | Immediate access, all builds | Automatic |
| **Beta Testers** | Pre-release testing | After review |
| **External Beta** | Wider beta audience | After review |

---

## Release Checklist

### Pre-Release (1 week before)

- [ ] All planned features complete and merged
- [ ] Feature flags set for release configuration
- [ ] Code review checklist applied (Issue #60)
- [ ] All tests passing (`xcodebuild test`)
- [ ] No critical or high-severity bugs open
- [ ] Performance benchmarks reviewed (Issue #58)
- [ ] Accessibility audit complete (Issue #38)
- [ ] Privacy manifest updated (Issue #49)

### Build Preparation

- [ ] Version bumped appropriately
- [ ] CHANGELOG.md updated with release notes
- [ ] Debug logging disabled for release
- [ ] Crash reporting configured
- [ ] App icons and launch screen verified
- [ ] Archive build created
- [ ] Archive validated (no errors/warnings)

### TestFlight Submission

- [ ] Build uploaded to App Store Connect
- [ ] What's New text prepared
- [ ] Internal testing completed (min 24 hours)
- [ ] Crash reports reviewed
- [ ] Beta App Review submitted (external)
- [ ] External testing completed (min 48 hours)

### App Store Submission

- [ ] App Store metadata updated (Issue #51)
- [ ] Screenshots current
- [ ] Review notes prepared (if needed)
- [ ] Build submitted for review
- [ ] Review passed
- [ ] Release date set
- [ ] Release confirmed

### Post-Release

- [ ] Monitor crash reports
- [ ] Monitor App Store reviews
- [ ] Respond to critical issues within 24 hours
- [ ] Update ROADMAP.md with shipped items
- [ ] Tag release in git

---

## Release Script

```bash
#!/bin/bash
# scripts/release.sh

set -e

VERSION=${1:?Usage: release.sh <version>}
SCHEME="CodingBridge"
ARCHIVE_PATH="build/CodingBridge.xcarchive"
EXPORT_PATH="build/export"

echo "🚀 Starting release for version $VERSION"

# 1. Verify clean working directory
if [[ -n $(git status --porcelain) ]]; then
    echo "❌ Working directory not clean. Commit or stash changes."
    exit 1
fi

# 2. Verify on main branch
BRANCH=$(git branch --show-current)
if [[ "$BRANCH" != "main" ]]; then
    echo "❌ Must be on main branch. Currently on: $BRANCH"
    exit 1
fi

# 3. Pull latest
echo "📥 Pulling latest changes..."
git pull origin main

# 4. Run tests
echo "🧪 Running tests..."
xcodebuild test \
    -project CodingBridge.xcodeproj \
    -scheme "$SCHEME" \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
    -quiet

# 5. Archive
echo "📦 Creating archive..."
xcodebuild archive \
    -project CodingBridge.xcodeproj \
    -scheme "$SCHEME" \
    -archivePath "$ARCHIVE_PATH" \
    -destination 'generic/platform=iOS'

# 6. Export for App Store
echo "📤 Exporting for App Store..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist ExportOptions.plist

# 7. Upload to App Store Connect
echo "☁️ Uploading to App Store Connect..."
xcrun altool --upload-app \
    -f "$EXPORT_PATH/CodingBridge.ipa" \
    -t ios \
    --apiKey "$APP_STORE_API_KEY" \
    --apiIssuer "$APP_STORE_API_ISSUER"

# 8. Tag release
echo "🏷️ Creating git tag..."
git tag -a "v$VERSION" -m "Release $VERSION"
git push origin "v$VERSION"

echo "✅ Release $VERSION complete!"
echo "   Next steps:"
echo "   1. Update TestFlight 'What's New'"
echo "   2. Submit for review in App Store Connect"
```

---

## Rollback Procedures

### TestFlight Rollback

1. Stop distributing current build (expire it)
2. Upload previous known-good archive
3. Distribute to testers
4. Communicate issue to testers

### App Store Rollback

| Scenario | Action |
|----------|--------|
| **Critical bug found before review** | Cancel submission, fix, resubmit |
| **Critical bug found during review** | Cancel submission, fix, resubmit |
| **Critical bug found after release** | Expedited review for hotfix |
| **Low-severity bug** | Include fix in next regular release |

### Hotfix Process

1. Create branch from release tag: `hotfix/X.Y.Z`
2. Apply minimal fix only
3. Bump patch version
4. Full testing of fix
5. Expedited release through TestFlight
6. Submit with expedited review request
7. Merge hotfix back to main

---

## Release Notes Format

### CHANGELOG.md Entry

```markdown
## [2.1.0] - 2026-01-15

### Added
- Widget support for agent status (#18)
- Live Activities for long-running tasks (#20)
- Keyboard shortcuts for iPad (#22)

### Changed
- Redesigned settings with grouped layout (#27)
- Improved message list performance (#11)

### Fixed
- WebSocket reconnection reliability (#34)
- Memory leak in long chat sessions (#56)

### Security
- Updated SSH key handling (#42)
```

### TestFlight What's New

```
What's New in 2.1.0:

• Home screen widgets show agent status
• Live Activities track progress on lock screen
• Full keyboard shortcut support on iPad
• Redesigned settings for easier navigation
• Improved performance for long conversations

Known Issues:
• Widget may take up to 15 minutes to refresh

Please report any issues via TestFlight feedback.
```

---

## Acceptance Criteria

- [ ] Versioning scheme documented
- [ ] Build configuration for all environments
- [ ] Version bump script working
- [ ] Release script automated
- [ ] TestFlight distribution process documented
- [ ] Release checklist complete
- [ ] Rollback procedures documented
- [ ] Hotfix process defined
- [ ] Release notes format standardized

## Testing

- [ ] Version bump script tested for major/minor/patch
- [ ] Archive build completes without errors
- [ ] Upload to TestFlight successful
- [ ] Internal testers receive build
- [ ] Release script runs end-to-end (dry run)
