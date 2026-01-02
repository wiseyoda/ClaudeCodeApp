#!/bin/bash
# Comprehensive API verification script for cli-bridge
# Validates all fields required by the iOS app
# Usage: ./scripts/verify-api.sh [server-url]

SERVER="${1:-http://localhost:3100}"
PASSED=0
FAILED=0
WARNINGS=0
TMP_DIR="/tmp/cli-bridge-verify"
mkdir -p "$TMP_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

log_pass() { echo -e "${GREEN}✓${NC} $1"; ((PASSED++)); }
log_fail() { echo -e "${RED}✗${NC} $1"; ((FAILED++)); }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; ((WARNINGS++)); }
log_info() { echo -e "${CYAN}→${NC} $1"; }
log_detail() { echo -e "  ${GRAY}$1${NC}"; }
log_section() { echo -e "\n${BLUE}━━━ $1 ━━━${NC}"; }

# Check if a field exists and is not null
check_field() {
    local json="$1"
    local field="$2"
    local value=$(echo "$json" | jq -r ".$field // \"__NULL__\"")
    [ "$value" != "__NULL__" ] && [ "$value" != "null" ]
}

# Check if a field is a string (not a JSON array/object)
check_string_field() {
    local json="$1"
    local field="$2"
    local value=$(echo "$json" | jq -r ".$field // \"__NULL__\"")
    [ "$value" = "__NULL__" ] || [ "$value" = "null" ] && return 1
    [[ "$value" == \[* ]] && return 2
    return 0
}

# Check ISO8601 date format
check_date_field() {
    local json="$1"
    local field="$2"
    local value=$(echo "$json" | jq -r ".$field // \"__NULL__\"")
    [ "$value" = "__NULL__" ] || [ "$value" = "null" ] && return 1
    [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]] && return 0
    return 2
}

# ============================================================================
log_section "Health Check"
# ============================================================================

HEALTH=$(curl -sf "$SERVER/health" 2>/dev/null)
if [ $? -eq 0 ]; then
    log_pass "Server reachable at $SERVER"
    VERSION=$(echo "$HEALTH" | jq -r '.version // "unknown"')
    log_info "Server version: $VERSION"
else
    log_fail "Server not reachable at $SERVER"
    echo -e "\n${RED}Cannot continue without server connection${NC}"
    exit 1
fi

# ============================================================================
log_section "Projects: GET /projects"
# ============================================================================

curl -sf "$SERVER/projects" > "$TMP_DIR/projects.json" 2>/dev/null
if [ $? -ne 0 ]; then
    log_fail "Failed to fetch /projects"
else
    log_pass "Endpoint responds"
    PROJECT_COUNT=$(jq '.projects | length' "$TMP_DIR/projects.json")
    log_info "Found $PROJECT_COUNT projects"

    if [ "$PROJECT_COUNT" -gt 0 ]; then
        PROJECT=$(jq '.projects[0]' "$TMP_DIR/projects.json")

        # Required fields
        for field in path name; do
            check_field "$PROJECT" "$field" && log_pass "projects[].${field}" || log_fail "projects[].${field} MISSING"
        done

        # Optional fields
        for field in lastUsed sessionCount; do
            check_field "$PROJECT" "$field" && log_pass "projects[].${field}" || log_warn "projects[].${field} (optional)"
        done

        # Git info
        if jq -e '.git' <<< "$PROJECT" > /dev/null 2>&1; then
            log_pass "projects[].git"
            for field in branch; do
                check_field "$(jq '.git' <<< "$PROJECT")" "$field" && log_pass "projects[].git.${field}" || log_warn "projects[].git.${field}"
            done
        fi

        TEST_PROJECT_PATH=$(jq -r '.path' <<< "$PROJECT")
        TEST_PROJECT_ENCODED=$(echo "$TEST_PROJECT_PATH" | sed 's|^/|-|; s|/|-|g')
    fi
fi

# ============================================================================
log_section "Sessions: GET /projects/{path}/sessions"
# ============================================================================

if [ -n "$TEST_PROJECT_ENCODED" ]; then
    curl -sf "$SERVER/projects/$TEST_PROJECT_ENCODED/sessions?limit=5" > "$TMP_DIR/sessions.json" 2>/dev/null
    if [ $? -ne 0 ]; then
        log_fail "Failed to fetch sessions"
    else
        log_pass "Endpoint responds"
        SESSION_COUNT=$(jq '.sessions | length' "$TMP_DIR/sessions.json")
        log_info "Found $SESSION_COUNT sessions"

        # Pagination fields
        for field in total hasMore; do
            check_field "$(cat "$TMP_DIR/sessions.json")" "$field" && log_pass "response.${field}" || log_warn "response.${field}"
        done

        if [ "$SESSION_COUNT" -gt 0 ]; then
            SESSION=$(jq '.sessions[0]' "$TMP_DIR/sessions.json")

            # Required fields
            for field in id projectPath source messageCount; do
                check_field "$SESSION" "$field" && log_pass "sessions[].${field}" || log_fail "sessions[].${field} MISSING"
            done

            # Date fields (ISO8601)
            for field in createdAt lastActivityAt; do
                check_date_field "$SESSION" "$field"
                case $? in
                    0) log_pass "sessions[].${field} (ISO8601)" ;;
                    1) log_fail "sessions[].${field} MISSING" ;;
                    2) log_fail "sessions[].${field} NOT ISO8601" ;;
                esac
            done

            # String fields (must NOT be JSON arrays - the key fix!)
            for field in title lastUserMessage lastAssistantMessage; do
                check_string_field "$SESSION" "$field"
                case $? in
                    0) log_pass "sessions[].${field} (plain string)" ;;
                    1) log_info "sessions[].${field} not set" ;;
                    2) log_fail "sessions[].${field} IS JSON ARRAY - should be plain string" ;;
                esac
            done

            # Optional fields
            for field in customTitle model archivedAt parentSessionId; do
                check_field "$SESSION" "$field" && log_pass "sessions[].${field}" || log_info "sessions[].${field} not set"
            done

            TEST_SESSION_ID=$(jq -r '.id' <<< "$SESSION")
        fi
    fi
fi

# ============================================================================
log_section "Messages: GET /projects/{path}/sessions/{id}/messages"
# ============================================================================

if [ -n "$TEST_PROJECT_ENCODED" ] && [ -n "$TEST_SESSION_ID" ]; then
    curl -sf "$SERVER/projects/$TEST_PROJECT_ENCODED/sessions/$TEST_SESSION_ID/messages?limit=50&includeRawContent=true" > "$TMP_DIR/messages.json" 2>/dev/null
    if [ $? -ne 0 ]; then
        log_fail "Failed to fetch messages"
    else
        log_pass "Endpoint responds"
        API_VERSION=$(jq -r '.apiVersion // "unknown"' "$TMP_DIR/messages.json")
        log_info "API version: $API_VERSION"

        MESSAGE_COUNT=$(jq '.messages | length' "$TMP_DIR/messages.json")
        log_info "Found $MESSAGE_COUNT messages"

        # Pagination
        if jq -e '.pagination' "$TMP_DIR/messages.json" > /dev/null 2>&1; then
            log_pass "response.pagination"
            for field in total limit offset hasMore; do
                check_field "$(jq '.pagination' "$TMP_DIR/messages.json")" "$field" && \
                    log_pass "pagination.${field}" || log_warn "pagination.${field}"
            done
        else
            log_fail "response.pagination MISSING"
        fi

        if [ "$MESSAGE_COUNT" -gt 0 ]; then
            MESSAGE=$(jq '.messages[0]' "$TMP_DIR/messages.json")

            # Message structure
            for field in id timestamp; do
                check_field "$MESSAGE" "$field" && log_pass "messages[].${field}" || log_fail "messages[].${field} MISSING"
            done

            check_date_field "$MESSAGE" "timestamp"
            case $? in
                0) log_pass "messages[].timestamp (ISO8601)" ;;
                2) log_fail "messages[].timestamp NOT ISO8601" ;;
            esac

            # Message object
            if jq -e '.message' <<< "$MESSAGE" > /dev/null 2>&1; then
                log_pass "messages[].message"
                MSG=$(jq '.message' <<< "$MESSAGE")
                check_field "$MSG" "type" && log_pass "message.type" || log_fail "message.type MISSING"

                check_string_field "$MSG" "content"
                case $? in
                    0) log_pass "message.content (plain string)" ;;
                    1) log_info "message.content empty" ;;
                    2) log_fail "message.content IS JSON ARRAY" ;;
                esac
            else
                log_fail "messages[].message MISSING"
            fi

            # rawContent array
            if jq -e '.rawContent | type == "array"' <<< "$MESSAGE" > /dev/null 2>&1; then
                log_pass "messages[].rawContent (array)"
            else
                log_warn "messages[].rawContent not array (requested with includeRawContent=true)"
            fi
        fi
    fi
fi

# ============================================================================
log_section "Content Blocks in rawContent"
# ============================================================================

if [ -f "$TMP_DIR/messages.json" ]; then
    # Count block types
    BLOCK_TYPES=$(jq -r '[.messages[].rawContent // [] | .[].type] | group_by(.) | map("\(.[0]): \(length)") | join(", ")' "$TMP_DIR/messages.json")
    log_info "Block types found: $BLOCK_TYPES"

    # Verify TextBlock structure
    TEXT_BLOCK=$(jq 'first(.messages[].rawContent // [] | .[] | select(.type == "text"))' "$TMP_DIR/messages.json" 2>/dev/null)
    if [ -n "$TEXT_BLOCK" ] && [ "$TEXT_BLOCK" != "null" ]; then
        log_pass "TextBlock found"
        check_field "$TEXT_BLOCK" "type" && log_pass "  TextBlock.type" || log_fail "  TextBlock.type MISSING"
        check_field "$TEXT_BLOCK" "text" && log_pass "  TextBlock.text" || log_fail "  TextBlock.text MISSING"
        log_detail "Sample: $(echo "$TEXT_BLOCK" | jq -r '.text' | head -c 60)..."
    else
        log_warn "No TextBlock found in sample"
    fi

    # Verify ToolUseBlock structure
    TOOL_USE=$(jq 'first(.messages[].rawContent // [] | .[] | select(.type == "tool_use"))' "$TMP_DIR/messages.json" 2>/dev/null)
    if [ -n "$TOOL_USE" ] && [ "$TOOL_USE" != "null" ]; then
        log_pass "ToolUseBlock found"
        check_field "$TOOL_USE" "type" && log_pass "  ToolUseBlock.type" || log_fail "  ToolUseBlock.type MISSING"
        check_field "$TOOL_USE" "id" && log_pass "  ToolUseBlock.id" || log_fail "  ToolUseBlock.id MISSING"
        check_field "$TOOL_USE" "name" && log_pass "  ToolUseBlock.name" || log_fail "  ToolUseBlock.name MISSING"
        check_field "$TOOL_USE" "input" && log_pass "  ToolUseBlock.input" || log_fail "  ToolUseBlock.input MISSING"
        log_detail "Tool: $(echo "$TOOL_USE" | jq -r '.name')"
    else
        log_warn "No ToolUseBlock found in sample"
    fi

    # Verify ThinkingBlock structure
    THINKING=$(jq 'first(.messages[].rawContent // [] | .[] | select(.type == "thinking"))' "$TMP_DIR/messages.json" 2>/dev/null)
    if [ -n "$THINKING" ] && [ "$THINKING" != "null" ]; then
        log_pass "ThinkingBlock found"
        check_field "$THINKING" "type" && log_pass "  ThinkingBlock.type" || log_fail "  ThinkingBlock.type MISSING"
        check_field "$THINKING" "thinking" && log_pass "  ThinkingBlock.thinking" || log_fail "  ThinkingBlock.thinking MISSING"
        log_detail "Thinking: $(echo "$THINKING" | jq -r '.thinking' | head -c 60)..."
    else
        log_info "No ThinkingBlock in sample (may not be present)"
    fi

    # Verify ToolResultBlock structure (if present)
    TOOL_RESULT=$(jq 'first(.messages[].rawContent // [] | .[] | select(.type == "tool_result"))' "$TMP_DIR/messages.json" 2>/dev/null)
    if [ -n "$TOOL_RESULT" ] && [ "$TOOL_RESULT" != "null" ]; then
        log_pass "ToolResultBlock found"
        check_field "$TOOL_RESULT" "type" && log_pass "  ToolResultBlock.type" || log_fail "  ToolResultBlock.type MISSING"
        check_field "$TOOL_RESULT" "tool_use_id" && log_pass "  ToolResultBlock.tool_use_id" || log_fail "  ToolResultBlock.tool_use_id MISSING"
        check_field "$TOOL_RESULT" "content" && log_pass "  ToolResultBlock.content" || log_fail "  ToolResultBlock.content MISSING"
        check_field "$TOOL_RESULT" "is_error" && log_pass "  ToolResultBlock.is_error" || log_info "  ToolResultBlock.is_error not set"
    else
        log_info "No ToolResultBlock in sample (may be in user messages)"
    fi
fi

# ============================================================================
log_section "Recent Sessions: GET /sessions/recent"
# ============================================================================

curl -sf "$SERVER/sessions/recent?limit=3" > "$TMP_DIR/recent.json" 2>/dev/null
if [ $? -ne 0 ]; then
    log_fail "Failed to fetch /sessions/recent"
else
    log_pass "Endpoint responds"
    RECENT_COUNT=$(jq '.sessions | length' "$TMP_DIR/recent.json")
    log_info "Found $RECENT_COUNT recent sessions"

    if [ "$RECENT_COUNT" -gt 0 ]; then
        SESSION=$(jq '.sessions[0]' "$TMP_DIR/recent.json")

        for field in id projectPath source messageCount; do
            check_field "$SESSION" "$field" && log_pass "sessions[].${field}" || log_fail "sessions[].${field} MISSING"
        done

        for field in title lastUserMessage lastAssistantMessage; do
            check_string_field "$SESSION" "$field"
            case $? in
                0) log_pass "sessions[].${field} (plain string)" ;;
                1) log_info "sessions[].${field} not set" ;;
                2) log_fail "sessions[].${field} IS JSON ARRAY" ;;
            esac
        done
    fi
fi

# ============================================================================
log_section "Summary"
# ============================================================================

# Cleanup
rm -rf "$TMP_DIR"

echo ""
echo -e "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}, ${YELLOW}$WARNINGS warnings${NC}"
echo ""

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}━━━ API VERIFICATION FAILED ━━━${NC}"
    echo "Fix the issues above before building iOS app"
    exit 1
else
    echo -e "${GREEN}━━━ API VERIFICATION PASSED ━━━${NC}"
    exit 0
fi
