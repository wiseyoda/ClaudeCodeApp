# Design Decisions

| Area | Decision |
|------|----------|
| Navigation | iPhone TabView (Projects, Terminal, Commands, Settings) + primary New Project action; iPad NavigationSplitView |
| Settings | Grouped Form in sheet (iOS Settings-style) |
| iPad | Split View + Slide Over support; Stage Manager + external display deferred beyond redesign |
| Modals | Sheets for quick actions, push for main flows |
| State | @Observable + actors; repository-layer caching/error pipelines (no ErrorStore/TaskState/ProjectCache) |
| Design | Liquid Glass throughout; iPhone-first polish |
| Liquid Glass Intensity | System slider only; no in-app override |
| Messages | 3 card types: Chat, Tool, System; action bars on all cards |
| Status | Streaming-only status banner above input; status message collection in Settings |
| Tools | Smart grouping/compaction is core; WritePreview expands to full-screen viewer |
| Commands | Slash command palette + autocomplete; local command output as system cards |
| Offline | Lightweight client handling; cli-bridge replay/timeout; NetworkMonitor-driven banners |
| Background | Short background continuity (best-effort, target ~30 min if iOS allows) |
| Git | cli-bridge status only; no local git integration |
| Diagnostics | Consolidated Diagnostics (error analytics + insights); Firebase later |
| Firebase | Firebase integration after redesign; define provider abstractions now |
| Platform | Widgets, Control Center, Live Activities, Siri (per issues) |
| Source of Truth | `docs/design/` + `assets/` (Figma optional, add link if available) |
