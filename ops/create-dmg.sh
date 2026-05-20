#!/usr/bin/env bash
# Build a notarizable DMG containing SlapShift.app + an Applications symlink.
#
# Usage: ./create-dmg.sh <path/to/SlapShift.app> <output.dmg>
#
# Why hdiutil and not create-dmg (brew)?
#   - hdiutil ships with macOS — one less dep to install on a fresh machine
#   - UDZO is the compressed read-only format Apple notarizes cleanly
#   - We don't need a custom background image for v1; cosmetics can come later

set -euo pipefail

APP_PATH="${1:-}"
OUTPUT_DMG="${2:-}"

if [ -z "$APP_PATH" ] || [ -z "$OUTPUT_DMG" ]; then
    echo "usage: $0 <SlapShift.app> <output.dmg>" >&2
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "error: app not found at $APP_PATH" >&2
    exit 1
fi

# Stage the DMG contents in a temp directory so hdiutil can snapshot it.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# UDZO = compressed read-only. -ov overwrites any existing output.
hdiutil create \
    -volname "SlapShift" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    "$OUTPUT_DMG"

echo "Created: $OUTPUT_DMG"
