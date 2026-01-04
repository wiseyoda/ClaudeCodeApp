# CodingBridge UI Redesign

Entry point for the iOS 26 redesign. This README stays short and links to the canonical specs.

## Quick Start (Agents)

1. Read the status dashboard: [STATUS.md](STATUS.md)
2. Pick a task from the issue index: [issues/README.md](issues/README.md)
3. Use the doc map to find the right specs: [docs/README.md](docs/README.md)

## Sources of Truth

- Build settings: [docs/build/README.md](docs/build/README.md)
- Contracts (models + wire format): [docs/contracts/README.md](docs/contracts/README.md)
- Architecture (data + UI): [docs/architecture/README.md](docs/architecture/README.md)
- Design system: [docs/design/README.md](docs/design/README.md)
- Execution guardrails: [docs/workflows/guardrails.md](docs/workflows/guardrails.md)

## Overview

- Vision: [docs/overview/vision.md](docs/overview/vision.md)
- Target platform: [docs/overview/platform.md](docs/overview/platform.md)
- Design decisions: [docs/overview/design-decisions.md](docs/overview/design-decisions.md)

## What Gets Replaced

- iPhone navigation: MainTabView + HomeView card grid -> Liquid Glass TabView with simplified Projects surface and a primary action for New Project
- Chat status bar -> streaming-only status banner above input, with session info moved to toolbar/subtitle chips
- StatusBubbleView -> StatusMessageBannerView (animated, collection-based messages)
- Tool rendering -> core grouping/compaction plus WritePreview full-screen viewer and shared MessageActionBar
- Error analytics/insights -> consolidated Diagnostics view

## What Gets Removed

- Client-side git status (GitStatusCoordinator); cli-bridge status only
- Heavy offline approval queue persistence; rely on cli-bridge replay/timeout with lightweight client handling
