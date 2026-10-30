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
- В 0.3 подпись «Global hotkeys for macOS» на этих двух картинках заменена слоганом «Доли секунды решают всё. Макрос решает за них.» скриптом `Icon/make_hero.py` из исходников `Icon/source/hero-original.png` и `social-original.png`.
- `docs/images/features.svg`, `privacy.svg`, `build.svg`: текстовые информационные баннеры SVG.
- `Icon/source/dragon-logo-original.png`: новый источник логотипа.
- Остальные изображения `Icon/source/`: производные `Icon/prepare_logo.py` (в 0.3: крупная эмблема 1024×1024 на кремовом фоне, значок строки меню — дракон в кольце).

Повторная подготовка иконок: `python3 Icon/prepare_logo.py` (нужен Pillow).
`Icon/make_hero.py` накладывает слоган на hero и social-preview. `Icon/make_banner.py` создаёт альтернативный баннер `banner.png` из новой эмблемы.
