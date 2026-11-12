#!/bin/bash
# Builds build/TopBar.app. Set SIGN_IDENTITY to a real certificate so the
# Accessibility grant survives rebuilds (ad-hoc "-" signatures change every build).
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP=build/TopBar.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/TopBar" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
echo "Built $APP"

# macOS 27 only lets an allow-listed app keep its own menu bar icon when it runs from /Applications.
pkill -x TopBar || true
rm -rf /Applications/TopBar.app
cp -R "$APP" /Applications/
echo "Installed /Applications/TopBar.app"
