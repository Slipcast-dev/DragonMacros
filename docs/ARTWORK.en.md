# Project artwork

[Русский](ARTWORK.md) · [English](ARTWORK.en.md)

Artwork sources were created with OpenAI's built-in `image_gen` on 2026-10-30 and
2026-11-14. External images were not used.

## Prompts

Hero: original polished wide 2:1 GitHub banner for Dragon Macros, near-black
charcoal and crimson, title "Dragon Macros", subtitle "Global hotkeys for macOS";
original sculptural dragon formed from red ribbons and glowing keyboard keys;
minimal editorial tech aesthetic, no vendor logos, no stock graphics, no watermark.

Logo: original square black geometric dragon silhouette on pure white,
flowing curled angular tail suggesting D and keyboard command key;
flat bold silhouette, no text, no gradients, no existing brand imitation.

## Samurai Motion icon, version 0.5

`Icon/source/japan-app-icon.png` was created on 2026-11-14 with OpenAI's built-in
`image_gen`: a Japanese red sun and ink stroke, with a transparent background.
The user approved this source for the new app icon. It is a generative source;
the project does not claim that the illustration was made by hand.

`Icon/make_icons.py` prepares the macOS icon sizes from this source and packages
them into `AppIcon.icns`. The old dragon is no longer the source of the app icon.
The menu bar icon continues to use the prepared `Icon/source/status-template.png`.

## Files

- `docs/images/hero.png`: the original AI-generated banner.
- `docs/images/social-preview.png`: a 1280×640 variant for GitHub Social preview.
- In 0.3, “Global hotkeys for macOS” on those two images was replaced with the Russian tagline “Доли секунды решают всё. Макрос решает за них.” by `Icon/make_hero.py`, using `Icon/source/hero-original.png` and `social-original.png`.
- `docs/images/features.svg`, `privacy.svg`, `build.svg`: text-based informational SVG banners.
- `Icon/source/japan-app-icon.png`: the approved AI-generated source for the version 0.5 icon.
- `Icon/source/dragon-logo-original.png`: the source of the previous logo and menu bar icon.
- Other `Icon/source/` images: derivatives from `Icon/prepare_logo.py`; in 0.3 these included a large 1024×1024 emblem on a cream background and a dragon-in-a-circle menu bar icon.

Build the current app and menu bar icons with `python3 -I Icon/make_icons.py`
(part of the ordinary build; no third-party packages required).
Prepare archived logo derivatives with `python3 Icon/prepare_logo.py` (requires Pillow).
`Icon/make_hero.py` adds the tagline to the hero and social preview.
`Icon/make_banner.py` creates the alternative `banner.png` from the newer emblem.

## Bilingual repository banner

`images/hero-samurai.png` was created with OpenAI's built-in `image_gen` on 2026-11-14.
The reference was the approved `Icon/source/japan-app-icon.png`. Working prompt:
professional GitHub README banner, aspect ratio 3:1, graphite #101112,
ivory serif title “Dragon Macros”, exact subtitles “Горячие клавиши для macOS”
and “Hotkeys for macOS”, “Intel · Apple Silicon”; approved ivory/red/black icon
on the right, restrained sumi-e stroke and muted brass detail; no static download
or star counts, no fake UI, no samurai character, no new logo.

Stars and downloads appear as separate dynamic Shields.io badges, not as numbers
baked into the image. Downloads count release asset downloads, not unique users.
The application source contains no telemetry.
