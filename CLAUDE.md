# TopBar

A native macOS menu bar manager (Swift, AppKit + SwiftUI). It hides other apps' menu bar icons (e.g. OBS) by moving them behind separator status items.

Full plan and roadmap: `~/.claude/plans/hey-okay-so-we-tender-torvalds.md`

## Build, run, test
- `swift build` / `swift test`: SwiftPM, no Xcode project. Open `Package.swift` in Xcode if you want the IDE.
- `Scripts/build-app.sh && open /Applications/TopBar.app`: wraps the binary into a `.app` with `Resources/Info.plist` (LSUIElement, so no Dock icon), ad-hoc codesigns it, quits the running copy, and installs it to `/Applications`. A real `.app` is required for Accessibility and launch at login.
- **Always run the `/Applications` copy.** On macOS 27, a restricted menu bar hides TopBar's own chevron when the app runs from `build/` (even with `lsregister`, and even though its bundle ID is on the allow-list). The user is then left with no icon to click.
- Logs: `log show --last 5m --info --predicate 'subsystem == "dev.topbar.TopBar"'`
- Saved settings: `defaults read dev.topbar.TopBar`
- Toolchain: macOS 27, Xcode 16.2, Swift 6.0.3, but the package uses tools-version 5.10 (Swift 5 language mode). Minimum target is macOS 14.

## How hiding works
There are two engines. `MenuBarManager` picks one at launch with `NativeVisibility.isAvailable`.

**macOS 27+ (native, the one this Mac uses):**
- macOS 27 draws the whole menu bar as one window. Making a separator very long no longer pushes icons off-screen: macOS just refuses to re-lay out the bar.
- Instead we call the private `MenuBarClientCore` framework: `MBAssessmentModeConfiguration(allowedSystemItems:allowedBundleIdentifiers:)` plus `MBAssessmentModeAssertion activate/invalidate`. It's the allow-list used by exam mode, and Hidden Bar 1.11.1 uses it the same way.
- macOS shows only allow-listed apps, hides the rest, and reflows the bar. It works per bundle ID, and system items (0..<64) are always kept.
- The allow-list is all running bundle IDs minus the blocked sections (`MenuBarSection.allowedBundles`):
  - collapsed blocks hidden + alwaysHidden;
  - expanded blocks alwaysHidden;
  - showAll has no restriction.
- It's re-applied on every state change and every app launch. Separators are hidden (`ControlItems.usesSeparators = false`).
- macOS re-shows icons wherever it likes. `arrangeAroundChevron(for:)` fixes the order with Cmd-drags. It needs Accessibility, and these are the only drags on macOS 27.
  - On collapse, the chevron goes left of every shown icon (`MovePlanner.chevronLeftmostMove`).
  - On expand, revealed Hidden icons go left of the chevron, leftmost first (`MovePlanner.revealedItemMove`).
  - Result: `[hidden…] chevron [visible…]`.
- The call goes through an Objective-C target (`Sources/MenuBarClientShim`) so NSExceptions from a changed private API are caught. If the API is missing, we fall back to the legacy engine.

**Older macOS (legacy):**
```
[always-hidden items] |AH| [hidden items] |H| [visible items] [TopBar icon]
```
- Three `NSStatusItem`s. Collapsed sets H to length 10_000 to push everything left of it off-screen; AH stays short. Expanded sets AH long. showAll makes both short.
- `reconcileByDragging()` shows all, scans with AX, Cmd-drags one wrong-section icon (`MenuBarItemMover`), and rescans. Max 3 tries per app.

Both engines find icons with the Accessibility API (`kAXExtrasMenuBarAttribute` per app, in `MenuBarItemScanner`). On macOS 27 that's only used for the settings list and empty-area hit tests.

## Code layout (`Sources/TopBar/`)
| Folder | What |
|---|---|
| `App/` | `TopBarApp` (@main, accessory policy), `AppDelegate` (owns and wires services, settings window), `Log` (os.Logger) |
| `MenuBar/` | `ControlItems` (our 3 status items + right-click menu), `MenuBarItem` (model), `MenuBarItemScanner` (AX reads), `MovePlanner` (**pure** section/move logic), `MenuBarItemMover` (CGEvent drag), `MenuBarManager` (@Observable coordinator: reveal/collapse/rehide/reconcile), `MenuBarSection` |
| `Triggers/` | `RevealTriggers` (global NSEvent monitors: hover, empty-area click, scroll), `MenuBarGeometry` (**pure** hit tests + one screen helper) |
| `Settings/` | `SettingsStore` (@Observable, UserDefaults), `SettingsView` (SwiftUI form: per-app section picker, triggers, launch at login) |
| `System/` | `Permissions` (Accessibility), `LaunchAtLogin` (SMAppService), `NativeVisibility` (macOS 27 allow-list wrapper) |

`Sources/MenuBarClientShim/`: a tiny Objective-C target that dlopens `MenuBarClientCore` and wraps the calls in `@try/@catch`.

Tests (`Tests/TopBarTests/`) cover only the pure logic: `MovePlanner` (incl. chevron/revealed moves), `MenuBarGeometry`, `MenuBarSection.allowedBundles`.

## Conventions
- Services are small, single-purpose, `@MainActor`, and owned by `AppDelegate`. No singletons.
- Decision logic stays pure and unit-tested. AX, CGEvent and NSStatusItem code stays thin.
- AppKit callbacks (NSEvent monitors, notifications) hop to the actor with `MainActor.assumeIsolated`.
- Settings are keyed by **bundle ID**. All icons of one app move together. Apps with no saved section are never moved.
- Coordinates: AX and CGEvent use top-left origin; AppKit uses bottom-left. **X is the same in both**, so the code compares only x across them. `MenuBarItem.frame` is in AX space.
- Known shortcuts are marked `// shortcut:` in the code.

## Things to know
- **Accessibility resets on every rebuild** because ad-hoc signatures change. After `build-app.sh`: System Settings → Privacy & Security → Accessibility. Remove TopBar with "−", then re-add or re-enable it. No signing certificate is installed. `SIGN_IDENTITY="Apple Development: …" Scripts/build-app.sh` fixes this.
- **No App Sandbox / no Mac App Store**: synthesized events need it unsandboxed.
- **macOS 27 findings**:
  - `CGWindowListCopyWindowInfo` lists no per-item windows.
  - AX detection works.
  - Separator length is capped: a too-long item gets moved to `y = -38` and nothing hides.
  - The Cmd-drag move does work, but on macOS 27 it isn't needed.
  - `com.apple.MenuBarAgent` hosts system items (Wi-Fi, battery, clock...).
- **Private API risk**: `MenuBarClientCore` is undocumented. A macOS update can rename it. The shim then reports unavailable and the legacy engine kicks in, which won't actually hide on macOS 27. Check the logs for `native visibility: true` and `VisibilityRestrictionAssertion session activated`.
- Apps without a bundle ID can't be allow-listed, so they hide whenever a restriction is active.
- If the chevron disappears, check the `state … icon {{x, y}, …}` log line. `y = -38` means macOS hid it, so check it's running from `/Applications`. To recover when stuck: `pkill -x TopBar` (the restriction ends with the process).
- Auto-rehide doesn't check for open menus (see `shortcut:` in `MenuBarManager`).

## Roadmap (not built yet)
- M2: drag-and-drop layout editor (item images need Screen Recording); hide app menus when they overlap shown items.
- M3: separate bar below the notch (borderless `NSPanel` mirroring hidden items).
- M4: appearance: tint (solid/gradient), shadow, border, rounded/split shapes (overlay window at menu bar level).
