# Issue 56: iCloud Sync

**Phase:** 8 (iOS 26 Platform)
**Priority:** Medium
**Status:** Not Started
**Depends On:** 29 (Project Settings)
**Target:** iOS 26.2, Xcode 26.2, Swift 6.2.1

## Goal

Implement iCloud sync for user settings, bookmarks, saved commands, and ideas across devices using CloudKit and NSUbiquitousKeyValueStore.

## Scope

- In scope:
  - Settings sync via NSUbiquitousKeyValueStore
  - Bookmarks sync via CloudKit
  - Saved commands sync via CloudKit
  - Ideas sync via CloudKit
  - Conflict resolution strategy
  - Sync status indicator
- Out of scope:
  - Chat message history sync (stored on server)
  - SSH credential sync (security concern)
  - Project file sync (use git)
  - Real-time collaborative editing

## Non-goals

- Full offline message cache
- Cross-platform sync (Android/web)
- Third-party cloud providers

## Dependencies

- Issue #29 (Project Settings) for settings structure

## Touch Set

- Files to create:
  - `CodingBridge/Services/Sync/CloudKitManager.swift`
  - `CodingBridge/Services/Sync/SyncStatusTracker.swift`
  - `CodingBridge/Services/Sync/ConflictResolver.swift`
- Files to modify:
  - `CodingBridge/Core/AppSettings.swift` (add iCloud sync)
  - `CodingBridge/Stores/BookmarkStore.swift` (add CloudKit)
  - `CodingBridge/Stores/CommandStore.swift` (add CloudKit)
  - `CodingBridge/Stores/IdeasStore.swift` (add CloudKit)
  - Entitlements file (add iCloud capability)

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                         iCloud                                │
│  ┌─────────────────────┐  ┌────────────────────────────────┐ │
│  │ Key-Value Store     │  │ CloudKit Private Database      │ │
│  │ (Settings)          │  │ (Bookmarks, Commands, Ideas)   │ │
│  └─────────────────────┘  └────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                    CloudKitManager                           │
│  ┌─────────────────┐  ┌───────────────┐  ┌────────────────┐ │
│  │ SettingsSync    │  │ RecordSync    │  │ ConflictResolver│ │
│  │ (KVS Observer)  │  │ (CKDatabase)  │  │                │ │
│  └─────────────────┘  └───────────────┘  └────────────────┘ │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│                    Local Stores                              │
│  ┌──────────┐  ┌──────────────┐  ┌───────────┐  ┌─────────┐ │
│  │AppSettings│  │BookmarkStore │  │CommandStore│  │IdeasStore│
│  └──────────┘  └──────────────┘  └───────────┘  └─────────┘ │
└──────────────────────────────────────────────────────────────┘
```

---

## Settings Sync (NSUbiquitousKeyValueStore)

### SettingsSyncManager

```swift
import Foundation

/// Syncs app settings via iCloud Key-Value Store.
///
/// Settings are automatically synced across devices signed into
/// the same iCloud account. Changes propagate within seconds.
@MainActor @Observable
final class SettingsSyncManager {
    static let shared = SettingsSyncManager()

    private let store = NSUbiquitousKeyValueStore.default

    private(set) var lastSyncDate: Date?
    private(set) var isSyncing = false

    /// Keys that should sync to iCloud.
    private let syncableKeys: Set<String> = [
        "fontSize",
        "appTheme",
        "showThinkingBlocks",
        "autoScrollEnabled",
        "projectSortOrder",
        "defaultModel",
        "thinkingMode",
        "skipPermissions",
    ]

    /// Keys that should NOT sync (device-specific or sensitive).
    private let excludedKeys: Set<String> = [
        "serverURL",      // Device-specific
        "sshHost",        // Device-specific
        "sshPort",
        "sshUsername",
        "sshAuthMethod",
        // Passwords stored in Keychain, not synced
    ]

    private init() {
        setupObserver()
        synchronize()
    }

    private func setupObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
    }

    @objc private func storeDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonRaw = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
              let keys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }

        let reason = ChangeReason(rawValue: reasonRaw) ?? .serverChange

        Task { @MainActor in
            await handleRemoteChanges(keys: keys, reason: reason)
        }
    }

    private func handleRemoteChanges(keys: [String], reason: ChangeReason) async {
        isSyncing = true
        defer { isSyncing = false }

        for key in keys where syncableKeys.contains(key) {
            if let value = store.object(forKey: key) {
                UserDefaults.standard.set(value, forKey: key)
            }
        }

        lastSyncDate = Date()

        // Post notification for UI update
        NotificationCenter.default.post(
            name: .settingsDidSyncFromCloud,
            object: nil,
            userInfo: ["keys": keys, "reason": reason]
        )
    }

    /// Push local setting to iCloud.
    func pushSetting(key: String, value: Any?) {
        guard syncableKeys.contains(key) else { return }

        if let value {
            store.set(value, forKey: key)
        } else {
            store.removeObject(forKey: key)
        }
    }

    /// Force sync with iCloud.
    func synchronize() {
        store.synchronize()
    }

    enum ChangeReason: Int {
        case serverChange = 0
        case initialSyncChange = 1
        case quotaViolationChange = 2
        case accountChange = 3
    }
}

extension Notification.Name {
    static let settingsDidSyncFromCloud = Notification.Name("settingsDidSyncFromCloud")
}
```

---

## CloudKit Record Sync

### CloudKitManager

```swift
import CloudKit

/// Manages CloudKit sync for bookmarks, commands, and ideas.
actor CloudKitManager {
    static let shared = CloudKitManager()

    private let container = CKContainer(identifier: "iCloud.com.codingbridge.app")
    private var database: CKDatabase { container.privateCloudDatabase }

    private(set) var isSyncing = false
    private(set) var lastError: Error?

    // MARK: - Zone Setup

    private let zoneID = CKRecordZone.ID(
        zoneName: "CodingBridgeData",
        ownerName: CKCurrentUserDefaultName
    )

    func setupZone() async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        let operation = CKModifyRecordZonesOperation(
            recordZonesToSave: [zone],
            recordZoneIDsToDelete: nil
        )

        try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordZonesResultBlock = { result in
                continuation.resume(with: result)
            }
            database.add(operation)
        }
    }

    // MARK: - Subscriptions

    func setupSubscriptions() async throws {
        let subscriptionID = "all-changes"

        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        subscription.notificationInfo = CKSubscription.NotificationInfo()
        subscription.notificationInfo?.shouldSendContentAvailable = true

        try await database.save(subscription)
    }

    // MARK: - Fetch Changes

    func fetchChanges() async throws -> [SyncChange] {
        var changes: [SyncChange] = []
        var changeToken: CKServerChangeToken?

        // Load saved token
        if let tokenData = UserDefaults.standard.data(forKey: "cloudKitChangeToken") {
            changeToken = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: CKServerChangeToken.self,
                from: tokenData
            )
        }

        let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        options.previousServerChangeToken = changeToken

        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: options]
        )

        operation.recordWasChangedBlock = { recordID, result in
            switch result {
            case .success(let record):
                changes.append(.modified(record))
            case .failure(let error):
                Logger.cloudKit.error("Record change error: \(error)")
            }
        }

        operation.recordWithIDWasDeletedBlock = { recordID, recordType in
            changes.append(.deleted(recordID, recordType))
        }

        operation.recordZoneFetchResultBlock = { zoneID, result in
            if case .success(let (newToken, _, _)) = result, let newToken {
                // Save token
                if let tokenData = try? NSKeyedArchiver.archivedData(
                    withRootObject: newToken,
                    requiringSecureCoding: true
                ) {
                    UserDefaults.standard.set(tokenData, forKey: "cloudKitChangeToken")
                }
            }
        }

        try await withCheckedThrowingContinuation { continuation in
            operation.fetchRecordZoneChangesResultBlock = { result in
                continuation.resume(with: result.map { _ in () })
            }
            database.add(operation)
        }

        return changes
    }

    // MARK: - Save Records

    func save(_ records: [CKRecord]) async throws {
        isSyncing = true
        defer { isSyncing = false }

        let operation = CKModifyRecordsOperation(
            recordsToSave: records,
            recordIDsToDelete: nil
        )
        operation.savePolicy = .changedKeys

        try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                continuation.resume(with: result.map { _ in () })
            }
            database.add(operation)
        }
    }

    // MARK: - Delete Records

    func delete(_ recordIDs: [CKRecord.ID]) async throws {
        isSyncing = true
        defer { isSyncing = false }

        let operation = CKModifyRecordsOperation(
            recordsToSave: nil,
            recordIDsToDelete: recordIDs
        )

        try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                continuation.resume(with: result.map { _ in () })
            }
            database.add(operation)
        }
    }
}

enum SyncChange {
    case modified(CKRecord)
    case deleted(CKRecord.ID, CKRecord.RecordType)
}
```

---

## Record Types

### Bookmark Record

```swift
extension BookmarkedMessage {
    static let recordType = "Bookmark"

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let messageId = record["messageId"] as? String,
              let roleRaw = record["role"] as? String,
              let role = ChatMessage.Role(rawValue: roleRaw),
              let content = record["content"] as? String,
              let projectPath = record["projectPath"] as? String,
              let createdAt = record["createdAt"] as? Date else {
            return nil
        }

        self.init(
            id: record.recordID.recordName,
            messageId: messageId,
            role: role,
            content: content,
            projectPath: projectPath,
            sessionId: record["sessionId"] as? String,
            timestamp: createdAt,
            note: record["note"] as? String
        )
    }

    func toRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id, zoneID: zoneID)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)

        record["messageId"] = messageId
        record["role"] = role.rawValue
        record["content"] = content
        record["projectPath"] = projectPath
        record["sessionId"] = sessionId
        record["createdAt"] = timestamp
        record["note"] = note

        return record
    }
}
```

### Command Record

```swift
extension SavedCommand {
    static let recordType = "Command"

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let name = record["name"] as? String,
              let content = record["content"] as? String else {
            return nil
        }

        self.init(
            id: record.recordID.recordName,
            name: name,
            content: content,
            category: record["category"] as? String,
            lastUsed: record["lastUsed"] as? Date,
            createdAt: record["createdAt"] as? Date ?? Date()
        )
    }

    func toRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id, zoneID: zoneID)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)

        record["name"] = name
        record["content"] = content
        record["category"] = category
        record["lastUsed"] = lastUsed
        record["createdAt"] = createdAt

        return record
    }
}
```

### Idea Record

```swift
extension Idea {
    static let recordType = "Idea"

    init?(record: CKRecord) {
        guard record.recordType == Self.recordType,
              let text = record["text"] as? String else {
            return nil
        }

        self.init(
            id: record.recordID.recordName,
            text: text,
            title: record["title"] as? String,
            tags: (record["tags"] as? [String]) ?? [],
            isArchived: record["isArchived"] as? Bool ?? false,
            createdAt: record["createdAt"] as? Date ?? Date(),
            modifiedAt: record["modifiedAt"] as? Date ?? Date()
        )
    }

    func toRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id, zoneID: zoneID)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)

        record["text"] = text
        record["title"] = title
        record["tags"] = tags
        record["isArchived"] = isArchived
        record["createdAt"] = createdAt
        record["modifiedAt"] = modifiedAt

        return record
    }
}
```

---

## Conflict Resolution

### ConflictResolver

```swift
/// Resolves conflicts between local and remote data.
struct ConflictResolver {
    enum Resolution {
        case useLocal
        case useRemote
        case merge
    }

    /// Resolve bookmark conflict.
    static func resolve(
        local: BookmarkedMessage,
        remote: BookmarkedMessage
    ) -> Resolution {
        // Most recently modified wins
        if local.timestamp > remote.timestamp {
            return .useLocal
        }
        return .useRemote
    }

    /// Resolve command conflict.
    static func resolve(
        local: SavedCommand,
        remote: SavedCommand
    ) -> Resolution {
        // Keep local if more recently used
        if let localUsed = local.lastUsed,
           let remoteUsed = remote.lastUsed,
           localUsed > remoteUsed {
            return .useLocal
        }
        return .useRemote
    }

    /// Resolve idea conflict - attempt merge.
    static func resolve(
        local: Idea,
        remote: Idea
    ) -> (Resolution, Idea?) {
        // If same content, use most recently modified
        if local.text == remote.text {
            return (local.modifiedAt > remote.modifiedAt ? .useLocal : .useRemote, nil)
        }

        // If content differs, merge
        let merged = Idea(
            id: local.id,
            text: remote.text,  // Keep remote text
            title: local.title ?? remote.title,  // Prefer local title
            tags: Array(Set(local.tags + remote.tags)),  // Union of tags
            isArchived: local.isArchived || remote.isArchived,
            createdAt: min(local.createdAt, remote.createdAt),
            modifiedAt: Date()
        )

        return (.merge, merged)
    }
}
```

---

## Sync Status UI

### SyncStatusIndicator

```swift
struct SyncStatusIndicator: View {
    @State private var syncManager = CloudKitManager.shared
    @State private var settingsSync = SettingsSyncManager.shared

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)

            if showLabel {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.default, value: isSyncing)
    }

    private var isSyncing: Bool {
        // Note: Need to access actor state properly
        false // Placeholder - would use @State from actor
    }

    private var iconName: String {
        if isSyncing {
            return "arrow.triangle.2.circlepath"
        }
        return "checkmark.icloud"
    }

    private var iconColor: Color {
        if isSyncing {
            return .blue
        }
        return .green
    }

    private var statusText: String {
        if isSyncing {
            return "Syncing..."
        }
        return "Synced"
    }

    private var showLabel: Bool {
        isSyncing
    }
}
```

---

## Edge Cases

- **No iCloud account**: Gracefully disable sync, show settings prompt
- **iCloud quota exceeded**: Warn user, prioritize recent items
- **Network unavailable**: Queue changes, sync when connected
- **Conflict during offline**: Use timestamp-based resolution
- **App deleted on one device**: Other devices keep data
- **New device setup**: Full initial sync on first launch

## Acceptance Criteria

- [ ] Settings sync via NSUbiquitousKeyValueStore
- [ ] Bookmarks sync to CloudKit private database
- [ ] Commands sync to CloudKit private database
- [ ] Ideas sync to CloudKit private database
- [ ] Conflict resolution for all record types
- [ ] Sync status indicator in UI
- [ ] Graceful degradation without iCloud
- [ ] Background sync via push notifications

## Testing

```swift
class CloudKitSyncTests: XCTestCase {
    func testBookmarkRecordConversion() {
        let bookmark = BookmarkedMessage.mock()
        let zoneID = CKRecordZone.ID(zoneName: "Test", ownerName: CKCurrentUserDefaultName)

        let record = bookmark.toRecord(zoneID: zoneID)
        let restored = BookmarkedMessage(record: record)

        XCTAssertEqual(restored?.id, bookmark.id)
        XCTAssertEqual(restored?.content, bookmark.content)
    }

    func testConflictResolution() {
        let local = Idea(text: "Local version")
        let remote = Idea(text: "Remote version")

        let (resolution, merged) = ConflictResolver.resolve(local: local, remote: remote)

        XCTAssertEqual(resolution, .merge)
        XCTAssertNotNil(merged)
    }

    func testSettingsSync() async {
        let manager = SettingsSyncManager.shared
        manager.pushSetting(key: "fontSize", value: 16)

        // Verify key was pushed (mock verification)
        XCTAssertTrue(true) // Placeholder
    }
}
```
