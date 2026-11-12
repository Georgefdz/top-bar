#!/bin/bash
# On-screen end-to-end test: hides a fixture status item ("Q7Z9Q") through the real TopBar.app
# and checks, by OCR on a menu bar screenshot, that it disappears and comes back in each state.
# Needs Screen Recording for the terminal. Screenshots stay in build/e2e-<section>-<state>.png.
# Usage: Scripts/e2e.sh [--no-build]
set -euo pipefail
cd "$(dirname "$0")/.."

DOMAIN=dev.topbar.TopBar
FIX_ID=dev.topbar.Fixture
FIX=build/TopBarFixture.app
INSTALLED_FIX=/Applications/TopBarFixture.app # macOS 27 hides restricted items of apps outside /Applications

if [[ "${1:-}" != "--no-build" ]]; then
    Scripts/build-app.sh
    swift build -c release --product TopBarFixture
    rm -rf "$FIX" && mkdir -p "$FIX/Contents/MacOS"
    cp "$(swift build -c release --show-bin-path)/TopBarFixture" "$FIX/Contents/MacOS/"
    sed "s/>TopBar</>TopBarFixture</g; s/$DOMAIN/$FIX_ID/" Resources/Info.plist > "$FIX/Contents/Info.plist"
    codesign --force --sign - "$FIX"
    rm -rf "$INSTALLED_FIX" && cp -R "$FIX" "$INSTALLED_FIX"
    swiftc -O Scripts/e2e-probe.swift -o build/e2e-probe
fi

# Keep the user's settings and put them back however the test ends.
BACKUP=$(mktemp)
defaults export "$DOMAIN" "$BACKUP"
cleanup() {
    pkill -x TopBarFixture || true
    pkill -x TopBar || true
    defaults import "$DOMAIN" "$BACKUP" && rm -f "$BACKUP"
    open /Applications/TopBar.app
}
trap cleanup EXIT

command() { # posts dev.topbar.command and gives macOS time to reflow the bar
    swift -e "import Foundation; DistributedNotificationCenter.default().postNotificationName(.init(\"dev.topbar.command\"), object: \"$1\", userInfo: nil, deliverImmediately: true)"
    sleep 2
}

WIDTH=$(swift -e 'import AppKit; print(Int(NSScreen.main!.frame.width))')
visible() { # visible <png>: screenshots the menu bar and looks for the fixture's title
    screencapture -x -R0,0,$WIDTH,40 "$1"
    build/e2e-probe "$1" | grep -q Q7Z9Q # substring: OCR may join it with the chevron
}

FAILED=0
expect() { # expect <state> <shown|hidden>
    command "$1"
    local shot="build/e2e-$SECTION-$1.png" actual=hidden
    visible "$shot" && actual=shown
    if [[ "$actual" == "$2" ]]; then echo "ok   $SECTION / $1: $actual"
    else echo "FAIL $SECTION / $1: expected $2, got $actual (see $shot)"; FAILED=1
    fi
}

run() { # run <section> <collapsed> <expanded> <showAll>
    SECTION=$1
    pkill -x TopBar || true
    defaults write "$DOMAIN" autoRehide -bool false
    defaults write "$DOMAIN" sections -dict-add "$FIX_ID" "$SECTION"
    open /Applications/TopBar.app
    sleep 2
    expect collapse "$2"
    expect expand "$3"
    expect showAll "$4"
}

pkill -x TopBarFixture || true
pkill -x TopBar || true # no restriction while TopBar is off, so the fixture must show
open "$INSTALLED_FIX"
sleep 2
visible build/e2e-baseline.png || { echo "Q7Z9Q not found on screen: grant the terminal Screen Recording"; exit 2; }

run hidden hidden shown shown
run alwaysHidden hidden hidden shown
run visible shown shown shown

/usr/bin/log show --last 2m --info --predicate "subsystem == \"$DOMAIN\"" | grep -E "native visibility|failed" | tail -3 || true
[[ $FAILED == 0 ]] && echo "e2e passed" || { echo "e2e FAILED"; exit 1; }
