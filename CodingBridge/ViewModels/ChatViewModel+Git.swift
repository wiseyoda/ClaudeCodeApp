import SwiftUI

/// Git operations extension for ChatViewModel
/// Handles git status monitoring, auto-pull, and Claude prompts for git cleanup
extension ChatViewModel {
    // MARK: - Git Status Handling

    func handleGitStatusOnLoad() {
        Task {
            switch gitStatus {
            case .behind:
                await performAutoPull()
            case .dirty, .dirtyAndAhead, .diverged:
                break
            default:
                if gitStatus == .clean || gitStatus == .notGitRepo {
                    showGitBanner = false
                }
            }
        }
    }

    func refreshGitStatus() {
        Task {
            gitStatus = .checking

            let newStatus: GitStatus
        do {
            let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
            let projectDetail = try await apiClient.getProjectDetail(projectPath: project.path)
            if let git = projectDetail.git {
                newStatus = git.toGitStatus
            } else {
                newStatus = .notGitRepo
            }
        } catch let apiError as CLIBridgeAPIError {
            switch apiError {
            case .notFound, .notFoundError:
                log.debug("[ChatViewModel] Git status unavailable for project; marking as not a git repo")
                newStatus = .notGitRepo
            default:
                log.debug("[ChatViewModel] Failed to fetch git status from API: \(apiError)")
                newStatus = .error(apiError.localizedDescription)
            }
        } catch {
            log.debug("[ChatViewModel] Failed to fetch git status from API: \(error)")
            newStatus = .error(error.localizedDescription)
        }

            gitStatus = newStatus
            ProjectCache.shared.updateGitStatus(for: project.path, status: newStatus)

            // Notify other views (e.g., HomeView via GitStatusCoordinator)
            NotificationCenter.default.post(
                name: .gitStatusUpdated,
                object: nil,
                userInfo: ["projectPath": project.path, "status": newStatus]
            )

            if newStatus == .clean || newStatus == .notGitRepo {
                showGitBanner = false
            } else {
                showGitBanner = true
            }
        }
    }

    /// Show git banner and refresh status (for manual refresh from toolbar)
    func showGitBannerAndRefresh() {
        showGitBanner = true
        refreshGitStatus()
    }

    func refreshChatContent() async {
        HapticManager.light()

        Task {
            refreshGitStatus()
        }

        if let sessionId = manager.sessionId {
            do {
                let history = try await fetchHistoryMessages(
                    sessionId: sessionId,
                    limit: settings.historyLimit.rawValue
                )
                let historyMessages = history.messages
                if !historyMessages.isEmpty {
                    messages = historyMessages
                    refreshDisplayMessagesCache()
                }
            } catch {
                log.debug("[ChatViewModel] Failed to refresh session history: \(error)")
            }
        }
    }

    // MARK: - Git Operations

    func performAutoPull() async {
        isAutoPulling = true

        do {
            let apiClient = CLIBridgeAPIClient(serverURL: settings.serverURL)
            let response = try await apiClient.gitPull(projectPath: project.path)

            isAutoPulling = false
            if response.commits > 0 {
                gitStatus = .clean
                showGitBanner = false
                ProjectCache.shared.updateGitStatus(for: project.path, status: .clean)

                let filesDesc = response.files.map { " (\($0.count) files)" } ?? ""
                messages.append(ChatMessage(
                    role: .system,
                    content: "Pulled \(response.commits) commit\(response.commits == 1 ? "" : "s")\(filesDesc)",
                    timestamp: Date()
                ))
            } else {
                gitStatus = .clean
                showGitBanner = false
                ProjectCache.shared.updateGitStatus(for: project.path, status: .clean)
            }
        } catch {
            isAutoPulling = false
            let errorStatus = GitStatus.error("Auto-pull failed: \(error.localizedDescription)")
            gitStatus = errorStatus
            ProjectCache.shared.updateGitStatus(for: project.path, status: errorStatus)
        }
    }

    // MARK: - Claude Git Prompts

    func promptClaudeForCleanup() {
        hasPromptedCleanup = true

        let cleanupPrompt: String
        switch gitStatus {
        case .dirty:
            cleanupPrompt = """
            There are uncommitted changes in this project. Please run `git status` and `git diff` to review the changes, then help me decide how to handle them. Options might include:
            - Committing the changes with an appropriate message
            - Stashing them for later
            - Discarding them if they're not needed
            """
        case .ahead(let count):
            cleanupPrompt = """
            This project has \(count) unpushed commit\(count == 1 ? "" : "s"). Please run `git log --oneline @{upstream}..HEAD` to show me what commits need to be pushed, then help me decide whether to push them now.
            """
        case .dirtyAndAhead:
            cleanupPrompt = """
            This project has both uncommitted changes AND unpushed commits. Please:
            1. Run `git status` to show uncommitted changes
            2. Run `git log --oneline @{upstream}..HEAD` to show unpushed commits
            3. Help me decide how to handle both - whether to commit, stash, push, or discard.
            """
        case .diverged:
            cleanupPrompt = """
            This project has diverged from the remote - there are both local and remote changes. Please:
            1. Run `git status` to show the current state
            2. Run `git log --oneline HEAD...@{upstream}` to show the divergence
            3. Help me resolve this - we may need to rebase or merge.
            """
        default:
            return
        }

        let userMessage = ChatMessage(role: .user, content: cleanupPrompt, timestamp: Date())
        messages.append(userMessage)
        showGitBanner = false

        sendToManager(
            cleanupPrompt,
            projectPath: project.path,
            resumeSessionId: manager.sessionId,
            permissionMode: effectivePermissionModeValue.rawValue,
            images: nil,
            model: effectiveModelId
        )
        processingStartTime = Date()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.scrollToBottomTrigger = true
        }
    }

    func promptClaudeForCommit() {
        let commitPrompt = """
        Please help me commit my changes. Run `git status` and `git diff` to review what has changed, then create a commit with an appropriate message. After committing, push the changes to the remote.
        """

        let userMessage = ChatMessage(role: .user, content: commitPrompt, timestamp: Date())
        messages.append(userMessage)
        showGitBanner = false

        sendToManager(
            commitPrompt,
            projectPath: project.path,
            resumeSessionId: manager.sessionId,
            permissionMode: effectivePermissionModeValue.rawValue,
            images: nil,
            model: effectiveModelId
        )
        processingStartTime = Date()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.scrollToBottomTrigger = true
        }
    }

    func promptClaudeForPush() {
        let pushPrompt = """
        Please push my local commits to the remote. Run `git log --oneline @{upstream}..HEAD` to show what will be pushed, then run `git push` to push the commits.
        """

        let userMessage = ChatMessage(role: .user, content: pushPrompt, timestamp: Date())
        messages.append(userMessage)
        showGitBanner = false

        sendToManager(
            pushPrompt,
            projectPath: project.path,
            resumeSessionId: manager.sessionId,
            permissionMode: effectivePermissionModeValue.rawValue,
            images: nil,
            model: effectiveModelId
        )
        processingStartTime = Date()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.scrollToBottomTrigger = true
        }
    }
}
