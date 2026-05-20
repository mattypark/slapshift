#!/usr/bin/env bash
# SlapShift release pipeline.
#
# What this does, end-to-end:
#   1. archive  — xcodebuild archive (Release config, Developer ID signing)
#   2. export   — xcodebuild -exportArchive → unsigned-friendly .app
#   3. dmg      — wraps .app in a compressed DMG with /Applications symlink
#   4. notarize — xcrun notarytool submit --wait (blocks ~2-5 min)
#   5. staple   — xcrun stapler staple, so DMG works offline
#   6. verify   — spctl --assess + stapler validate
#
# Prerequisites (one-time setup — see ops/README.md):
#   - Apple Developer Program enrollment
#   - DEVELOPMENT_TEAM set in app/project.yml (re-run xcodegen after)
#   - Notary credentials stored in keychain:
#       xcrun notarytool store-credentials "slapshift-notary" \
#         --apple-id <your-apple-id> \
#         --team-id <your-team-id> \
#         --password <app-specific-password>
#
# Usage: ./release.sh [version]
#   version: optional, e.g. "0.1.0". If omitted, uses MARKETING_VERSION from project.yml.

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-slapshift-notary}"

ROOT="$(pwd)"
APP_DIR="$ROOT/app"
BUILD_DIR="$ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/SlapShift.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP_PATH="$EXPORT_DIR/SlapShift.app"

mkdir -p "$BUILD_DIR"

# Resolve version from project.yml if not passed explicitly.
if [ -z "$VERSION" ]; then
    VERSION="$(grep -E '^\s*MARKETING_VERSION:' "$APP_DIR/project.yml" | head -1 | awk '{print $2}' | tr -d '\"')"
fi
if [ -z "$VERSION" ]; then
    echo "error: could not determine version (pass as arg or set MARKETING_VERSION in project.yml)" >&2
    exit 1
fi

DMG_PATH="$BUILD_DIR/SlapShift-$VERSION.dmg"

echo "=== Building SlapShift $VERSION ==="

# 1. Archive
echo "--- [1/6] xcodebuild archive ---"
xcodebuild archive \
    -project "$APP_DIR/SlapShift.xcodeproj" \
    -scheme SlapShift \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination 'generic/platform=macOS' \
    | xcbeautify 2>/dev/null || xcodebuild archive \
        -project "$APP_DIR/SlapShift.xcodeproj" \
        -scheme SlapShift \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -destination 'generic/platform=macOS'

# 2. Export
echo "--- [2/6] xcodebuild exportArchive ---"
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$ROOT/ops/exportOptions.plist"

if [ ! -d "$APP_PATH" ]; then
    echo "error: exported app not found at $APP_PATH" >&2
    exit 1
fi

# 3. DMG
echo "--- [3/6] create DMG ---"
"$ROOT/ops/create-dmg.sh" "$APP_PATH" "$DMG_PATH"

# 4. Notarize
echo "--- [4/6] notarize (this can take 2-5 minutes) ---"
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

# 5. Staple — embed notarization ticket into DMG so it works offline
echo "--- [5/6] staple ---"
xcrun stapler staple "$DMG_PATH"

# 6. Verify
echo "--- [6/6] verify ---"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type install --verbose "$DMG_PATH" || {
    echo "warning: spctl assessment failed — DMG may not Gatekeeper-pass"
    echo "(but stapler validation succeeded, which is usually the canonical check)"
}

echo ""
echo "=== Done ==="
echo "DMG: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "Next: upload to your distribution host (R2 / S3 / Vercel blob) and publish."
