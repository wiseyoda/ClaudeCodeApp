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
   - Session selection for resuming conversations

2. **Chat Interface**
   - Send messages to Claude (text, voice, or with images)
   - Receive streaming responses in real-time via WebSocket
   - Display tool usage with collapsible sections
   - Display tool results (truncated with expand option)
   - Show thinking/reasoning blocks (collapsible)
   - Diff visualization for Edit tool changes
   - Code blocks with syntax highlighting and copy button
   - Support multi-turn conversations via session persistence

3. **Message Persistence**
   - Save last 50 messages per project
   - Auto-save draft input text
   - Load history on view appear
   - Clear history with "New Chat" button

4. **Voice Input**
   - Speech-to-text via iOS Speech Recognition
   - Real-time transcription with partial results
   - Recording indicator in input bar

5. **Image Attachments**
   - Photo library picker integration
   - Image preview before sending
   - Images displayed inline in messages

6. **SSH Terminal**
   - Native SSH client via Citadel library
   - Special keys bar (Ctrl+C, Tab, arrows, etc.)
   - Password authentication with saved credentials
   - Auto-connect with stored settings

7. **Configuration**
   - Configurable backend server URL
   - SSH host/port/username/password
   - Font size preferences (XS/S/M/L/XL)
   - Claude mode selector (normal/plan/bypass)
   - Persist settings across app launches

8. **Notifications**
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
   - CLI-inspired dark theme
   - Support for iOS 17.0+
   - Works on iPhone and iPad

## Out of Scope (Current Version)

- Push notifications (APNs - currently uses local notifications)
- Offline mode
- Multiple backend server profiles
- File attachments beyond images
