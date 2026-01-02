#!/bin/bash
# Quick test runner for ContentBlockParser tests
# Usage: ./scripts/test-parsing.sh

set -e

echo "🧪 Running ContentBlockParser tests..."
echo ""

xcodebuild test \
  -project CodingBridge.xcodeproj \
  -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -only-testing:CodingBridgeTests/ContentBlockParserTests \
  2>&1 | xcpretty || xcodebuild test \
  -project CodingBridge.xcodeproj \
  -scheme CodingBridge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -only-testing:CodingBridgeTests/ContentBlockParserTests \
  2>&1 | grep -E "(Test Case|passed|failed|error:)"

echo ""
echo "✅ Done"
