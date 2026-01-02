#!/bin/bash
# Regenerate Swift types from cli-bridge OpenAPI spec
# Run this after API changes to update generated types
#
# Generated types include:
# - REST API types (agents, sessions, projects, etc.)
# - WebSocket message types (ClientMessage, ServerMessage, StreamMessage, etc.)
# - Content block types (TextBlock, ToolUseBlock, ThinkingBlock, etc.)
#
# See CLAUDE.md for conflict resolution strategy

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/CodingBridge/Generated"
SPEC_URL="${CLI_BRIDGE_URL:-http://172.20.0.2:3100}/openapi.json"

echo "Fetching OpenAPI spec from $SPEC_URL..."
curl -s "$SPEC_URL" -o /tmp/openapi.json

VERSION=$(jq -r '.info.version' /tmp/openapi.json)
SCHEMA_COUNT=$(jq '.components.schemas | keys | length' /tmp/openapi.json)
echo "API version: $VERSION ($SCHEMA_COUNT schemas)"

echo "Generating Swift types (swift6 generator)..."
rm -rf /tmp/Generated
openapi-generator generate \
  -i /tmp/openapi.json \
  -g swift6 \
  -o /tmp/Generated \
  --skip-validate-spec \
  2>&1 | grep -v "^WARNING" | tail -5

echo "Cleaning up generated files..."
MODELS_DIR="/tmp/Generated/Sources/OpenAPIClient/Models"
INFRA_DIR="/tmp/Generated/Sources/OpenAPIClient/Infrastructure"

# Remove ParameterConvertible conformance (requires runtime support we don't need)
for f in "$MODELS_DIR"/*.swift; do
  sed -i '' 's/, ParameterConvertible//g' "$f"
done

# Types that conflict with our existing app types - prefix with "API"
# These are generated types that would clash with hand-written app types:
# - Project: App has Project model with UI properties, sessions list
# - GitStatus: App has GitStatus enum with icons, colors, accessibility
# - ThinkingMode: App has ThinkingMode enum with different semantics
# - Model: App has Model type for Claude model selection
# - Error: Conflicts with Swift.Error
# Note: Using perl for word boundary support (BSD sed on macOS doesn't support \b)
CONFLICTING_TYPES="Project|GitStatus|ThinkingMode|Model|Error"

for f in "$MODELS_DIR"/*.swift; do
  perl -i -pe "s/\b($CONFLICTING_TYPES)\b/API\$1/g" "$f"
done

# Rename conflicting files
for type in Project GitStatus ThinkingMode Model Error; do
  if [ -f "$MODELS_DIR/${type}.swift" ]; then
    mv "$MODELS_DIR/${type}.swift" "$MODELS_DIR/API${type}.swift"
  fi
done

echo "Moving to project..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Copy all models
cp "$MODELS_DIR"/*.swift "$OUTPUT_DIR/"

# Copy required infrastructure files
cp "$INFRA_DIR/JSONValue.swift" "$OUTPUT_DIR/"
cp "$INFRA_DIR/Validation.swift" "$OUTPUT_DIR/"

COUNT=$(ls "$OUTPUT_DIR"/*.swift | wc -l | tr -d ' ')
echo "Generated $COUNT Swift types in $OUTPUT_DIR"
echo ""
echo "Generated types include:"
echo "  - REST: AgentCreateBody, SessionMetadata, SearchResult, etc."
echo "  - WebSocket: ClientMessage, ServerMessage, StreamMessage, etc."
echo "  - Content: TextBlock, ToolUseBlock, ThinkingBlock, etc."
echo ""
echo "IMPORTANT: If this is the first run, add the Generated folder to Xcode:"
echo "  1. Right-click CodingBridge in Xcode"
echo "  2. Add Files to 'CodingBridge'"
echo "  3. Select the Generated folder"
echo "  4. Check 'Create groups' and 'Add to target: CodingBridge'"
