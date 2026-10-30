# Графика проекта

Генерация: встроенный `image_gen`, 2026-10-30. Внешние изображения не использовались.

## Промпты

Hero: original polished wide 2:1 GitHub banner for Dragon Macros, near-black
charcoal and crimson, title "Dragon Macros", subtitle "Global hotkeys for macOS";
original sculptural dragon formed from red ribbons and glowing keyboard keys;
minimal editorial tech aesthetic, no vendor logos, no stock graphics, no watermark.

Logo: original square black geometric dragon silhouette on pure white,
flowing curled angular tail suggesting D and keyboard command key;
flat bold silhouette, no text, no gradients, no existing brand imitation.

## Файлы

- `docs/images/hero.png`: основной AI-баннер.
- `docs/images/social-preview.png`: вариант 1280×640 для GitHub Social preview.
- `docs/images/features.svg`, `privacy.svg`, `build.svg`: текстовые информационные баннеры SVG.
- `Icon/source/dragon-logo-original.png`: новый источник логотипа.
- Остальные изображения `Icon/source/`: производные `Icon/prepare_logo.py`.

Повторная подготовка иконок: `python3 Icon/prepare_logo.py` (нужен Pillow).
`Icon/make_banner.py` создаёт альтернативный баннер `banner.png` из новой эмблемы.
