#!/bin/bash
# ─────────────────────────────────────────────────────────────────
# NotchMirror — create-dmg.sh
# Run this AFTER doing Product → Archive → Export in Xcode.
# Usage: ./create-dmg.sh /path/to/exported/NotchMirror.app
# ─────────────────────────────────────────────────────────────────

set -e

APP="${1:-./NotchMirror.app}"
DMG_NAME="NotchMirror"
DMG_STAGING="/tmp/dmg-staging-$$"
OUT_DMG="./${DMG_NAME}.dmg"

if [ ! -d "$APP" ]; then
    echo "❌  App not found at: $APP"
    echo "    Usage: $0 /path/to/NotchMirror.app"
    exit 1
fi

echo "📦  Staging..."
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP" "$DMG_STAGING/"
# Add an /Applications symlink so the user can drag-install
ln -s /Applications "$DMG_STAGING/Applications"

echo "🖼   Creating DMG..."
hdiutil create \
    -volname "$DMG_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$OUT_DMG"

rm -rf "$DMG_STAGING"

echo ""
echo "✅  Done: $OUT_DMG"
echo "    Distribute this file. Users double-click it, drag NotchMirror"
echo "    to Applications, then double-click to launch."
echo ""
echo "💡  To notarize (requires Apple Developer account):"
echo "    xcrun notarytool submit $OUT_DMG \\"
echo "        --apple-id you@example.com \\"
echo "        --team-id XXXXXXXXXX \\"
echo "        --password <app-specific-password> \\"
echo "        --wait"
echo "    xcrun stapler staple $OUT_DMG"
