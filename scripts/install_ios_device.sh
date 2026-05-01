#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Mirador.xcodeproj"
DERIVED_DATA_PATH="$ROOT_DIR/.build/xcode-ios-device"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphoneos/MiradorClientApp.app"
BUNDLE_ID="com.stevenacz.mirador.client"

if [[ -z "${DEVICE_ID:-}" ]]; then
  echo "error: DEVICE_ID is required" >&2
  echo "hint: xcrun xctrace list devices" >&2
  exit 1
fi

if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
  echo "error: DEVELOPMENT_TEAM is required" >&2
  echo "hint: set your Apple development team id in the environment" >&2
  exit 1
fi

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme MiradorClientApp \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  CODE_SIGN_STYLE=Automatic \
  build

xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing "$BUNDLE_ID"
