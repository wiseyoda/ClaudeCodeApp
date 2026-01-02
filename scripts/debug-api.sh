#!/bin/bash
# Quick API debugging script for cli-bridge
# Usage: ./scripts/debug-api.sh [command] [args...]

SERVER="${CLI_BRIDGE_URL:-http://localhost:3100}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

cmd_help() {
    echo "CLI Bridge API Debug Tool"
    echo ""
    echo "Usage: $0 <command> [args...]"
    echo ""
    echo "Commands:"
    echo "  health              Check server health"
    echo "  projects            List all projects"
    echo "  sessions <path>     List sessions for a project (encoded path)"
    echo "  recent [limit]      List recent sessions (default: 5)"
    echo "  messages <path> <session-id>  Get messages for a session"
    echo "  raw <endpoint>      Raw GET request to any endpoint"
    echo ""
    echo "Examples:"
    echo "  $0 health"
    echo "  $0 recent 3"
    echo "  $0 sessions -Users-ppatterson-dev-ClaudeCodeApp"
    echo "  $0 messages -Users-ppatterson-dev-ClaudeCodeApp abc123-def456"
    echo ""
    echo "Environment:"
    echo "  CLI_BRIDGE_URL      Server URL (default: http://localhost:3100)"
}

cmd_health() {
    echo -e "${BLUE}GET /health${NC}"
    curl -s "$SERVER/health" | python3 -m json.tool
}

cmd_projects() {
    echo -e "${BLUE}GET /projects${NC}"
    curl -s "$SERVER/projects" | python3 -m json.tool
}

cmd_sessions() {
    local path="$1"
    if [ -z "$path" ]; then
        echo -e "${RED}Error: Project path required${NC}"
        echo "Usage: $0 sessions <encoded-path>"
        echo "Example: $0 sessions -Users-ppatterson-dev-myproject"
        exit 1
    fi
    echo -e "${BLUE}GET /projects/$path/sessions${NC}"
    curl -s "$SERVER/projects/$path/sessions?limit=5" | python3 -m json.tool
}

cmd_recent() {
    local limit="${1:-5}"
    echo -e "${BLUE}GET /sessions/recent?limit=$limit${NC}"
    curl -s "$SERVER/sessions/recent?limit=$limit" | python3 -m json.tool
}

cmd_messages() {
    local path="$1"
    local session="$2"
    if [ -z "$path" ] || [ -z "$session" ]; then
        echo -e "${RED}Error: Project path and session ID required${NC}"
        echo "Usage: $0 messages <encoded-path> <session-id>"
        exit 1
    fi
    echo -e "${BLUE}GET /projects/$path/sessions/$session/messages${NC}"
    curl -s "$SERVER/projects/$path/sessions/$session/messages?limit=5&order=desc&includeRawContent=true" | python3 -m json.tool
}

cmd_raw() {
    local endpoint="$1"
    if [ -z "$endpoint" ]; then
        echo -e "${RED}Error: Endpoint required${NC}"
        exit 1
    fi
    echo -e "${BLUE}GET $endpoint${NC}"
    curl -s "$SERVER$endpoint" | python3 -m json.tool
}

# Parse title to extract text from content blocks
cmd_parse_title() {
    local json="$1"
    echo -e "${YELLOW}Input:${NC} $json"
    echo -e "${GREEN}Parsed:${NC}"
    echo "$json" | python3 -c "
import json
import sys

raw = sys.stdin.read().strip()
try:
    # Try parsing as JSON array of content blocks
    blocks = json.loads(raw)
    if isinstance(blocks, list):
        texts = [b.get('text', '') for b in blocks if b.get('type') == 'text']
        print(' '.join(texts))
    else:
        print(raw)
except:
    print(raw)
"
}

# Main
case "${1:-help}" in
    health)   cmd_health ;;
    projects) cmd_projects ;;
    sessions) cmd_sessions "$2" ;;
    recent)   cmd_recent "$2" ;;
    messages) cmd_messages "$2" "$3" ;;
    raw)      cmd_raw "$2" ;;
    parse)    cmd_parse_title "$2" ;;
    help|*)   cmd_help ;;
esac
