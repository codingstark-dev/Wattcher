#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
ARCHIVE="$ROOT/.build/Wattcher-$VERSION.zip"
UPDATES="$ROOT/.build/updates"
APPCAST_TOOL="$ROOT/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"

"$ROOT/scripts/release-app.sh" >/dev/null
mkdir -p "$UPDATES"
cp "$ROOT/.build/Wattcher.zip" "$ARCHIVE"
cp "$ARCHIVE" "$UPDATES/Wattcher-$VERSION.zip"
cp "$ROOT/appcast.xml" "$UPDATES/appcast.xml"

"$APPCAST_TOOL" \
  --account app.wattcher.Wattcher \
  --download-url-prefix "https://github.com/codingstark-dev/Wattcher/releases/download/v$VERSION/" \
  --link "https://github.com/codingstark-dev/Wattcher" \
  "$UPDATES"

cp "$UPDATES/appcast.xml" "$ROOT/appcast.xml"
print "$ARCHIVE"
print "$ROOT/appcast.xml"
