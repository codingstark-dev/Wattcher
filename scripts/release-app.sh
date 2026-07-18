#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
IDENTITY="${WATTCHER_SIGNING_IDENTITY:?Set WATTCHER_SIGNING_IDENTITY to a Developer ID Application certificate}"
PROFILE="${WATTCHER_NOTARY_PROFILE:?Set WATTCHER_NOTARY_PROFILE to a notarytool keychain profile}"
APP="$ROOT/.build/Wattcher.app"
ARCHIVE="$ROOT/.build/Wattcher.zip"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
DMG="$ROOT/.build/Wattcher-$VERSION.dmg"

create_portable_archive() {
  rm -f "$ARCHIVE"
  ditto -c -k \
    --norsrc \
    --noextattr \
    --noqtn \
    --noacl \
    --keepParent \
    "$APP" \
    "$ARCHIVE"

  if /usr/bin/zipinfo -1 "$ARCHIVE" | /usr/bin/grep -Eq '(^|/)\._|^__MACOSX/'; then
    print -u2 "Release archive contains AppleDouble metadata files."
    exit 1
  fi
}

"$ROOT/scripts/build-app.sh" >/dev/null

codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

create_portable_archive
xcrun notarytool submit "$ARCHIVE" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
create_portable_archive
"$ROOT/scripts/build-dmg.sh" --existing-app >/dev/null
codesign --force --timestamp --sign "$IDENTITY" "$DMG"
codesign --verify --verbose=2 "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

print "$APP"
print "$ARCHIVE"
print "$DMG"
