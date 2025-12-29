import Foundation

/// Persists draft input text to survive backgrounding
@MainActor
final class DraftInputPersistence {
    static let shared = DraftInputPersistence()

    private let draftKey = "draftInput"
    private let sessionKey = "draftInputSessionId"
    private let projectKey = "draftInputProjectPath"
    private let timestampKey = "draftInputTimestamp"

    // MARK: - Initialization

    private init() {}

    // MARK: - Current Draft

    /// The current draft text
    var currentDraft: String {
        get { UserDefaults.standard.string(forKey: draftKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: draftKey) }
    }

    /// The session ID associated with the draft
    var draftSessionId: String? {
        get { UserDefaults.standard.string(forKey: sessionKey) }
        set { UserDefaults.standard.set(newValue, forKey: sessionKey) }
    }

    /// The project path associated with the draft
    var draftProjectPath: String? {
        get { UserDefaults.standard.string(forKey: projectKey) }
        set { UserDefaults.standard.set(newValue, forKey: projectKey) }
    }

    /// When the draft was last saved
    var draftTimestamp: Date? {
        get {
            let interval = UserDefaults.standard.double(forKey: timestampKey)
            return interval > 0 ? Date(timeIntervalSince1970: interval) : nil
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: timestampKey)
            } else {
                UserDefaults.standard.removeObject(forKey: timestampKey)
            }
        }
    }

    // MARK: - Save/Load

    /// Save the current draft with context
    func save(draft: String? = nil, sessionId: String? = nil, projectPath: String? = nil) {
        if let draft = draft {
            currentDraft = draft
        }
        if let sessionId = sessionId {
            draftSessionId = sessionId
        }
        if let projectPath = projectPath {
            draftProjectPath = projectPath
        }
        draftTimestamp = Date()

        log.debug("[Persistence] Saved draft (\(currentDraft.count) chars)")
    }

    /// Load draft for a specific session
    func loadForSession(_ sessionId: String) -> String? {
        guard draftSessionId == sessionId else {
            log.debug("[Persistence] Draft session mismatch: expected=\(sessionId), stored=\(draftSessionId ?? "nil")")
            return nil
        }
        guard !currentDraft.isEmpty else {
            log.debug("[Persistence] Draft is empty for session=\(sessionId)")
            return nil
        }
        log.info("[Persistence] Loaded draft (\(currentDraft.count) chars) for session=\(sessionId.prefix(8))...")
        return currentDraft
    }

    /// Load draft for a specific project
    func loadForProject(_ projectPath: String) -> String? {
        guard draftProjectPath == projectPath else {
            log.debug("[Persistence] Draft project mismatch: expected=\(projectPath), stored=\(draftProjectPath ?? "nil")")
            return nil
        }
        guard !currentDraft.isEmpty else {
            log.debug("[Persistence] Draft is empty for project=\(projectPath)")
            return nil
        }
        log.info("[Persistence] Loaded draft (\(currentDraft.count) chars) for project")
        return currentDraft
    }

    /// Check if draft is stale (older than 24 hours)
    var isDraftStale: Bool {
        guard let timestamp = draftTimestamp else { return true }
        return Date().timeIntervalSince(timestamp) > 24 * 60 * 60
    }

    // MARK: - Clear

    /// Clear the draft
    func clear() {
        currentDraft = ""
        draftSessionId = nil
        draftProjectPath = nil
        draftTimestamp = nil
        log.debug("[Persistence] Cleared draft")
    }

    /// Clear draft only if it matches the given session
    func clearIfSession(_ sessionId: String) {
        if draftSessionId == sessionId {
            clear()
        }
    }
}
