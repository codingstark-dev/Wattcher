#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
IDENTITY="${WATTCHER_SIGNING_IDENTITY:?Set WATTCHER_SIGNING_IDENTITY to a Developer ID Application certificate}"
PROFILE="${WATTCHER_NOTARY_PROFILE:?Set WATTCHER_NOTARY_PROFILE to a notarytool keychain profile}"
APP="$ROOT/.build/Wattcher.app"
ARCHIVE="$ROOT/.build/Wattcher.zip"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
DMG="$ROOT/.build/Wattcher-$VERSION.dmg"
DMG_WORK="$ROOT/.build/release-dmg"
DMG_STAGING="$DMG_WORK/root"
DMG_READ_WRITE="$DMG_WORK/Wattcher-rw.dmg"
DMG_VOLUME_NAME="Wattcher Installer"
DMG_DEVICE=""

cleanup() {
  if [[ -n "$DMG_DEVICE" ]]; then
    hdiutil detach "$DMG_DEVICE" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

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

create_dmg() {
  rm -rf "$DMG_WORK"
  rm -f "$DMG"
  mkdir -p "$DMG_STAGING"
  ditto --norsrc --noextattr --noqtn --noacl "$APP" "$DMG_STAGING/Wattcher.app"
  ln -s /Applications "$DMG_STAGING/Applications"
  mkdir -p "$DMG_STAGING/.background"
  sips -s format png \
    "$ROOT/Resources/InstallerBackground.svg" \
    --out "$DMG_STAGING/.background/installer.png" >/dev/null
  cp "$ROOT/Resources/Wattcher.icns" "$DMG_STAGING/.VolumeIcon.icns"
  xcrun SetFile -a V "$DMG_STAGING/.VolumeIcon.icns"

  hdiutil create \
    -volname "$DMG_VOLUME_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDRW \
    "$DMG_READ_WRITE" >/dev/null

  local attach_output mount_point
  attach_output="$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_READ_WRITE")"
  DMG_DEVICE="$(print -r -- "$attach_output" | awk '/^\/dev\// { device = $1 } END { print device }')"
  mount_point="$(print -r -- "$attach_output" | sed -n 's#^.*\t\(/Volumes/.*\)$#\1#p' | tail -1)"

  if [[ -z "$DMG_DEVICE" || -z "$mount_point" ]]; then
    print -u2 "Could not attach the writable installer image."
    exit 1
  fi

  xcrun SetFile -a C "$mount_point"

  osascript - "$DMG_VOLUME_NAME" <<'APPLESCRIPT'
on run arguments
  set volumeName to item 1 of arguments
  tell application "Finder"
    tell disk volumeName
      open
      set installerWindow to container window
      set current view of installerWindow to icon view
      set toolbar visible of installerWindow to false
      set statusbar visible of installerWindow to false
      set bounds of installerWindow to {180, 180, 820, 560}
      set viewOptions to icon view options of installerWindow
      set arrangement of viewOptions to not arranged
      set background picture of viewOptions to file ".background:installer.png"
      set icon size of viewOptions to 112
      set text size of viewOptions to 14
      set position of item "Wattcher.app" to {190, 190}
      set position of item "Applications" to {450, 190}
      update
      delay 2
      close installerWindow
    end tell
  end tell
end run
APPLESCRIPT

  sync
  hdiutil detach "$DMG_DEVICE" >/dev/null
  DMG_DEVICE=""

  hdiutil convert \
    "$DMG_READ_WRITE" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG" >/dev/null
  hdiutil verify "$DMG" >/dev/null
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
create_dmg
codesign --force --timestamp --sign "$IDENTITY" "$DMG"
codesign --verify --verbose=2 "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

print "$APP"
print "$ARCHIVE"
print "$DMG"
