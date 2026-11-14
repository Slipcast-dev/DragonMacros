# Dragon Macros 0.5.1 · Samurai Motion

[Русский](#русский) · [English](#english)

## Русский

Нативные глобальные горячие клавиши для приложений и ссылок на macOS 11+.
Этот релиз обновляет опубликованную версию 0.3 до **0.5.1 / build 6**.

### Что изменилось

- Новый интерфейс Samurai Motion и одобренная японская иконка: солнце и тушевый росчерк.
- Четыре различимых стиля: Самурай, бело-красный, чёрно-красный и системный; RU/EN сохраняются.
- Исправлены положение счётчиков, композиция фона и кривые, появление туши, вращение орбиты и отклик кнопок. Анимация учитывает Reduce Motion и настройку приложения.
- Пустой список предлагает реальные действия создания и загрузки конфигурации.
- Надёжное транзакционное сохранение, сообщения об ошибках, уникальные резервные копии повреждённого JSON и блокировка записи при неудачном резервировании.
- Полная проверка импорта без молчаливого обрезания: до 500 макросов и 2 МБ.
- Обновлены обработка ошибок Carbon/автозапуска, модульная структура, тесты и сборка иконок.

### Установка и обновление

- **DMG:** открыть и перетащить приложение в «Программы».
- **PKG:** запустить установщик; целевая папка — `/Applications`.
- Оба пакета универсальные: Intel + Apple Silicon. Контрольные суммы — `SHA256SUMS.txt`.
- Перед обновлением полностью завершите старый экземпляр через **⌘Q**. Существующие макросы и настройки сохраняются в прежних местах.
- Тестовая сборка использует те же макросы и настройки, что и обычная; отдельного профиля нет.

Приложение подписано **ad-hoc**, без нотариализации. Проверяйте источник и SHA256;
при предупреждении Gatekeeper используйте системные настройки безопасности для
доверенной сборки. Не отключайте Gatekeeper целиком.

### Проверки и ограничения

Локально пройдены 17 проверок хранения/настроек, 3 теста ICNS и расширенная проверка
AppKit: ввод, сохранение текста, счётчики, темы, пустое состояние и контракты Core Animation.
Проверены универсальные архитектуры, подпись, структура пакетов, DMG и SHA256.
Offscreen-отрисовка и контракты анимации не подтверждают воспроизведение в живом окне;
интерактивная запись движения была недоступна. Это не утверждение о статусе GitHub CI.

## English

Native global hotkeys for apps and links on macOS 11+.
This release updates the published 0.3 version to **0.5.1 / build 6**.

### Changes

- New Samurai Motion interface and the approved Japanese sun-and-ink app icon.
- Four distinct styles: Samurai, original white/red, black/red, and system; Russian/English UI remains available.
- Fixed counter alignment, artwork composition and curves, ink reveal, orbit rotation, and button feedback. Motion respects Reduce Motion and the app preference.
- Added working create/load actions to the empty list.
- Added transactional persistence, visible write errors, unique damaged-JSON backups, and write blocking after backup failure.
- Validated complete imports without silent truncation: up to 500 macros and 2 MB.
- Improved Carbon/launch-at-login error handling, module structure, tests, and icon packaging.

### Install and update

- **DMG:** open and drag the app to Applications.
- **PKG:** run the installer; it targets `/Applications`.
- Both packages are universal: Intel + Apple Silicon. Checksums are in `SHA256SUMS.txt`.
- Fully quit the old instance with **⌘Q** before updating. Existing macros and preferences keep their original locations.
- The test copy shares the regular app's macros and preferences; it has no separate data profile.

The app is **ad-hoc signed and not notarized**. Verify the source and SHA256 checksums.
For a Gatekeeper warning, use system security settings only for a trusted build;
do not disable Gatekeeper globally.

### Checks and limitations

Local checks passed: 17 storage/preferences checks, 3 ICNS tests, and expanded AppKit
checks for input, pending edits, counters, styles, empty state, and Core Animation contracts.
Universal architectures, signature, package structure, DMG integrity, and SHA256 were verified.
Offscreen rendering and animation contracts do not establish real-window playback;
interactive motion recording was unavailable. This is not a claim about GitHub CI status.
