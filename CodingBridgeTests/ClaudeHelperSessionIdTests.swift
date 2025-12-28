import XCTest
@testable import CodingBridge

final class ClaudeHelperSessionIdTests: XCTestCase {
    func testCreateHelperSessionIdIsDeterministicForSamePath() {
        let path = "/tmp/helper-session"

        let first = ClaudeHelper.createHelperSessionId(for: path)
        let second = ClaudeHelper.createHelperSessionId(for: path)

        XCTAssertEqual(first, second)
    }

    func testCreateHelperSessionIdDiffersForDifferentPaths() {
        let basePath = "/tmp/helper-session"
        let baseId = ClaudeHelper.createHelperSessionId(for: basePath)
        var foundDifferent = false

        for index in 0..<50 {
            let candidate = "\(basePath)-\(index)"
            let candidateId = ClaudeHelper.createHelperSessionId(for: candidate)
            if candidateId != baseId {
                foundDifferent = true
                break
            }
        }

        XCTAssertTrue(foundDifferent)
    }

    func testCreateHelperSessionIdMatchesUUIDFormat() {
        let id = ClaudeHelper.createHelperSessionId(for: "/tmp/helper-session-format")

        XCTAssertNotNil(UUID(uuidString: id))

        let parts = id.split(separator: "-")
        XCTAssertEqual(parts.count, 5)
        XCTAssertTrue(parts[2].hasPrefix("4"))

        if let variant = parts[3].first {
            let allowed = ["8", "9", "a", "b", "A", "B"]
            XCTAssertTrue(allowed.contains(String(variant)))
        } else {
            XCTFail("Expected variant nibble")
        }
    }

    // MARK: - Helper Prompt Detection Tests

    func testIsHelperPromptDetectsSuggestionPrompts() {
        // generateSuggestions prompt
        XCTAssertTrue(ClaudeHelper.isHelperPrompt(
            "Based on this conversation context, suggest 3 short next actions the user might want to take."
        ))
    }

    func testIsHelperPromptDetectsFilePrompts() {
        // suggestRelevantFiles prompt
        XCTAssertTrue(ClaudeHelper.isHelperPrompt(
            "Based on this conversation, which files would be most relevant to reference next?"
        ))
    }

    func testIsHelperPromptDetectsIdeaEnhancementPrompts() {
        // enhanceIdea prompt
        XCTAssertTrue(ClaudeHelper.isHelperPrompt(
            "You are helping a developer expand a quick idea into an actionable prompt for Claude Code."
        ))
    }

    func testIsHelperPromptDetectsAnalysisPrompts() {
        // analyzeMessage prompt
        XCTAssertTrue(ClaudeHelper.isHelperPrompt(
            "Analyze this Claude Code response and suggest 3 helpful follow-up actions."
        ))
    }

    func testIsHelperPromptRejectsRegularUserMessages() {
        XCTAssertFalse(ClaudeHelper.isHelperPrompt("Help me fix this bug"))
        XCTAssertFalse(ClaudeHelper.isHelperPrompt("What files are in this project?"))
        XCTAssertFalse(ClaudeHelper.isHelperPrompt("Run the tests"))
        XCTAssertFalse(ClaudeHelper.isHelperPrompt(nil))
        XCTAssertFalse(ClaudeHelper.isHelperPrompt(""))
    }

    func testIsHelperSessionDetectsBySessionId() {
        let projectPath = "/test/project"
        let helperSessionId = ClaudeHelper.createHelperSessionId(for: projectPath)

        // Should detect by session ID even with nil message
        XCTAssertTrue(ClaudeHelper.isHelperSession(
            sessionId: helperSessionId,
            lastUserMessage: nil,
            projectPath: projectPath
        ))

        // Should detect by session ID even with regular message
        XCTAssertTrue(ClaudeHelper.isHelperSession(
            sessionId: helperSessionId,
            lastUserMessage: "Regular user message",
            projectPath: projectPath
        ))
    }

    func testIsHelperSessionIgnoresContentForRegularSessionIds() {
        let projectPath = "/test/project"
        let randomSessionId = UUID().uuidString

        // Should NOT filter by content - a real session may have helper prompt as lastUserMessage
        // because ClaudeHelper correctly reuses the existing session
        XCTAssertFalse(ClaudeHelper.isHelperSession(
            sessionId: randomSessionId,
            lastUserMessage: "Based on this conversation context, suggest 3 short next actions",
            projectPath: projectPath
        ))
    }

    func testIsHelperSessionAllowsRegularSessions() {
        let projectPath = "/test/project"
        let randomSessionId = UUID().uuidString

        // Should NOT detect regular sessions
        XCTAssertFalse(ClaudeHelper.isHelperSession(
            sessionId: randomSessionId,
            lastUserMessage: "Help me implement a new feature",
            projectPath: projectPath
        ))
    }

    // MARK: - Agent Session Detection Tests

    func testIsAgentSessionDetectsAgentIds() {
        XCTAssertTrue(ClaudeHelper.isAgentSession("agent-acfbed8"))
        XCTAssertTrue(ClaudeHelper.isAgentSession("agent-a321f99"))
        XCTAssertTrue(ClaudeHelper.isAgentSession("agent-12345"))
    }

    func testIsAgentSessionAllowsRegularIds() {
        XCTAssertFalse(ClaudeHelper.isAgentSession("64400173-15b3-4488-97b1-6516809c42be"))
        XCTAssertFalse(ClaudeHelper.isAgentSession(UUID().uuidString))
        XCTAssertFalse(ClaudeHelper.isAgentSession("some-regular-id"))
    }

    func testIsHelperSessionFiltersAgentSessions() {
        let projectPath = "/test/project"

        // Agent sessions should be filtered even with regular user messages
        XCTAssertTrue(ClaudeHelper.isHelperSession(
            sessionId: "agent-acfbed8",
            lastUserMessage: "Regular user message",
            projectPath: projectPath
        ))

        XCTAssertTrue(ClaudeHelper.isHelperSession(
            sessionId: "agent-test123",
            lastUserMessage: nil,
            projectPath: projectPath
        ))
    }
}
