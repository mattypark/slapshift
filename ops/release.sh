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

# Sign the DMG container itself (the .app inside is already signed by xcodebuild).
# Without this the .app passes Gatekeeper but the DMG container shows as
# "unsigned" in spctl --type install. --timestamp is required for notarization.
SIGN_ID="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ {print $2; exit}')"
if [ -z "$SIGN_ID" ]; then
    echo "error: no Developer ID Application cert in keychain" >&2
    exit 1
fi
codesign --sign "$SIGN_ID" --timestamp "$DMG_PATH"

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

# 7. Sparkle sign_update + appcast snippet
#
# Sparkle's auto-update needs an EdDSA signature on the DMG. sign_update
# reads the private key from the Mac's Keychain (created once by
# `generate_keys`, see ops/README.md) and emits a one-line snippet ready
# to drop into appcast.xml. We also stage the DMG into web/public/dl/ so
# `git add` + push deploys it via Vercel.
echo "--- [7/7] Sparkle sign + stage ---"

SPARKLE_BIN="$(find ~/Library/Developer/Xcode/DerivedData -type f -name sign_update -not -path '*old_dsa_scripts*' 2>/dev/null | head -1)"
if [ -z "$SPARKLE_BIN" ]; then
    # Fallback: SPM resolves Sparkle artifacts here when built via swift build
    SPARKLE_BIN="$(find "$APP_DIR/.build" -type f -name sign_update -not -path '*old_dsa_scripts*' 2>/dev/null | head -1)"
fi
if [ -z "$SPARKLE_BIN" ]; then
    # Last resort: brew install sparkle ships sign_update too
    SPARKLE_BIN="$(command -v sign_update || true)"
fi

WEB_DL="$ROOT/web/public/dl"
APPCAST="$ROOT/web/public/appcast.xml"
mkdir -p "$WEB_DL"

if [ -n "$SPARKLE_BIN" ]; then
    SIG_LINE="$("$SPARKLE_BIN" "$DMG_PATH")"
    echo "Sparkle signature:"
    echo "  $SIG_LINE"
    cp "$DMG_PATH" "$WEB_DL/SlapShift-$VERSION.dmg"
    # "latest" mirror: Vercel's DMG_URL env points at /dl/SlapShift-latest.dmg
    # so the marketing download link auto-updates every release without
    # touching the dashboard. Sparkle appcast still points at the versioned
    # file so update verification stays exact.
    cp "$DMG_PATH" "$WEB_DL/SlapShift-latest.dmg"
    echo "Staged: web/public/dl/SlapShift-$VERSION.dmg"
    echo "Staged: web/public/dl/SlapShift-latest.dmg (Vercel DMG_URL target)"
    echo ""
    echo "Drop this <item> into web/public/appcast.xml (above the others):"
    echo ""
    PUB_DATE="$(date -u +"%a, %d %b %Y %H:%M:%S +0000")"
    # Sparkle compares sparkle:version against the running app's CFBundleVersion
    # (the build number, NOT the marketing string). Read it from project.yml so
    # the appcast stays in lockstep.
    BUILD_NUM="$(grep -E '^\s*CURRENT_PROJECT_VERSION:' "$APP_DIR/project.yml" | head -1 | awk '{print $2}' | tr -d '\"')"
    cat <<EOF
        <item>
            <title>$VERSION</title>
            <pubDate>$PUB_DATE</pubDate>
            <sparkle:version>$BUILD_NUM</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
            <description><![CDATA[
                <h2>SlapShift $VERSION</h2>
                <ul>
                    <li>TODO: write changelog</li>
                </ul>
            ]]></description>
            <enclosure
                url="https://slapshift.app/dl/SlapShift-$VERSION.dmg"
                $SIG_LINE
                type="application/octet-stream"/>
        </item>
EOF
    echo ""
else
    echo "warning: sign_update not found — skipping Sparkle signing."
    echo "  Build the app once via Xcode (or swift build) so SPM resolves Sparkle artifacts,"
    echo "  or install via Homebrew: brew install --cask sparkle"
fi

echo ""
echo "=== Done ==="
echo "DMG: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
echo "Appcast: $APPCAST"
echo ""
echo "Next steps:"
echo "  1. Paste the <item> snippet above into web/public/appcast.xml"
echo "  2. cd web && git add public/dl/SlapShift-$VERSION.dmg public/appcast.xml && git commit && git push"
echo "  3. Vercel auto-deploys. Existing users get the update on next launch (or daily)."
