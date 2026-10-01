#!/bin/bash
set -euo pipefail

if ! xcodebuild -version >/dev/null 2>&1 && [ -d /Applications/Xcode.app ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

xcrun swift-format lint --recursive Sources Tests
xcodegen generate
xcodebuild -project Dormant.xcodeproj -scheme Dormant -destination 'platform=macOS' build
xcodebuild -project Dormant.xcodeproj -scheme Dormant -destination 'platform=macOS' test
(cd site && npm ci --include=dev && npm run build)
