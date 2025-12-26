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
   - Display project name and path
   - Navigate to project chat view

2. **Chat Interface**
   - Send messages to Claude
   - Receive streaming responses in real-time
   - Display tool usage (what tools Claude is using)
   - Display tool results (truncated for readability)
   - Support multi-turn conversations via session persistence

3. **Configuration**
   - Configurable backend server URL
   - Persist settings across app launches

### Non-Functional Requirements

1. **Performance**
   - Streaming responses must feel responsive
   - App should handle long conversations without lag

2. **Security**
   - Rely on network-level security (Tailscale)
   - No credentials stored in the app (backend handles auth)

3. **Usability**
   - Native iOS look and feel
   - Support for iOS 17.0+
   - Works on iPhone and iPad

## Out of Scope (v1.0)

- Push notifications when Claude completes tasks
- Offline mode
- Multiple backend server profiles
- Conversation history browser
- File attachments/uploads
