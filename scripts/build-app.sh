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
cp "$ROOT/Resources/Wattcher.icns" "$CONTENTS/Resources/Wattcher.icns"
mkdir -p "$CONTENTS/Frameworks"
cp -R "$ROOT/.build/release/Sparkle.framework" "$CONTENTS/Frameworks/Sparkle.framework"
install_name_tool -add_rpath @executable_path/../Frameworks "$CONTENTS/MacOS/Wattcher"
codesign --force --deep --sign - "$APP"
print "$APP"
