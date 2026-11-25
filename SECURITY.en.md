# Security policy

[Русский](SECURITY.md) · [English](SECURITY.en.md)

## Application behavior

- Registers global shortcuts through Carbon `RegisterEventHotKey` to open `.app` bundles and links. It does not record a global input stream and needs neither Input Monitoring nor Accessibility permission.
- Does not make network requests or send data. Selected links are passed to system URL handlers, including the default browser.
- Blocks the `file:`, `javascript:`, `data:`, and `vbscript:` URL schemes; app actions require a `.app` directory.
- Configuration exchange uses ordinary JSON files chosen by the user. Import only trusted configurations: they may refer to any app or link. Limits are 2 MB and 500 macros, including the total after appending.
- Stores macros at `~/Library/Application Support/DragonMacros/macros.json` with mode 0600 in a directory with mode 0700. Preferences use `UserDefaults`. Launch at login creates `~/Library/LaunchAgents/dev.slipcast.dragonmacros.plist` only when enabled by the user.
- `DragonMacros-Test.app` uses the regular user preferences and macros; it does not create a separate profile or copy of user data.
- The app is ad-hoc signed with hardened runtime and **not notarized**. Check installer checksums against `SHA256SUMS.txt` from the release or build from source.

## Reporting a vulnerability

Do not publish sensitive details in public. Use [private vulnerability reporting](https://github.com/Slipcast-dev/DragonMacros/security/advisories/new)
if GitHub offers it. Otherwise use a contact voluntarily published on the
[owner's profile](https://github.com/Slipcast-dev). Include the app version, macOS
version, reproduction steps, and impact. No response time is guaranteed.

## Supported versions

Fixes target the current version, 1.0. Older versions are not maintained separately.

## Protection boundaries

The app does not use App Sandbox. Only `http`, `https` and `mailto` open directly;
`file`, `javascript`, `data` and `vbscript` are blocked, and other schemes need confirmation.
“Always open” applies to a single scheme+host pair and can be reset in Settings; it is not
offered for `ssh` or System Settings links. A confirmed link is handed to a system handler
whose safety the app cannot guarantee. A `.app` extension does not establish trust in a bundle.
File permissions are not encryption and do not protect against other processes
running as the same user. Write failures are reported; failed backup creation for a
damaged data file blocks subsequent writes. Engineering checks and limitations are
recorded in [PROJECT_REVIEW.md](docs/PROJECT_REVIEW.md) (Russian).

## Repository contents

Keep passwords, tokens, signing keys, certificates (`.p12`, `.pem`, `.mobileprovision`),
and personal data out of the repository. `.gitignore` and `.githooks/pre-commit` help
block these files and suspicious added lines; they do not replace GitHub-side controls.
Enable the local hook after cloning:

```sh
git config core.hooksPath .githooks
```
