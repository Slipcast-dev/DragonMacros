# Графика проекта

[Русский](ARTWORK.md) · [English](ARTWORK.en.md)

Источники графики созданы встроенным OpenAI `image_gen` 2026-10-30 и 2026-11-14.
Внешние изображения не использовались.

## Промпты

Hero: original polished wide 2:1 GitHub banner for Dragon Macros, near-black
charcoal and crimson, title "Dragon Macros", subtitle "Global hotkeys for macOS";
original sculptural dragon formed from red ribbons and glowing keyboard keys;
minimal editorial tech aesthetic, no vendor logos, no stock graphics, no watermark.

Logo: original square black geometric dragon silhouette on pure white,
flowing curled angular tail suggesting D and keyboard command key;
flat bold silhouette, no text, no gradients, no existing brand imitation.

## Иконка Samurai Motion, версия 0.5

`Icon/source/japan-app-icon.png` создан 2026-11-14 встроенным OpenAI `image_gen`:
японское красное солнце и тушевый росчерк, прозрачный фон. Пользователь одобрил
этот источник для новой иконки приложения. Это генеративный исходник; проект
не заявляет, что иллюстрация создана вручную.

`Icon/make_icons.py` подготавливает из этого источника размеры иконки macOS и
упаковывает их в `AppIcon.icns`; старый дракон больше не является источником
иконки приложения. Значок строки меню продолжает использовать подготовленный
`Icon/source/status-template.png`.

## Файлы

- `docs/images/hero.png`: основной AI-баннер.
- `docs/images/social-preview.png`: вариант 1280×640 для GitHub Social preview.
- В 0.3 подпись «Global hotkeys for macOS» на этих двух картинках заменена слоганом «Доли секунды решают всё. Макрос решает за них.» скриптом `Icon/make_hero.py` из исходников `Icon/source/hero-original.png` и `social-original.png`.
- `docs/images/features.svg`, `privacy.svg`, `build.svg`: текстовые информационные баннеры SVG.
- `Icon/source/japan-app-icon.png`: одобренный AI-источник иконки версии 0.5.
- `Icon/source/dragon-logo-original.png`: источник прежнего логотипа и значка строки меню.
- Остальные изображения `Icon/source/`: производные `Icon/prepare_logo.py` (в 0.3: крупная эмблема 1024×1024 на кремовом фоне, значок строки меню — дракон в кольце).

Сборка актуальной иконки приложения и значка строки меню: `python3 -I Icon/make_icons.py`
(входит в обычную сборку, сторонних пакетов не требует).
Подготовка архивных производных логотипа: `python3 Icon/prepare_logo.py` (нужен Pillow).
`Icon/make_hero.py` накладывает слоган на hero и social-preview. `Icon/make_banner.py` создаёт альтернативный баннер `banner.png` из новой эмблемы.

## Двуязычный баннер репозитория

`images/hero-samurai.png` создан встроенным OpenAI `image_gen` 2026-11-14.
Референс — утверждённая `Icon/source/japan-app-icon.png`. Рабочий промпт:
профессиональный GitHub README banner, aspect ratio 3:1, graphite #101112,
ivory serif title “Dragon Macros”, exact subtitles “Горячие клавиши для macOS”
and “Hotkeys for macOS”, “Intel · Apple Silicon”; approved ivory/red/black icon
on the right, restrained sumi-e stroke and muted brass detail; no static download
or star counts, no fake UI, no samurai character, no new logo.

Число звёзд и загрузок отображается отдельными динамическими Shields.io-значками,
а не вписано в изображение. Число загрузок относится к файлам релизов и не измеряет
уникальных пользователей. Исходники приложения не содержат телеметрии.
