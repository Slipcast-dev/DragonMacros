# Changelog

[Русский](CHANGELOG.md) · [English](CHANGELOG.en.md)

## 1.0 — 2026-11-26

- First stable release, build 7.
- Hotkey recording now stops when the window loses focus or closes, the language or style changes, or another app becomes active. Previously all macros stopped firing.
- Links: only `http`, `https` and `mailto` open directly; `file`, `javascript`, `data` and `vbscript` are blocked; other schemes (`smb`, `ssh`, app schemes) open after confirmation, with an “Always open” option per host (not offered for `ssh` or System Settings links); allowed links can be reset in Settings. Schemes without `//` (`tel:`, `javascript:`) are no longer turned into `https://…`.
- Loading a config first shows the applications, links and hotkeys it contains.
- Hotkeys refused by macOS are retried when the app becomes active; only the duplicate macro reports a conflict, not the working one.
- A damaged data file larger than 2 MB is backed up and no longer blocks saving.
- Pause survives restarts. Launching the app again shows the window of the running copy. Added Redo (⇧⌘Z).
- Launch at login uses system Login Items (SMAppService) on macOS 13+ and a LaunchAgent on macOS 11–12; a LaunchAgent pointing to a moved app counts as disabled.
- Faster: the application menu and icons are cached, list rows are reused, the Samurai backdrop pauses while the window is fully covered; `./build.sh` always builds with `-O`.
- Build: the version is defined once in `build.sh`; optional Developer ID signing and notarization via `SIGN_IDENTITY`, `PKG_SIGN_IDENTITY`, `NOTARY_PROFILE`.
- Repository cleanup: unused mockups and 0.5 screenshots removed, interface screenshots re-rendered without a version in their names, release notes in [docs/RELEASE-v1.0.md](docs/RELEASE-v1.0.md).

## 0.5.1 — 2026-11-14

- Centered the macro count and index with dedicated drawing; an empty list displays `0` instead of `00`.
- Fixed Samurai Motion composition using the local 390×610 artwork area, curves from the approved HTML, and texture contained within the sun.
- Added the orbit dot and 40-second rotation, 9-second sun cycle, 2.2-second ink reveal, and particle cycles of 11/14/17 seconds.
- Restored distinct white/red and black/red palettes and crimson headers. System follows macOS; Samurai keeps a subdued graphite header.
- Added working Add macro and Load config actions to the empty state, without inserting fictitious user data.
- Clarified the selected style and macOS Reduce Motion behavior in settings.
- App and installer version: 0.5.1, build 6. Added snapshots for the four styles and empty state.

## 0.5 — 2026-11-14

- Added the approved Japanese sun and ink-stroke app icon, created with OpenAI `image_gen` and prepared with transparency.
- Brought Samurai Motion styling to native AppKit: graphite surfaces, vermilion accents, and a redesigned macro list and editor.
- Replaced old window emblems and the samurai figure with an abstract sun and ink composition. Kept the menu bar icon.
- Added native background, hover, and transition motion, an animation preference, and support for macOS Reduce Motion.
- Selected Samurai on the first 0.5 launch while retaining macro data, localization, import/export, and access to the other styles.
- Added the `test-app` build flag to refresh `DragonMacros-Test.app` in the project root after signature verification; ignored local `.app` bundles in Git.
- Updated packages to 0.5 / build 5. CI also checks the test copy's signature and installer checksums.
- Added `./test-interface.sh` for isolated AppKit field, persistence, layout, and offscreen rendering checks.

## 0.4 — 2026-11-14

- Made persistence atomic and transactional: failures are shown while previous data and hotkey registrations remain intact.
- Added unique damaged-JSON backups and write blocking when backup creation fails.
- Validated config application/version, shortcuts, 500-macro and 2 MB limits; removed silent truncation.
- Debounced text saves by 0.4 seconds and flushed pending changes before selection, closing, and quitting.
- Avoided re-registering unchanged hotkeys and checked Carbon and launch-at-login errors.
- Split code into modules and switched file dialogs to `allowedContentTypes`.
- Removed dependence on `iconutil` packaging and added a project-local Swift module cache.
- Added storage and ICNS regression tests to CI.

## 0.3

- Added JSON Load/Save controls (⌘O / ⌘S) with replace/append import, validation, size limits, and fresh imported identifiers.
- Refined macOS-style header controls and fixed Settings.
- Added a larger dragon emblem and a new Russian tagline on the hero and social preview.
- Changed the menu bar icon from “M” to a dragon in a circle and refined theme palettes.
- Added PKG packaging alongside DMG and `SHA256SUMS.txt` for installers.

## 0.2

- Added global shortcuts for apps and links.
- Added Russian/English UI, three styles, Dock/menu bar settings, pause, and launch at login through LaunchAgent.
- Blocked selected unsafe URL schemes and used private permissions for saved data.

## Public repository preparation

- Added universal-build CI, signature checks, and Dependabot for GitHub Actions.
- Added contribution and community guidelines, issue/PR templates, and CODEOWNERS.
- Prepared project artwork and documented security boundaries.
