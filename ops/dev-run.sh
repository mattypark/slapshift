#!/usr/bin/env bash
# SlapShift fast local-dev build.
#
# What this does:
#   1. xcodebuild archive  — same as release, but no signing flags vary
#   2. exportArchive       — produces build/export/SlapShift.app
#   3. open the .app       — launches it as a real menu-bar agent
#
# What it DOES NOT do:
#   - sign/notarize/staple (skip — local launch doesn't care)
#   - build a DMG
#
# Why a separate script:
#   `swift build` (SwiftPM) only produces a bare executable. SlapShift is a
#   menu-bar agent (LSUIElement=true) that requires a proper .app bundle so
#   macOS reads Info.plist and skips installing a Dock icon. Running the raw
#   binary leaves you with a half-working app and a Dock icon you can't kill.
#
# Usage: ./ops/dev-run.sh
#   Takes ~20-30 seconds. Re-run after every code change you want to try.

set -euo pipefail

cd "$(dirname "$0")/.."

ROOT="$(pwd)"
APP_DIR="$ROOT/app"
BUILD_DIR="$ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/SlapShift-dev.xcarchive"
EXPORT_DIR="$BUILD_DIR/dev-export"
APP_PATH="$EXPORT_DIR/SlapShift.app"

mkdir -p "$BUILD_DIR"

echo "=== dev-run: building SlapShift ==="

# Kill any running instance so the new build's NSStatusItem isn't
# competing with a stale menu bar icon from a prior dev launch.
pkill -x SlapShift 2>/dev/null || true

# 1. Archive
echo "--- [1/3] xcodebuild archive ---"
xcodebuild archive \
    -project "$APP_DIR/SlapShift.xcodeproj" \
    -scheme SlapShift \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination 'generic/platform=macOS' \
    -quiet

# 2. Export
echo "--- [2/3] exportArchive ---"
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$ROOT/ops/exportOptions.plist" \
    -quiet

if [ ! -d "$APP_PATH" ]; then
    echo "error: exported app not found at $APP_PATH" >&2
    exit 1
fi

# 3. Launch
echo "--- [3/3] launching $APP_PATH ---"
open "$APP_PATH"

echo ""
echo "=== Done. App is running ==="
echo "App path: $APP_PATH"
echo ""
echo "Look for the SlapShift hand icon in your menu bar."
echo "Click 'Show Home' from the menu bar to open the new dashboard."
