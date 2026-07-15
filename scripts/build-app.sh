#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"

swift build -c release

APP="$ROOT/.build/Wattcher.app"
CONTENTS="$APP/Contents"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$ROOT/.build/release/Wattcher" "$CONTENTS/MacOS/Wattcher"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
codesign --force --deep --sign - "$APP"
print "$APP"
