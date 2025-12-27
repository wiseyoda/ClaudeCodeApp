# Claude Code iOS App - Requirements Overview

## Project Goal

Create a native iOS application that provides a mobile-friendly interface to Claude Code, enabling developers to interact with Claude CLI from their iPhone or iPad while away from their desk.

## Background

The [claude-code-webui](https://github.com/sugyan/claude-code-webui) project provides a web-based interface for Claude Code. This iOS app acts as a native client for that same backend, providing a more polished mobile experience.

## Target Users

- Developers who use Claude Code for coding assistance
- Users who want to interact with Claude Code from mobile devices
- Teams running Claude Code on remote servers (NAS, cloud, etc.)

## Key Requirements

### Functional Requirements

1. **Project Management**
   - List all available projects from the backend
   - Display project name, path, and session count
   - Navigate to project chat view
   - Clone projects from GitHub URL
   - Create new empty projects
   - Delete projects from list (with confirmation)
   - Project registration with Claude via session files

2. **Session Management**
   - Session selection for resuming conversations
   - Full-screen session picker with summaries and timestamps
   - Rename sessions with custom names
   - Delete sessions with swipe-to-delete
   - Export sessions as markdown with share sheet

3. **Chat Interface**
   - Send messages to Claude (text, voice, or with images)
   - Receive streaming responses in real-time via WebSocket
   - Display tool usage with collapsible sections
   - Display tool results (truncated with expand option)
   - Show thinking/reasoning blocks (collapsible)
   - Diff visualization for Edit tool changes
   - TodoWrite visual checklist with status colors
   - AskUserQuestion interactive selection UI
   - Code blocks with syntax highlighting and copy button
   - Support multi-turn conversations via session persistence
   - Copy and share messages via context menu

4. **Slash Commands**
   - `/clear` - Clear conversation and start fresh
   - `/new` - Start a new session
   - `/init` - Create/modify CLAUDE.md (via Claude)
   - `/resume` - Open session picker
   - `/compact` - Compact conversation to save context
   - `/status` - Show connection and session info
   - `/exit` - Return to project list
   - `/help` - Show command reference

5. **File Browser & References**
   - Browse project files via SSH
   - Breadcrumb navigation for directories
   - Search/filter files by name
   - @ button to insert file references into prompts

6. **Message Persistence**
   - Save last 50 messages per project (file-based storage)
   - Auto-save draft input text
   - Load history on view appear
   - Clear history with "New Chat" button

7. **Voice Input**
   - Speech-to-text via iOS Speech Recognition
   - Real-time transcription with partial results
   - Recording indicator in input bar

8. **Image Attachments**
   - Photo library picker integration
   - Image preview before sending
   - Images displayed inline in messages

9. **SSH Terminal**
   - Native SSH client via Citadel library
   - Special keys bar (Ctrl+C, Tab, arrows, etc.)
   - Password authentication with saved credentials
   - Auto-connect with stored settings

10. **Configuration**
    - Configurable backend server URL
    - SSH host/port/username/password
    - Font size preferences (XS/S/M/L/XL)
    - Theme selection (System/Dark/Light)
    - Claude mode selector (normal/plan/bypass)
    - Skip permissions toggle
    - Show thinking blocks toggle
    - Auto-scroll toggle
    - Project sort order (name/date)
    - Persist settings across app launches

11. **Notifications**
    - Local notifications when tasks complete (background only)
    - Request notification permissions on launch

### Non-Functional Requirements

1. **Performance**
   - Streaming responses must feel responsive
   - App should handle long conversations without lag
   - Exponential backoff reconnection (1s→2s→4s→8s + jitter)

2. **Security**
   - Rely on network-level security (Tailscale)
   - No credentials stored in the app (backend handles auth)
   - SSH credentials stored locally via UserDefaults

3. **Usability**
   - CLI-inspired theme with light/dark mode support
   - Support for iOS 17.0+
   - Works on iPhone and iPad
   - VoiceOver accessibility labels on interactive elements

4. **Quality**
   - 28+ unit tests for parsers and utilities
   - Structured logging via Logger utility
   - Unified error handling via AppError

## Completed Features

- ✅ Real-time streaming chat
- ✅ Tool use visualization with collapsible sections
- ✅ Diff viewer for Edit tool
- ✅ TodoWrite visual checklist
- ✅ AskUserQuestion interactive UI
- ✅ Voice input with Speech framework
- ✅ Image attachments
- ✅ SSH terminal
- ✅ File browser with @ references
- ✅ Project clone from GitHub
- ✅ Project creation and deletion
- ✅ Session rename, delete, export
- ✅ Slash commands
- ✅ Copy/share context menus
- ✅ Light/dark theme support
- ✅ File-based message persistence
- ✅ Unit test coverage

## Out of Scope (Current Version)

- Push notifications (APNs - currently uses local notifications)
- Offline mode
- Multiple backend server profiles
- File attachments beyond images
- GitHub OAuth integration
- Auto-sync from GitHub (background git pull)
- iPad sidebar navigation
