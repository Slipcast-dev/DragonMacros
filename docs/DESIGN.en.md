# Samurai Motion design

[Русский](DESIGN.md) · [English](DESIGN.en.md)

Application version: 3.1. The visual reference is the approved interactive
[Samurai Motion mockup](mockups/samurai-motion.html). The mockup specifies appearance;
the working application remains native AppKit, without HTML/WebView.

## Palette

| Element | Mockup color |
|---|---|
| Main surface | `#101112` |
| Sidebar | `#191A1B` |
| Primary text | `#F0ECE5` |
| Secondary text | `#91918E` |
| Vermilion accent | `#DF4938` |
| Dividers | `#303132` |

A warm red-brown fill marks the selected macro, with a thin red line along its left
edge. Primary action buttons are distinct from fields and quiet utility actions.

Other styles have their own appearance, rather than the same geometry with a slight
color shift:

| Style | Surfaces and header |
|---|---|
| Original white and red | White background, light sidebar, and crimson header |
| Black and red | Black surfaces, red accents, and crimson header |
| Samurai | Graphite surfaces, subdued header, and red disk on the right |
| Match system | Light or dark palette following macOS |

The list/editor structure is shared, while the header, background, selection, fields,
and typography follow the selected style. Settings explain the difference beside
the style selector.

## Layout and text

The macro list, shortcuts, and Add button are on the left. The editor is on the right:
name, shortcut recording, action type, app or URL, enabled state, and Test/Delete.
Load, Save, and Settings are in the header. The status bar shows pause state and macro
count. Counter text is centered using its actual measured size; an empty count is `0`.
The empty list offers actions to create the first macro and load a config, rather
than fictitious saved macros.

The Samurai product name and editor heading use an expressive serif face; fields,
labels, and buttons use the macOS system font. Russian and English UI share the same
composition. Controls remain native and support keyboard navigation.

## Background and motion

The red disk, thin orbit, and abstract lines reproduce the mockup's composition
without a samurai figure, crest, or old window emblem. The decorative layer does not
intercept clicks, cover editable controls, or trigger system actions.

Background motion, editor transitions, and button feedback use Core Animation/AppKit.
The artwork uses the HTML's local 390×610 area: a 260×260 sun at (90, 60), a 324×324
orbit at (58, 28), and three ink curves within (9, 256, 390, 240). Texture stays inside
the disk; ink paths do not stretch across the entire window. The orbit and dot rotate
in 40 seconds, the sun cycle takes 9 seconds, ink reveal takes 2.2 seconds, and particle
cycles take 11/14/17 seconds.

The app preference or macOS Reduce Motion disables movement. Decorative animation
stops while the window is not shown or the application is inactive, reducing background
resource use.

## App icon

A separate Japanese sun-and-ink icon was approved for version 0.5. Its source,
`Icon/source/japan-app-icon.png`, was created with OpenAI's built-in `image_gen`,
prepared with transparency, and processed by the project generator for the macOS
bundle. Provenance is recorded in [ARTWORK.en.md](ARTWORK.en.md) and
[NOTICE.en.md](../NOTICE.en.md). The menu bar icon intentionally keeps the previous
dragon silhouette and differs from the new app icon.

## Behavior

Motion does not substitute for executing a macro or change the JSON format. Global
shortcuts, the installed app catalog, conflict checks, and file dialogs use the
working application logic. Pending text is saved before changing macros, closing a
window, exporting, or quitting; storage errors are shown to the user.

## AppKit smoke check

```sh
./test-interface.sh
```

The check creates a controller with temporary macros, verifies field editability and
text bounds, pending input persistence, and minimum content sizes. It renders the
window offscreen to `.build/interface-tests/window.png` and creates
`theme-samurai.png`, `theme-original.png`, `theme-dark.png`, `theme-system.png`, and
`empty-state.png`. These images allow comparing themes and the empty list state.
The real user store and global shortcut registration are not used. Record the actual
result separately: the existence of a test is not proof that it passed.

## Fidelity checks

After integration, compare the working window with the mockup in five areas: palette,
layout, typography, control states, and artwork/motion. Also check resizing, Russian
and English UI, disabled animation, and macOS Reduce Motion. This document describes
the intended contract; it does not replace visual verification of the built app.

## 3.1 verification

The Settings window gained an Updates section: a background check toggle, a Check Now
button and a status line; the window is 716 pt tall. Downloading an update shows a separate
progress panel with Cancel. The UI check renders the Settings window and verifies that
controls fit and do not overlap.

## 1.0 verification

The design is unchanged in 1.0. README screenshots were re-rendered by the isolated AppKit
check; the Settings window gained a Links section for resetting allowed links and is now 560 pt tall.

## 0.5.1 fix verification

Five current AppKit snapshots were inspected for counter alignment, header differences,
layout, and contrast. Native layer checks verified animation keys, paths, durations,
and stop policies. The 17 storage/preferences checks, 3 ICNS tests, and expanded AppKit
check passed. Real-window motion playback remains unverified. See
[PROJECT_REVIEW.md](PROJECT_REVIEW.md), in Russian, for the engineering verification record.

## Historical 0.5 port verification

The HTML mockup was compared with offscreen rendering of real AppKit controls:

| Area | Result |
|---|---|
| Palette | Graphite, warm text, red-brown selection, and vermilion button transferred |
| Layout | Header, list, editor, and status retained; native macOS window frame added |
| Typography | Georgia headings; system labels, fields, and buttons; Russian text checked |
| Controls | Fields, shortcut recording, toggle, buttons, and list selection inspected in native rendering |
| Artwork and motion | Red disk, orbit, and Core Animation lines; system accessibility preference respected |

Intentional difference: app actions keep the functional installed `.app` catalog,
rather than the demo HTML's text path. Decorative outer-page text and framing are not
part of the product. The mockup uses CSS and the app uses Core Animation; paths and
durations were adapted for native UI in version 0.5. The 0.5.1 fix realigns local geometry
and key durations with the approved HTML; earlier comparison results remain historical.

The native smoke check uses a temporary store, verifies NSTextView input, persistence,
toggle state/action, and bounds at content sizes 1160×800 and 1000×760. The desktop
control service was unavailable, so a complete interactive mouse run and recording
of built-app motion were not confirmed. Offscreen images are not desktop-window recordings.
