#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
APP="$ROOT/.build/Wattcher.app"
DMG="$ROOT/.build/Wattcher-$VERSION.dmg"
WORK="$ROOT/.build/dmg"
STAGING="$WORK/root"
READ_WRITE_IMAGE="$WORK/Wattcher-rw.dmg"
VOLUME_NAME="Wattcher Installer"
DEVICE=""
MODE="${1:-}"

if [[ $# -gt 1 ]]; then
  print -u2 "Usage: $0 [--existing-app]"
  exit 64
fi

cleanup() {
  if [[ -n "$DEVICE" ]]; then
    hdiutil detach "$DEVICE" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

case "$MODE" in
  "")
    "$ROOT/scripts/build-app.sh" >/dev/null
    ;;
  --existing-app)
    if [[ ! -d "$APP" ]]; then
      print -u2 "Expected an existing app bundle at $APP"
      exit 1
    fi
    codesign --verify --deep --strict --verbose=2 "$APP"
    ;;
  *)
    print -u2 "Usage: $0 [--existing-app]"
    exit 64
    ;;
esac

rm -rf "$WORK"
rm -f "$DMG"
mkdir -p "$STAGING"
ditto --norsrc --noextattr --noqtn --noacl "$APP" "$STAGING/Wattcher.app"
ln -s /Applications "$STAGING/Applications"
mkdir -p "$STAGING/.background"
sips -s format png \
  "$ROOT/Resources/InstallerBackground.svg" \
  --out "$STAGING/.background/installer.png" >/dev/null
cp "$ROOT/Resources/Wattcher.icns" "$STAGING/.VolumeIcon.icns"
xcrun SetFile -a V "$STAGING/.VolumeIcon.icns"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDRW \
  "$READ_WRITE_IMAGE" >/dev/null

ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "$READ_WRITE_IMAGE")"
DEVICE="$(print -r -- "$ATTACH_OUTPUT" | awk '/^\/dev\// { device = $1 } END { print device }')"
MOUNT_POINT="$(print -r -- "$ATTACH_OUTPUT" | sed -n 's#^.*\t\(/Volumes/.*\)$#\1#p' | tail -1)"

if [[ -z "$DEVICE" || -z "$MOUNT_POINT" ]]; then
  print -u2 "Could not attach the writable installer image."
  exit 1
fi

xcrun SetFile -a C "$MOUNT_POINT"

osascript - "$VOLUME_NAME" <<'APPLESCRIPT'
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
hdiutil detach "$DEVICE" >/dev/null
DEVICE=""

hdiutil convert \
  "$READ_WRITE_IMAGE" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG" >/dev/null
hdiutil verify "$DMG" >/dev/null

print "$DMG"
