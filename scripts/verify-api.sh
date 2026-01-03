#!/bin/bash
# Comprehensive API verification script for cli-bridge
# Validates all fields required by the iOS app
# Usage: ./scripts/verify-api.sh [server-url]
# Env:
#   VERIFY_API_TOKEN=...              (Bearer token for /api/push endpoints)
#   VERIFY_API_PROJECT_PATH=...       (Absolute project path override)
#   VERIFY_API_ENCODED_PATH=...       (Encoded project path override)
#   VERIFY_API_SESSION_ID=...         (Session ID override)
#   VERIFY_API_REQUIRE_PERMISSIONS=1  (Treat missing /permissions as failure)

SERVER="${1:-http://localhost:3100}"
PASSED=0
FAILED=0
WARNINGS=0
TMP_DIR="/tmp/cli-bridge-verify"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT
WARNINGS_LIST=()
FAILURES_LIST=()

VERIFY_API_TOKEN="${VERIFY_API_TOKEN:-}"
VERIFY_API_PROJECT_PATH="${VERIFY_API_PROJECT_PATH:-}"
VERIFY_API_ENCODED_PATH="${VERIFY_API_ENCODED_PATH:-}"
VERIFY_API_SESSION_ID="${VERIFY_API_SESSION_ID:-}"
VERIFY_API_REQUIRE_PERMISSIONS="${VERIFY_API_REQUIRE_PERMISSIONS:-0}"

if [ -n "$VERIFY_API_TOKEN" ]; then
    AUTH_HEADER=(-H "Authorization: Bearer $VERIFY_API_TOKEN")
else
    AUTH_HEADER=()
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

log_pass() { echo -e "${GREEN}✓${NC} $1"; ((PASSED++)); }
log_fail() { echo -e "${RED}✗${NC} $1"; ((FAILED++)); FAILURES_LIST+=("$1"); }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; ((WARNINGS++)); WARNINGS_LIST+=("$1"); }
log_info() { echo -e "${CYAN}→${NC} $1"; }
log_skip() { echo -e "${GRAY}↷${NC} $1"; }
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

is_http_ok() {
    local status="$1"
    [ "$status" -ge 200 ] && [ "$status" -lt 300 ]
}

request_json() {
    local url="$1"
    local output="$2"
    shift 2
    local status
    status=$(curl -sS -o "$output" -w "%{http_code}" "$@" "$url" || echo "000")
    echo "$status"
}

request_text() {
    local url="$1"
    local output="$2"
    shift 2
    local status
    status=$(curl -sS -o "$output" -w "%{http_code}" "$@" "$url" || echo "000")
    echo "$status"
}

ensure_json() {
    local file="$1"
    jq -e . "$file" >/dev/null 2>&1
}

encode_project_path() {
    echo "$1" | sed 's|^/|-|; s|/|-|g'
}

url_encode() {
    printf '%s' "$1" | jq -sRr @uri
}

check_type() {
    local json="$1"
    local field="$2"
    local expected="$3"
    echo "$json" | jq -e ".$field | type == \"$expected\"" >/dev/null 2>&1
}

check_enum_field() {
    local json="$1"
    local field="$2"
    shift 2
    local value
    value=$(echo "$json" | jq -r ".$field // \"__NULL__\"")
    [ "$value" = "__NULL__" ] || [ "$value" = "null" ] && return 1
    for option in "$@"; do
        [ "$value" = "$option" ] && return 0
    done
    return 2
}

is_uuid() {
    local value="$1"
    [[ "$value" =~ ^[0-9a-fA-F-]{36}$ ]]
}

TEST_PROJECT_PATH=""
TEST_PROJECT_ENCODED=""
TEST_SESSION_ID=""
TEST_AGENT_ID=""

if [ -n "$VERIFY_API_PROJECT_PATH" ]; then
    TEST_PROJECT_PATH="$VERIFY_API_PROJECT_PATH"
    TEST_PROJECT_ENCODED="$(encode_project_path "$TEST_PROJECT_PATH")"
elif [ -n "$VERIFY_API_ENCODED_PATH" ]; then
    TEST_PROJECT_ENCODED="$VERIFY_API_ENCODED_PATH"
fi

if [ -n "$VERIFY_API_SESSION_ID" ]; then
    TEST_SESSION_ID="$VERIFY_API_SESSION_ID"
fi

# ============================================================================
log_section "Health Check"
# ============================================================================

HEALTH_STATUS=$(request_json "$SERVER/health" "$TMP_DIR/health.json")
if is_http_ok "$HEALTH_STATUS"; then
    log_pass "Server reachable at $SERVER"
    if ! ensure_json "$TMP_DIR/health.json"; then
        log_fail "Health response is not valid JSON"
        exit 1
    fi
    VERSION=$(jq -r '.version // "unknown"' "$TMP_DIR/health.json")
    log_info "Server version: $VERSION"
    HEALTH_STATE=$(jq -r '.status // empty' "$TMP_DIR/health.json")
    if [ -n "$HEALTH_STATE" ]; then
        case "$HEALTH_STATE" in
            ok|healthy) log_pass "Health status: $HEALTH_STATE" ;;
            *) log_warn "Health status: $HEALTH_STATE" ;;
        esac
    fi
else
    log_fail "Server not reachable at $SERVER (HTTP $HEALTH_STATUS)"
    echo -e "\n${RED}Cannot continue without server connection${NC}"
    exit 1
fi

# ============================================================================
log_section "OpenAPI: GET /openapi.json"
# ============================================================================

OPENAPI_STATUS=$(request_json "$SERVER/openapi.json" "$TMP_DIR/openapi.json")
if is_http_ok "$OPENAPI_STATUS"; then
    log_pass "Endpoint responds"
    if ensure_json "$TMP_DIR/openapi.json"; then
        OPENAPI_VERSION=$(jq -r '.info.version // "unknown"' "$TMP_DIR/openapi.json")
        log_info "Spec version: $OPENAPI_VERSION"
        if [ "$VERSION" != "unknown" ] && [ "$OPENAPI_VERSION" != "unknown" ] && [ "$VERSION" != "$OPENAPI_VERSION" ]; then
            log_warn "Health version ($VERSION) differs from OpenAPI ($OPENAPI_VERSION)"
        fi
        PATH_COUNT=$(jq '.paths | length' "$TMP_DIR/openapi.json")
        SCHEMA_COUNT=$(jq '.components.schemas | length' "$TMP_DIR/openapi.json")
        [ "$PATH_COUNT" -gt 0 ] && log_pass "Spec paths: $PATH_COUNT" || log_fail "Spec paths missing"
        [ "$SCHEMA_COUNT" -gt 0 ] && log_pass "Spec schemas: $SCHEMA_COUNT" || log_fail "Spec schemas missing"
    else
        log_fail "OpenAPI response is not valid JSON"
    fi
else
    log_fail "Failed to fetch /openapi.json (HTTP $OPENAPI_STATUS)"
fi

# ============================================================================
log_section "Metrics: GET /metrics"
# ============================================================================

METRICS_STATUS=$(request_text "$SERVER/metrics" "$TMP_DIR/metrics.txt")
if is_http_ok "$METRICS_STATUS"; then
    log_pass "Endpoint responds"
    if [ -s "$TMP_DIR/metrics.txt" ]; then
        log_pass "Metrics payload non-empty"
    else
        log_warn "Metrics payload empty"
    fi
else
    log_fail "Failed to fetch /metrics (HTTP $METRICS_STATUS)"
fi

# ============================================================================
log_section "Config: GET /config/models"
# ============================================================================

MODELS_STATUS=$(request_json "$SERVER/config/models" "$TMP_DIR/models.json")
if is_http_ok "$MODELS_STATUS"; then
    log_pass "Endpoint responds"
    if ensure_json "$TMP_DIR/models.json"; then
        check_type "$(cat "$TMP_DIR/models.json")" "models" "array" && log_pass "models (array)" || log_fail "models (array) MISSING"
        MODELS_COUNT=$(jq '.models | length' "$TMP_DIR/models.json")
        log_info "Found $MODELS_COUNT models"
        if [ "$MODELS_COUNT" -gt 0 ]; then
            MODEL=$(jq '.models[0]' "$TMP_DIR/models.json")
            check_field "$MODEL" "id" && log_pass "models[].id" || log_fail "models[].id MISSING"
            check_type "$MODEL" "contextWindow" "number" && log_pass "models[].contextWindow" || log_fail "models[].contextWindow MISSING"
        else
            log_warn "No models returned"
        fi
    else
        log_fail "Models response is not valid JSON"
    fi
else
    log_fail "Failed to fetch /config/models (HTTP $MODELS_STATUS)"
fi

# ============================================================================
log_section "Config: GET /config/thinking-modes"
# ============================================================================

THINKING_STATUS=$(request_json "$SERVER/config/thinking-modes" "$TMP_DIR/thinking-modes.json")
if is_http_ok "$THINKING_STATUS"; then
    log_pass "Endpoint responds"
    if ensure_json "$TMP_DIR/thinking-modes.json"; then
        check_type "$(cat "$TMP_DIR/thinking-modes.json")" "modes" "array" && log_pass "modes (array)" || log_fail "modes (array) MISSING"
        MODE_COUNT=$(jq '.modes | length' "$TMP_DIR/thinking-modes.json")
        log_info "Found $MODE_COUNT thinking modes"
        if [ "$MODE_COUNT" -gt 0 ]; then
            MODE=$(jq '.modes[0]' "$TMP_DIR/thinking-modes.json")
            for field in id name description phrase; do
                check_field "$MODE" "$field" && log_pass "modes[].${field}" || log_fail "modes[].${field} MISSING"
            done
            check_type "$MODE" "budget" "number" && log_pass "modes[].budget" || log_fail "modes[].budget MISSING"
        else
            log_warn "No thinking modes returned"
        fi
    else
        log_fail "Thinking modes response is not valid JSON"
    fi
else
    log_fail "Failed to fetch /config/thinking-modes (HTTP $THINKING_STATUS)"
fi

# ============================================================================
log_section "Permissions: GET /permissions"
# ============================================================================

PERMISSIONS_STATUS=$(request_json "$SERVER/permissions" "$TMP_DIR/permissions.json")
if is_http_ok "$PERMISSIONS_STATUS"; then
    log_pass "Endpoint responds"
    if ensure_json "$TMP_DIR/permissions.json"; then
        PERMISSIONS=$(cat "$TMP_DIR/permissions.json")
        check_field "$PERMISSIONS" "global" && log_pass "permissions.global" || log_fail "permissions.global MISSING"
        check_field "$PERMISSIONS" "projects" && log_pass "permissions.projects" || log_fail "permissions.projects MISSING"
        check_type "$PERMISSIONS" "projects" "object" && log_pass "permissions.projects (object)" || log_fail "permissions.projects INVALID"

        check_type "$PERMISSIONS" "global.bypass_all" "boolean" && \
            log_pass "permissions.global.bypass_all" || log_fail "permissions.global.bypass_all MISSING"
        check_enum_field "$PERMISSIONS" "global.default_mode" "default" "acceptEdits" "bypassPermissions"
        case $? in
            0) log_pass "permissions.global.default_mode" ;;
            1) log_fail "permissions.global.default_mode MISSING" ;;
            2) log_fail "permissions.global.default_mode INVALID" ;;
        esac
    else
        log_fail "Permissions response is not valid JSON"
    fi
else
    if [ "$PERMISSIONS_STATUS" -eq 404 ] && [ "$VERIFY_API_REQUIRE_PERMISSIONS" -ne 1 ]; then
        log_warn "Permissions endpoint not supported (HTTP 404)"
    else
        log_fail "Failed to fetch /permissions (HTTP $PERMISSIONS_STATUS)"
    fi
fi

# ============================================================================
log_section "Projects: GET /projects"
# ============================================================================

PROJECTS_STATUS=$(request_json "$SERVER/projects" "$TMP_DIR/projects.json")
if is_http_ok "$PROJECTS_STATUS"; then
    log_pass "Endpoint responds"
    if ensure_json "$TMP_DIR/projects.json"; then
        check_type "$(cat "$TMP_DIR/projects.json")" "projects" "array" && log_pass "projects (array)" || log_fail "projects (array) MISSING"
        PROJECT_COUNT=$(jq '.projects | length' "$TMP_DIR/projects.json")
        log_info "Found $PROJECT_COUNT projects"

        if [ "$PROJECT_COUNT" -gt 0 ]; then
            PROJECT=$(jq '.projects[0]' "$TMP_DIR/projects.json")

            # Required fields
            for field in path name; do
                check_field "$PROJECT" "$field" && log_pass "projects[].${field}" || log_fail "projects[].${field} MISSING"
            done

            # Optional fields
            if check_field "$PROJECT" "lastUsed"; then
                check_date_field "$PROJECT" "lastUsed"
                case $? in
                    0) log_pass "projects[].lastUsed (ISO8601)" ;;
                    2) log_fail "projects[].lastUsed NOT ISO8601" ;;
                esac
            else
                log_info "projects[].lastUsed not set"
            fi

            if check_field "$PROJECT" "sessionCount"; then
                check_type "$PROJECT" "sessionCount" "number" && log_pass "projects[].sessionCount" || log_fail "projects[].sessionCount INVALID"
            else
                log_info "projects[].sessionCount not set"
            fi

            # Git info
            if jq -e '.git' <<< "$PROJECT" > /dev/null 2>&1; then
                log_pass "projects[].git"
                if check_field "$(jq '.git' <<< "$PROJECT")" "branch"; then
                    log_pass "projects[].git.branch"
                else
                    log_info "projects[].git.branch not set"
                fi
            fi

            if [ -z "$TEST_PROJECT_PATH" ]; then
                TEST_PROJECT_PATH=$(jq -r '.path' <<< "$PROJECT")
            fi
            if [ -z "$TEST_PROJECT_ENCODED" ] && [ -n "$TEST_PROJECT_PATH" ]; then
                TEST_PROJECT_ENCODED=$(encode_project_path "$TEST_PROJECT_PATH")
            fi
        fi
    else
        log_fail "Projects response is not valid JSON"
    fi
else
    log_fail "Failed to fetch /projects (HTTP $PROJECTS_STATUS)"
fi

# ============================================================================
log_section "Project Detail: GET /projects/{path}"
# ============================================================================

if [ -n "$TEST_PROJECT_ENCODED" ]; then
    PROJECT_DETAIL_STATUS=$(request_json "$SERVER/projects/$TEST_PROJECT_ENCODED" "$TMP_DIR/project-detail.json")
    if is_http_ok "$PROJECT_DETAIL_STATUS"; then
        log_pass "Endpoint responds"
        if ensure_json "$TMP_DIR/project-detail.json"; then
            PROJECT_DETAIL=$(cat "$TMP_DIR/project-detail.json")
            for field in path name; do
                check_field "$PROJECT_DETAIL" "$field" && log_pass "project.${field}" || log_fail "project.${field} MISSING"
            done
            if check_field "$PROJECT_DETAIL" "lastUsed"; then
                check_date_field "$PROJECT_DETAIL" "lastUsed"
                case $? in
                    0) log_pass "project.lastUsed (ISO8601)" ;;
                    2) log_fail "project.lastUsed NOT ISO8601" ;;
                esac
            else
                log_info "project.lastUsed not set"
            fi
            if check_field "$PROJECT_DETAIL" "sessionCount"; then
                check_type "$PROJECT_DETAIL" "sessionCount" "number" && log_pass "project.sessionCount" || log_fail "project.sessionCount INVALID"
            else
                log_info "project.sessionCount not set"
            fi
        else
            log_fail "Project detail response is not valid JSON"
        fi
    else
        log_fail "Failed to fetch /projects/{path} (HTTP $PROJECT_DETAIL_STATUS)"
    fi
else
    log_skip "No project available for detail checks"
fi

# ============================================================================
log_section "Files: GET /projects/{path}/files"
# ============================================================================

TEST_FILE_PATH=""
if [ -n "$TEST_PROJECT_ENCODED" ]; then
    ROOT_FILES_STATUS=$(request_json "$SERVER/projects/$TEST_PROJECT_ENCODED/files?dir=/" "$TMP_DIR/files-root.json")
    if is_http_ok "$ROOT_FILES_STATUS"; then
        log_pass "Endpoint responds"
        if ensure_json "$TMP_DIR/files-root.json"; then
            ROOT_FILES=$(cat "$TMP_DIR/files-root.json")
            check_field "$ROOT_FILES" "path" && log_pass "files.path" || log_fail "files.path MISSING"
            check_type "$ROOT_FILES" "entries" "array" && log_pass "files.entries" || log_fail "files.entries MISSING"

            TEST_FILE_PATH=$(jq -r '.entries[] | select(.type == "file") | select(.size == null or .size < 200000) | .name' "$TMP_DIR/files-root.json" | head -n1)
            if [ -z "$TEST_FILE_PATH" ]; then
                SUBDIR=$(jq -r '.entries[] | select(.type == "directory") | .name' "$TMP_DIR/files-root.json" | head -n1)
                if [ -n "$SUBDIR" ]; then
                    SUBDIR_ENCODED=$(url_encode "/$SUBDIR")
                    SUBDIR_STATUS=$(request_json "$SERVER/projects/$TEST_PROJECT_ENCODED/files?dir=$SUBDIR_ENCODED" "$TMP_DIR/files-subdir.json")
                    if is_http_ok "$SUBDIR_STATUS" && ensure_json "$TMP_DIR/files-subdir.json"; then
                        SUB_FILE=$(jq -r '.entries[] | select(.type == "file") | select(.size == null or .size < 200000) | .name' "$TMP_DIR/files-subdir.json" | head -n1)
                        if [ -n "$SUB_FILE" ]; then
                            TEST_FILE_PATH="$SUBDIR/$SUB_FILE"
                        fi
                    fi
                fi
            fi
        else
            log_fail "Files response is not valid JSON"
        fi
    else
        log_fail "Failed to fetch /projects/{path}/files (HTTP $ROOT_FILES_STATUS)"
    fi
else
    log_skip "No project available for files checks"
fi

if [ -n "$TEST_PROJECT_ENCODED" ] && [ -n "$TEST_FILE_PATH" ]; then
    FILE_PATH_ENCODED=$(url_encode "$TEST_FILE_PATH")
    FILE_STATUS=$(request_json "$SERVER/projects/$TEST_PROJECT_ENCODED/files/$FILE_PATH_ENCODED" "$TMP_DIR/file.json")
    if is_http_ok "$FILE_STATUS"; then
        log_pass "File content responds"
        if ensure_json "$TMP_DIR/file.json"; then
            FILE_CONTENT=$(cat "$TMP_DIR/file.json")
            for field in path content mimeType; do
                check_field "$FILE_CONTENT" "$field" && log_pass "file.${field}" || log_fail "file.${field} MISSING"
            done
            check_type "$FILE_CONTENT" "size" "number" && log_pass "file.size" || log_fail "file.size MISSING"
            check_date_field "$FILE_CONTENT" "modified"
            case $? in
                0) log_pass "file.modified (ISO8601)" ;;
                1) log_fail "file.modified MISSING" ;;
                2) log_fail "file.modified NOT ISO8601" ;;
            esac
        else
            log_fail "File content response is not valid JSON"
        fi
    else
        if [ "$FILE_STATUS" -eq 400 ] && ensure_json "$TMP_DIR/file.json"; then
            FILE_ERROR=$(jq -r '.error // empty' "$TMP_DIR/file.json")
            case "$FILE_ERROR" in
                BINARY_FILE|FILE_TOO_LARGE) log_warn "File content skipped ($FILE_ERROR)" ;;
                *) log_fail "File content error ($FILE_ERROR)" ;;
            esac
        else
            log_fail "Failed to fetch file content (HTTP $FILE_STATUS)"
        fi
    fi
else
    log_skip "No file available for file content checks"
fi

# ============================================================================
log_section "Subrepos: GET /projects/{path}/subrepos"
# ============================================================================

if [ -n "$TEST_PROJECT_ENCODED" ]; then
    SUBREPOS_STATUS=$(request_json "$SERVER/projects/$TEST_PROJECT_ENCODED/subrepos" "$TMP_DIR/subrepos.json")
    if is_http_ok "$SUBREPOS_STATUS"; then
        log_pass "Endpoint responds"
        if ensure_json "$TMP_DIR/subrepos.json"; then
            check_type "$(cat "$TMP_DIR/subrepos.json")" "subrepos" "array" && log_pass "subrepos (array)" || log_fail "subrepos (array) MISSING"
            SUBREPO_COUNT=$(jq '.subrepos | length' "$TMP_DIR/subrepos.json")
            log_info "Found $SUBREPO_COUNT subrepos"
            if [ "$SUBREPO_COUNT" -gt 0 ]; then
                SUBREPO=$(jq '.subrepos[0]' "$TMP_DIR/subrepos.json")
                check_field "$SUBREPO" "relativePath" && log_pass "subrepos[].relativePath" || log_fail "subrepos[].relativePath MISSING"
                if jq -e '.git' <<< "$SUBREPO" >/dev/null 2>&1; then
                    log_pass "subrepos[].git"
                fi
            fi
        else
            log_fail "Subrepos response is not valid JSON"
        fi
    else
        log_fail "Failed to fetch /projects/{path}/subrepos (HTTP $SUBREPOS_STATUS)"
    fi
else
    log_skip "No project available for subrepo checks"
fi

# ============================================================================
log_section "Sessions: GET /projects/{path}/sessions"
# ============================================================================

if [ -n "$TEST_PROJECT_ENCODED" ]; then
    SESSIONS_STATUS=$(request_json "$SERVER/projects/$TEST_PROJECT_ENCODED/sessions?limit=5" "$TMP_DIR/sessions.json")
    if is_http_ok "$SESSIONS_STATUS"; then
        log_pass "Endpoint responds"
        if ensure_json "$TMP_DIR/sessions.json"; then
            check_type "$(cat "$TMP_DIR/sessions.json")" "sessions" "array" && log_pass "sessions (array)" || log_fail "sessions (array) MISSING"
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

                check_type "$SESSION" "messageCount" "number" && log_pass "sessions[].messageCount (number)" || log_fail "sessions[].messageCount INVALID"

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
                if check_field "$SESSION" "customTitle"; then
                    log_pass "sessions[].customTitle"
                else
                    log_info "sessions[].customTitle not set"
                fi

                if check_field "$SESSION" "model"; then
                    log_pass "sessions[].model"
                else
                    log_info "sessions[].model not set"
                fi

                if check_field "$SESSION" "archivedAt"; then
                    check_date_field "$SESSION" "archivedAt"
                    case $? in
                        0) log_pass "sessions[].archivedAt (ISO8601)" ;;
                        2) log_fail "sessions[].archivedAt NOT ISO8601" ;;
                    esac
                else
                    log_info "sessions[].archivedAt not set"
                fi

                if check_field "$SESSION" "parentSessionId"; then
                    log_pass "sessions[].parentSessionId"
                else
                    log_info "sessions[].parentSessionId not set"
                fi

                if [ -z "$TEST_SESSION_ID" ]; then
                    TEST_SESSION_ID=$(jq -r '.id' <<< "$SESSION")
                fi
            fi
        else
            log_fail "Sessions response is not valid JSON"
        fi
    else
        log_fail "Failed to fetch sessions (HTTP $SESSIONS_STATUS)"
    fi
fi

# ============================================================================
log_section "Session Count: GET /projects/{path}/sessions/count"
# ============================================================================

if [ -n "$TEST_PROJECT_ENCODED" ]; then
    COUNT_STATUS=$(request_json "$SERVER/projects/$TEST_PROJECT_ENCODED/sessions/count" "$TMP_DIR/session-count.json")
    if is_http_ok "$COUNT_STATUS"; then
        log_pass "Endpoint responds"
        if ensure_json "$TMP_DIR/session-count.json"; then
            COUNT_JSON=$(cat "$TMP_DIR/session-count.json")
            if check_field "$COUNT_JSON" "total"; then
                check_type "$COUNT_JSON" "total" "number" && log_pass "sessionCount.total" || log_fail "sessionCount.total INVALID"
            else
                log_warn "sessionCount.total missing"
            fi
            for field in count user agent helper; do
                if check_field "$COUNT_JSON" "$field"; then
                    check_type "$COUNT_JSON" "$field" "number" && log_pass "sessionCount.${field}" || log_fail "sessionCount.${field} INVALID"
                fi
            done
        else
            log_fail "Session count response is not valid JSON"
        fi
    else
        log_fail "Failed to fetch /sessions/count (HTTP $COUNT_STATUS)"
    fi
else
    log_skip "No project available for session count checks"
fi

# ============================================================================
log_section "Session Detail: GET /projects/{path}/sessions/{id}"
# ============================================================================

if [ -n "$TEST_PROJECT_ENCODED" ] && [ -n "$TEST_SESSION_ID" ]; then
    SESSION_DETAIL_STATUS=$(request_json "$SERVER/projects/$TEST_PROJECT_ENCODED/sessions/$TEST_SESSION_ID" "$TMP_DIR/session-detail.json")
    if is_http_ok "$SESSION_DETAIL_STATUS"; then
        log_pass "Endpoint responds"
        if ensure_json "$TMP_DIR/session-detail.json"; then
            SESSION_DETAIL=$(cat "$TMP_DIR/session-detail.json")
            for field in id projectPath source messageCount; do
                check_field "$SESSION_DETAIL" "$field" && log_pass "session.${field}" || log_fail "session.${field} MISSING"
            done
            for field in createdAt lastActivityAt; do
                check_date_field "$SESSION_DETAIL" "$field"
                case $? in
                    0) log_pass "session.${field} (ISO8601)" ;;
                    1) log_fail "session.${field} MISSING" ;;
                    2) log_fail "session.${field} NOT ISO8601" ;;
                esac
            done
        else
            log_fail "Session detail response is not valid JSON"
        fi
    else
        log_fail "Failed to fetch session detail (HTTP $SESSION_DETAIL_STATUS)"
    fi
else
    log_skip "No session available for session detail checks"
fi

# ============================================================================
log_section "Session Children: GET /projects/{path}/sessions/{id}/children"
# ============================================================================

if [ -n "$TEST_PROJECT_ENCODED" ] && [ -n "$TEST_SESSION_ID" ]; then
    CHILDREN_STATUS=$(request_json "$SERVER/projects/$TEST_PROJECT_ENCODED/sessions/$TEST_SESSION_ID/children?limit=5" "$TMP_DIR/session-children.json")
    if is_http_ok "$CHILDREN_STATUS"; then
        log_pass "Endpoint responds"
        if ensure_json "$TMP_DIR/session-children.json"; then
            check_type "$(cat "$TMP_DIR/session-children.json")" "sessions" "array" && log_pass "children.sessions" || log_fail "children.sessions MISSING"
            CHILD_COUNT=$(jq '.sessions | length' "$TMP_DIR/session-children.json")
            log_info "Found $CHILD_COUNT child sessions"
            check_field "$(cat "$TMP_DIR/session-children.json")" "total" && log_pass "children.total" || log_warn "children.total missing"
        else
            log_fail "Session children response is not valid JSON"
        fi
    else
        log_fail "Failed to fetch session children (HTTP $CHILDREN_STATUS)"
    fi
else
    log_skip "No session available for session children checks"
fi

# ============================================================================
log_section "Session Search: GET /projects/{path}/sessions/search"
# ============================================================================

if [ -n "$TEST_PROJECT_ENCODED" ]; then
    SEARCH_QUERY="the"
    SEARCH_STATUS=$(request_json "$SERVER/projects/$TEST_PROJECT_ENCODED/sessions/search?q=$SEARCH_QUERY&limit=5" "$TMP_DIR/session-search.json")
    if is_http_ok "$SEARCH_STATUS"; then
        log_pass "Endpoint responds"
        if ensure_json "$TMP_DIR/session-search.json"; then
            check_field "$(cat "$TMP_DIR/session-search.json")" "query" && log_pass "search.query" || log_fail "search.query MISSING"
            check_field "$(cat "$TMP_DIR/session-search.json")" "results" && log_pass "search.results" || log_fail "search.results MISSING"
            check_type "$(cat "$TMP_DIR/session-search.json")" "results" "array" && log_pass "search.results (array)" || log_fail "search.results (array) MISSING"
            if check_field "$(cat "$TMP_DIR/session-search.json")" "total"; then
                check_type "$(cat "$TMP_DIR/session-search.json")" "total" "number" && log_pass "search.total" || log_fail "search.total INVALID"
            else
                log_fail "search.total MISSING"
            fi
            if check_field "$(cat "$TMP_DIR/session-search.json")" "hasMore"; then
                check_type "$(cat "$TMP_DIR/session-search.json")" "hasMore" "boolean" && log_pass "search.hasMore" || log_fail "search.hasMore INVALID"
            else
                log_warn "search.hasMore missing (/projects/{path}/sessions/search)"
            fi

            SEARCH_COUNT=$(jq '.results | length' "$TMP_DIR/session-search.json")
            log_info "Search results: $SEARCH_COUNT"
            if [ "$SEARCH_COUNT" -gt 0 ]; then
                RESULT=$(jq '.results[0]' "$TMP_DIR/session-search.json")
                for field in sessionId projectPath score; do
                    check_field "$RESULT" "$field" && log_pass "results[].${field}" || log_fail "results[].${field} MISSING"
                done
                check_type "$RESULT" "snippets" "array" && log_pass "results[].snippets" || log_fail "results[].snippets MISSING"
                check_date_field "$RESULT" "timestamp"
                case $? in
                    0) log_pass "results[].timestamp (ISO8601)" ;;
                    1) log_fail "results[].timestamp MISSING" ;;
                    2) log_fail "results[].timestamp NOT ISO8601" ;;
                esac
            fi
        else
            log_fail "Session search response is not valid JSON"
        fi
    else
        log_fail "Failed to fetch session search (HTTP $SEARCH_STATUS)"
    fi
else
    log_skip "No project available for session search checks"
fi

# ============================================================================
log_section "Messages: GET /projects/{path}/sessions/{id}/messages"
# ============================================================================

if [ -n "$TEST_PROJECT_ENCODED" ] && [ -n "$TEST_SESSION_ID" ]; then
    MESSAGES_STATUS=$(request_json "$SERVER/projects/$TEST_PROJECT_ENCODED/sessions/$TEST_SESSION_ID/messages?limit=50&includeRawContent=true" "$TMP_DIR/messages.json")
    if is_http_ok "$MESSAGES_STATUS"; then
        log_pass "Endpoint responds"
        if ensure_json "$TMP_DIR/messages.json"; then
            API_VERSION=$(jq -r '.apiVersion // "unknown"' "$TMP_DIR/messages.json")
            log_info "API version: $API_VERSION"

            check_type "$(cat "$TMP_DIR/messages.json")" "messages" "array" && log_pass "messages (array)" || log_fail "messages (array) MISSING"
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

            # Optional filters/integrity/error
            if jq -e '.filters' "$TMP_DIR/messages.json" > /dev/null 2>&1; then
                log_pass "response.filters"
            fi
            if jq -e '.integrity' "$TMP_DIR/messages.json" > /dev/null 2>&1; then
                log_pass "response.integrity"
                for field in totalLines validLines corruptedLines corruptedSamples; do
                    check_field "$(jq '.integrity' "$TMP_DIR/messages.json")" "$field" && \
                        log_pass "integrity.${field}" || log_fail "integrity.${field} MISSING"
                done
            fi
            if jq -e '.error | type != "null"' "$TMP_DIR/messages.json" > /dev/null 2>&1; then
                log_warn "response.error present"
            fi

            if [ "$MESSAGE_COUNT" -gt 0 ]; then
                FIRST_MESSAGE_ID=$(jq -r '.messages[0].id' "$TMP_DIR/messages.json")
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
        else
            log_fail "Messages response is not valid JSON"
        fi
    else
        log_fail "Failed to fetch messages (HTTP $MESSAGES_STATUS)"
    fi
fi

# ============================================================================
log_section "Messages Pagination: cursors"
# ============================================================================

if [ -n "$TEST_PROJECT_ENCODED" ] && [ -n "$TEST_SESSION_ID" ] && [ -n "$FIRST_MESSAGE_ID" ]; then
    if is_uuid "$FIRST_MESSAGE_ID"; then
        CURSOR_STATUS=$(request_json "$SERVER/projects/$TEST_PROJECT_ENCODED/sessions/$TEST_SESSION_ID/messages?limit=5&before=$FIRST_MESSAGE_ID" "$TMP_DIR/messages-before.json")
        if is_http_ok "$CURSOR_STATUS"; then
            log_pass "Endpoint responds"
            if ensure_json "$TMP_DIR/messages-before.json"; then
                check_type "$(cat "$TMP_DIR/messages-before.json")" "messages" "array" && \
                    log_pass "cursor.messages" || log_fail "cursor.messages MISSING"
            else
                log_fail "Cursor response is not valid JSON"
            fi
        else
            log_fail "Failed to fetch cursor messages (HTTP $CURSOR_STATUS)"
        fi
    else
        log_warn "Message id is not UUID; skipping cursor pagination"
    fi
else
    log_skip "No message available for cursor pagination checks"
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
log_section "Session Export: GET /projects/{path}/sessions/{id}/export"
# ============================================================================

if [ -n "$TEST_PROJECT_ENCODED" ] && [ -n "$TEST_SESSION_ID" ]; then
    EXPORT_STATUS=$(request_text "$SERVER/projects/$TEST_PROJECT_ENCODED/sessions/$TEST_SESSION_ID/export?format=markdown&excludeThinking=true" "$TMP_DIR/session-export.md")
    if is_http_ok "$EXPORT_STATUS"; then
        log_pass "Endpoint responds"
        if [ -s "$TMP_DIR/session-export.md" ]; then
            log_pass "Export payload non-empty"
        else
            log_warn "Export payload empty"
        fi
    else
        log_fail "Failed to export session (HTTP $EXPORT_STATUS)"
    fi
else
    log_skip "No session available for export checks"
fi

# ============================================================================
log_section "Search: GET /search"
# ============================================================================

SEARCH_QUERY="the"
SEARCH_URL="$SERVER/search?q=$SEARCH_QUERY&limit=5"
if [ -n "$TEST_PROJECT_PATH" ]; then
    SEARCH_URL="$SEARCH_URL&project=$(url_encode "$TEST_PROJECT_PATH")"
fi
GLOBAL_SEARCH_STATUS=$(request_json "$SEARCH_URL" "$TMP_DIR/search.json")
if is_http_ok "$GLOBAL_SEARCH_STATUS"; then
    log_pass "Endpoint responds"
    if ensure_json "$TMP_DIR/search.json"; then
        check_field "$(cat "$TMP_DIR/search.json")" "query" && log_pass "search.query" || log_fail "search.query MISSING"
        check_field "$(cat "$TMP_DIR/search.json")" "results" && log_pass "search.results" || log_fail "search.results MISSING"
        check_type "$(cat "$TMP_DIR/search.json")" "results" "array" && log_pass "search.results (array)" || log_fail "search.results (array) MISSING"
        if check_field "$(cat "$TMP_DIR/search.json")" "total"; then
            check_type "$(cat "$TMP_DIR/search.json")" "total" "number" && log_pass "search.total" || log_fail "search.total INVALID"
        else
            log_fail "search.total MISSING"
        fi
        if check_field "$(cat "$TMP_DIR/search.json")" "hasMore"; then
            check_type "$(cat "$TMP_DIR/search.json")" "hasMore" "boolean" && log_pass "search.hasMore" || log_fail "search.hasMore INVALID"
        else
            log_warn "search.hasMore missing (/search)"
        fi
        SEARCH_RESULT_COUNT=$(jq '.results | length' "$TMP_DIR/search.json")
        log_info "Search results: $SEARCH_RESULT_COUNT"
        if [ "$SEARCH_RESULT_COUNT" -gt 0 ]; then
            RESULT=$(jq '.results[0]' "$TMP_DIR/search.json")
            for field in sessionId projectPath score; do
                check_field "$RESULT" "$field" && log_pass "results[].${field}" || log_fail "results[].${field} MISSING"
            done
            check_type "$RESULT" "snippets" "array" && log_pass "results[].snippets" || log_fail "results[].snippets MISSING"
            check_date_field "$RESULT" "timestamp"
            case $? in
                0) log_pass "results[].timestamp (ISO8601)" ;;
                1) log_fail "results[].timestamp MISSING" ;;
                2) log_fail "results[].timestamp NOT ISO8601" ;;
            esac
        fi
    else
        log_fail "Search response is not valid JSON"
    fi
else
    log_fail "Failed to fetch /search (HTTP $GLOBAL_SEARCH_STATUS)"
fi

# ============================================================================
log_section "Agents: GET /agents"
# ============================================================================

AGENTS_STATUS=$(request_json "$SERVER/agents" "$TMP_DIR/agents.json")
if is_http_ok "$AGENTS_STATUS"; then
    log_pass "Endpoint responds"
    if ensure_json "$TMP_DIR/agents.json"; then
        check_type "$(cat "$TMP_DIR/agents.json")" "agents" "array" && log_pass "agents (array)" || log_fail "agents (array) MISSING"
        AGENT_COUNT=$(jq '.agents | length' "$TMP_DIR/agents.json")
        log_info "Found $AGENT_COUNT agents"
        if [ "$AGENT_COUNT" -gt 0 ]; then
            AGENT=$(jq '.agents[0]' "$TMP_DIR/agents.json")
            for field in id projectPath sessionId model state; do
                check_field "$AGENT" "$field" && log_pass "agents[].${field}" || log_fail "agents[].${field} MISSING"
            done
            check_type "$AGENT" "isHelper" "boolean" && log_pass "agents[].isHelper" || log_fail "agents[].isHelper MISSING"
            check_type "$AGENT" "hasActiveConnection" "boolean" && log_pass "agents[].hasActiveConnection" || log_fail "agents[].hasActiveConnection MISSING"
            for field in createdAt lastActivityAt; do
                check_date_field "$AGENT" "$field"
                case $? in
                    0) log_pass "agents[].${field} (ISO8601)" ;;
                    1) log_fail "agents[].${field} MISSING" ;;
                    2) log_fail "agents[].${field} NOT ISO8601" ;;
                esac
            done
            TEST_AGENT_ID=$(jq -r '.id' <<< "$AGENT")
        fi
    else
        log_fail "Agents response is not valid JSON"
    fi
else
    log_fail "Failed to fetch /agents (HTTP $AGENTS_STATUS)"
fi

# ============================================================================
log_section "Agent Detail: GET /agents/{id}"
# ============================================================================

if [ -n "$TEST_AGENT_ID" ]; then
    AGENT_DETAIL_STATUS=$(request_json "$SERVER/agents/$TEST_AGENT_ID" "$TMP_DIR/agent-detail.json")
    if is_http_ok "$AGENT_DETAIL_STATUS"; then
        log_pass "Endpoint responds"
        if ensure_json "$TMP_DIR/agent-detail.json"; then
            AGENT_DETAIL=$(cat "$TMP_DIR/agent-detail.json")
            for field in id projectPath sessionId model state permissionMode; do
                check_field "$AGENT_DETAIL" "$field" && log_pass "agent.${field}" || log_fail "agent.${field} MISSING"
            done
            for field in isHelper hasPendingPermission hasPendingQuestion hasQueuedInput; do
                check_type "$AGENT_DETAIL" "$field" "boolean" && log_pass "agent.${field}" || log_fail "agent.${field} MISSING"
            done
            for field in createdAt lastActivityAt; do
                check_date_field "$AGENT_DETAIL" "$field"
                case $? in
                    0) log_pass "agent.${field} (ISO8601)" ;;
                    1) log_fail "agent.${field} MISSING" ;;
                    2) log_fail "agent.${field} NOT ISO8601" ;;
                esac
            done
        else
            log_fail "Agent detail response is not valid JSON"
        fi
    else
        log_fail "Failed to fetch agent detail (HTTP $AGENT_DETAIL_STATUS)"
    fi
else
    log_skip "No agent available for detail checks"
fi

# ============================================================================
log_section "Agent Images: GET /agents/{id}/images"
# ============================================================================

if [ -n "$TEST_AGENT_ID" ]; then
    AGENT_IMAGES_STATUS=$(request_json "$SERVER/agents/$TEST_AGENT_ID/images" "$TMP_DIR/agent-images.json")
    if is_http_ok "$AGENT_IMAGES_STATUS"; then
        log_pass "Endpoint responds"
        if ensure_json "$TMP_DIR/agent-images.json"; then
            check_type "$(cat "$TMP_DIR/agent-images.json")" "images" "array" && log_pass "images (array)" || log_fail "images (array) MISSING"
            IMAGE_COUNT=$(jq '.images | length' "$TMP_DIR/agent-images.json")
            log_info "Found $IMAGE_COUNT images"
            if [ "$IMAGE_COUNT" -gt 0 ]; then
                IMAGE=$(jq '.images[0]' "$TMP_DIR/agent-images.json")
                for field in id mimeType size createdAt; do
                    check_field "$IMAGE" "$field" && log_pass "images[].${field}" || log_fail "images[].${field} MISSING"
                done
                check_date_field "$IMAGE" "createdAt"
                case $? in
                    0) log_pass "images[].createdAt (ISO8601)" ;;
                    2) log_fail "images[].createdAt NOT ISO8601" ;;
                esac
            fi
        else
            log_fail "Agent images response is not valid JSON"
        fi
    else
        log_fail "Failed to fetch agent images (HTTP $AGENT_IMAGES_STATUS)"
    fi
else
    log_skip "No agent available for image checks"
fi

# ============================================================================
log_section "Push: GET /api/push/status"
# ============================================================================

if [ -n "$VERIFY_API_TOKEN" ]; then
    PUSH_STATUS=$(request_json "$SERVER/api/push/status" "$TMP_DIR/push-status.json" "${AUTH_HEADER[@]}")
    if is_http_ok "$PUSH_STATUS"; then
        log_pass "Endpoint responds"
        if ensure_json "$TMP_DIR/push-status.json"; then
            PUSH_JSON=$(cat "$TMP_DIR/push-status.json")
            for field in provider providerEnabled fcmTokenRegistered liveActivityTokens recentDeliveries; do
                check_field "$PUSH_JSON" "$field" && log_pass "push.${field}" || log_fail "push.${field} MISSING"
            done
            check_type "$PUSH_JSON" "providerEnabled" "boolean" && log_pass "push.providerEnabled (boolean)" || log_fail "push.providerEnabled INVALID"
            check_type "$PUSH_JSON" "fcmTokenRegistered" "boolean" && log_pass "push.fcmTokenRegistered (boolean)" || log_fail "push.fcmTokenRegistered INVALID"
            check_type "$PUSH_JSON" "liveActivityTokens" "array" && log_pass "push.liveActivityTokens (array)" || log_fail "push.liveActivityTokens INVALID"
            check_type "$PUSH_JSON" "recentDeliveries" "array" && log_pass "push.recentDeliveries (array)" || log_fail "push.recentDeliveries INVALID"
        else
            log_fail "Push status response is not valid JSON"
        fi
    else
        log_fail "Failed to fetch push status (HTTP $PUSH_STATUS)"
    fi
else
    log_skip "No VERIFY_API_TOKEN set for push status"
fi

# ============================================================================
log_section "Recent Sessions: GET /sessions/recent"
# ============================================================================

RECENT_STATUS=$(request_json "$SERVER/sessions/recent?limit=3" "$TMP_DIR/recent.json")
if is_http_ok "$RECENT_STATUS"; then
    log_pass "Endpoint responds"
    if ensure_json "$TMP_DIR/recent.json"; then
        RECENT_COUNT=$(jq '.sessions | length' "$TMP_DIR/recent.json")
        log_info "Found $RECENT_COUNT recent sessions"

        if [ "$RECENT_COUNT" -gt 0 ]; then
            SESSION=$(jq '.sessions[0]' "$TMP_DIR/recent.json")

            for field in id projectPath source messageCount; do
                check_field "$SESSION" "$field" && log_pass "sessions[].${field}" || log_fail "sessions[].${field} MISSING"
            done
            check_type "$SESSION" "messageCount" "number" && log_pass "sessions[].messageCount (number)" || log_fail "sessions[].messageCount INVALID"

            for field in createdAt lastActivityAt; do
                check_date_field "$SESSION" "$field"
                case $? in
                    0) log_pass "sessions[].${field} (ISO8601)" ;;
                    1) log_fail "sessions[].${field} MISSING" ;;
                    2) log_fail "sessions[].${field} NOT ISO8601" ;;
                esac
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
    else
        log_fail "Recent sessions response is not valid JSON"
    fi
else
    log_fail "Failed to fetch /sessions/recent (HTTP $RECENT_STATUS)"
fi

# ============================================================================
log_section "Summary"
# ============================================================================

echo ""
echo -e "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}, ${YELLOW}$WARNINGS warnings${NC}"
echo ""

if [ ${#FAILURES_LIST[@]} -gt 0 ]; then
    echo -e "${RED}Failures:${NC}"
    for item in "${FAILURES_LIST[@]}"; do
        echo "  - $item"
    done
    echo ""
fi

if [ ${#WARNINGS_LIST[@]} -gt 0 ]; then
    echo -e "${YELLOW}Warnings:${NC}"
    for item in "${WARNINGS_LIST[@]}"; do
        echo "  - $item"
    done
    echo ""
fi

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}━━━ API VERIFICATION FAILED ━━━${NC}"
    echo "Fix the issues above before building iOS app"
    exit 1
else
    echo -e "${GREEN}━━━ API VERIFICATION PASSED ━━━${NC}"
    exit 0
fi
