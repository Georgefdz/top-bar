# TopBar

A tiny, native macOS menu bar manager. Pick the icons you don't want to see, and TopBar tucks them away until you ask for them.

<!-- Screenshot goes here: ![TopBar](docs/screenshot.png) -->

## Why

I built this because of OBS. Every time I recorded, its icon sat in my menu bar staring back at me, and on a notched MacBook that space is precious. There are great menu bar managers out there, but I wanted something small that I fully understand: plain Swift, AppKit + SwiftUI, no dependencies.

## What it does

- **Per-app sections.** Every app with a menu bar icon shows up in Settings. Set it to **Visible**, **Hidden** or **Always Hidden**.
- **One click to reveal.** Click the TopBar chevron to show your hidden icons. Option-click it to show the Always Hidden ones too.
- **Other ways to reveal**, each of which you can turn on or off:
  - hover over an empty part of the menu bar
  - click an empty part of the menu bar
  - scroll or swipe in the menu bar
- **Auto-rehide.** Hidden icons tuck themselves away again after a moment.
- **It remembers.** Settings are saved per app, so if OBS restarts, its icon stays hidden.
- **Launch at login**, if you want it.

## Requirements

- macOS 14 or later (tested on macOS 27)
- Xcode or the Swift toolchain (Swift 5.10+)
- The Accessibility permission, which TopBar uses to find menu bar icons and move them

## Install

There's no prebuilt download yet, so you build it yourself. It takes about a minute:

```sh
git clone https://github.com/<your-username>/top-bar.git
cd top-bar
Scripts/build-app.sh
open /Applications/TopBar.app
```

The script builds a release binary, wraps it in `TopBar.app`, signs it ad-hoc and installs it to `/Applications`. If a copy is already running, it quits that copy first.

Next, give TopBar the Accessibility permission: **System Settings → Privacy & Security → Accessibility**. Then click the chevron, open Settings, and choose which apps to hide.

> **Run it from `/Applications`.** On macOS 27, a copy run from anywhere else can end up hiding its own icon, which leaves you with nothing to click.

## How it works

**On macOS 27 and later**, the menu bar is drawn as a single window, so the classic trick of stretching a spacer to push icons off-screen no longer works. Instead, TopBar uses the same allow-list macOS uses for exam mode. It tells the system which apps may show icons, and macOS hides the rest and reflows the bar. Then TopBar Cmd-drags the icons you revealed so they sit just left of the chevron.

**On older macOS**, TopBar uses separator status items: `[always hidden] | [hidden] | [visible] [chevron]`. Stretching a separator pushes everything to its left off-screen, and synthesized Cmd-drags put each app's icon in the right section.

## Heads-up

- **macOS 27 support relies on a private framework** (`MenuBarClientCore`). A macOS update could rename or change it. If that happens, TopBar catches the error and falls back to the older method, but that method can't hide icons on macOS 27.
- **Rebuilding resets Accessibility.** Ad-hoc signatures change on every build, so you have to re-enable TopBar in the Accessibility list. Sign with a real certificate and the permission survives rebuilds:
  `SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" Scripts/build-app.sh`
- **No App Store, no sandbox.** Moving other apps' icons needs synthesized mouse events, which the sandbox blocks.
- Apps without a bundle ID can't be allow-listed, so they're hidden whenever TopBar is hiding anything.
- **Stuck with no icons?** Run `pkill -x TopBar`. Everything comes back as soon as the app quits.

## Roadmap

- A drag-and-drop layout editor
- Hiding an app's menus when they overlap your icons
- A second bar below the notch for hidden icons
- Appearance options: tint, gradients, shadows, borders, rounded shapes

## Development

It's a plain Swift package with no Xcode project. Open `Package.swift` in Xcode if you want the IDE.

```sh
swift build
swift test      # the pure logic: move planning, geometry, allow-lists
/usr/bin/log show --last 5m --info --predicate 'subsystem == "dev.topbar.TopBar"'
```

## License

[MIT](LICENSE)
