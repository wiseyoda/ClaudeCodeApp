#!/bin/bash
# Regenerate Swift types from cli-bridge OpenAPI spec
# Run this after API changes to update generated types

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/CodingBridge/Generated"
SPEC_URL="${CLI_BRIDGE_URL:-http://172.20.0.2:3100}/openapi.json"

echo "Fetching OpenAPI spec from $SPEC_URL..."
curl -s "$SPEC_URL" -o /tmp/openapi.json

VERSION=$(jq -r '.info.version' /tmp/openapi.json)
echo "API version: $VERSION"

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

for f in "$MODELS_DIR"/*.swift; do
  # Remove ParameterConvertible conformance (requires runtime support we don't need)
  sed -i '' 's/, ParameterConvertible//g' "$f"
done

echo "Moving to project..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Copy models
cp "$MODELS_DIR"/*.swift "$OUTPUT_DIR/"

# Copy required infrastructure (JSONValue for dynamic types)
cp "$INFRA_DIR/JSONValue.swift" "$OUTPUT_DIR/"

COUNT=$(ls "$OUTPUT_DIR"/*.swift | wc -l | tr -d ' ')
echo "Generated $COUNT Swift types in $OUTPUT_DIR"
echo ""
echo "IMPORTANT: If this is the first run, add the Generated folder to Xcode:"
echo "  1. Right-click CodingBridge in Xcode"
echo "  2. Add Files to 'CodingBridge'"
echo "  3. Select the Generated folder"
echo "  4. Check 'Create groups' and 'Add to target: CodingBridge'"
