# State Flow Diagrams


### Message Send/Receive Flow

```
User Input
  -> InputView
  -> ChatViewModel.sendMessage()
  -> CLIBridgeManager.sendMessage()
  -> WebSocket/REST
  -> StreamEvent
  -> MessageNormalizer
  -> MessageStore
  -> MessageListView
  -> MessageCardRouter
```

### Permission Approval Flow

```
StreamEvent.permissionRequest
  -> StreamInteractionHandler.enqueue()
  -> InteractionContainerView
  -> PermissionInteraction
  -> onPermissionResponse(request, choice)
  -> CLIBridgeManager.respondToPermission()
```

### Session Switching Flow

```
SidebarView selection
  -> AppState.selectedProject
  -> SessionStore.loadSessions()
  -> DetailContainerView
  -> ChatView(project)
```

### Error Propagation Flow

```
StreamEvent.error / connectionError
  -> ErrorStore
  -> User-facing banner / sheet
  -> Optional retry action
```

---
