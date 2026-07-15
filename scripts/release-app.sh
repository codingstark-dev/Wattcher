#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
IDENTITY="${WATTCHER_SIGNING_IDENTITY:?Set WATTCHER_SIGNING_IDENTITY to a Developer ID Application certificate}"
PROFILE="${WATTCHER_NOTARY_PROFILE:?Set WATTCHER_NOTARY_PROFILE to a notarytool keychain profile}"
APP="$ROOT/.build/Wattcher.app"
ARCHIVE="$ROOT/.build/Wattcher.zip"

"$ROOT/scripts/build-app.sh" >/dev/null

codesign --force --options runtime --timestamp --sign "$IDENTITY" \
  "$APP/Contents/MacOS/Wattcher"
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

rm -f "$ARCHIVE"
ditto -c -k --keepParent "$APP" "$ARCHIVE"
xcrun notarytool submit "$ARCHIVE" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
rm -f "$ARCHIVE"
ditto -c -k --keepParent "$APP" "$ARCHIVE"
print "$APP"
