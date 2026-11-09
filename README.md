# Clean Desk

A menu bar utility for macOS that hides everything on the desktop (files, folders, mounted disks and
drives) so only the wallpaper shows, and brings it all back with one click or a keyboard shortcut.

## Features

- **Hide / show desktop icons** from the menu bar icon or a global shortcut (⌃⌥⌘D by default, changeable in Settings).
  Uses Finder's own `CreateDesktop` setting and relaunches Finder, so nothing is moved or touched on disk.
- **Custom wallpaper while hidden.** Pick any image; it is applied to every display while the desktop is hidden
  and the previous wallpaper is restored when icons come back (per display, remembered across relaunches).
- **Launch at login** (SMAppService).
- **Show in Dock** toggle; the app is menu-bar-only by default.
- **Sparkle updates** from `https://beardfm.app/clean-desk/appcast.xml`.

Quitting the app shows the desktop again, so nobody is left with hidden files and no icon to recover them.
Logging out, restarting or shutting down leaves the desktop state alone.

## Project layout

- `Clean Desk/CleanDeskApp.swift` — AppKit entry point and app delegate (hotkey, Dock policy, main menu).
- `Clean Desk/Services/DesktopController.swift` — the Finder `CreateDesktop` switch and Finder relaunch.
- `Clean Desk/Services/WallpaperController.swift` — swaps and restores wallpapers per display.
- `Clean Desk/Services/Preferences.swift` — settings in UserDefaults.
- `Clean Desk/Menu/StatusItemController.swift` — the menu bar item.
- `Clean Desk/Settings/` — the Settings window (SwiftUI form in an AppKit window).
- `Config/Info.plist` — Sparkle keys only; everything else is generated from build settings.
- `Tools/release.sh` — Release build, Developer ID signing, notarization, DMG, and (with `--upload`) the
  beardfm.app download + appcast entry. `Tools/update-appcast.py` maintains the appcast.
- `Tools/make-icon.swift` — renders the app icon PNGs into the asset catalog.

## Building

Open `Clean Desk.xcodeproj` in Xcode and run, or:

```
xcodebuild -project "Clean Desk.xcodeproj" -scheme "Clean Desk" -configuration Debug -destination 'platform=macOS' build
```

Dependencies (Swift Package Manager): [Sparkle](https://github.com/sparkle-project/Sparkle) 2.x and
[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) 2.x.

The direct-download target is unsandboxed (hardened runtime on) because writing Finder's preferences and
relaunching Finder are not possible from the sandbox.

**Mac App Store target** ("Clean Desk App Store", `APPSTORE` compilation condition) is sandboxed and has no
Sparkle. Since it can't touch Finder, it hides the desktop with `DesktopCover`: a window per display just
above the icon layer and below every other window, drawing the wallpaper or the custom image. The custom
wallpaper is kept as a security-scoped bookmark. Its listing lives in `AppStore/metadata.md`, screenshots in
`AppStore/screenshots/` (rendered by `Tools/make-art.swift`), and `Tools/archive-appstore.sh` plus
`Tools/appstore.mjs` archive, upload, fill in the listing and submit.

Both builds answer `cleandesk://hide`, `cleandesk://show`, `cleandesk://toggle` and `cleandesk://settings`.

## Releasing

```
Tools/release.sh --notarize --upload
```

Signs updates with the EdDSA key in the login keychain (account `cleandesk`, public half in `Config/Info.plist`),
copies the DMG into `~/Movies/Apps/beardfm.app/site/static/downloads/`, and adds the release to
`site/static/clean-desk/appcast.xml`. Put release notes in `release-notes/<version>.html` first if wanted,
then commit and push the beardfm.app site to publish.

## License

MIT. See [LICENSE](LICENSE).
