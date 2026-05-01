#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

DERIVED_DATA=".build/xcode-macos-app"
APP_PATH="$DERIVED_DATA/Build/Products/Debug/MiradorHostApp.app"

pkill -x MiradorHostApp 2>/dev/null || true
xcodebuild \
  -project Mirador.xcodeproj \
  -scheme MiradorHostApp \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  build

/usr/bin/open -n "$APP_PATH"
