# Dragon Macros 1.0

[Русский](#русский) · [English](#english)

## Русский

Нативные глобальные горячие клавиши для приложений и ссылок на macOS 11+.
Первая стабильная версия: **1.0 / build 7**. Обновляет 0.5.1.

### Что изменилось

- **Надёжность сочетаний.** Запись сочетания больше не оставляет все макросы выключенными:
  она завершается при потере фокуса, закрытии окна, смене языка или стиля и переходе
  в другое приложение. Сочетания, отклонённые macOS, регистрируются повторно при возврате
  в приложение; конфликт показывается только у повторяющегося макроса.
- **Безопасные ссылки.** Сразу открываются только сайты и почта, локальные файлы и скрипты
  запрещены, остальные схемы (`smb:`, `ssh:`, схемы приложений) — после подтверждения.
  «Всегда открывать» действует для одного узла и сбрасывается в настройках.
- **Прозрачный импорт.** Перед загрузкой конфига показывается список приложений, ссылок
  и сочетаний.
- **Автозапуск** через объекты входа macOS 13+ (на 11–12 — LaunchAgent); устаревший агент
  после переноса приложения больше не считается включённым.
- Пауза сохраняется между запусками, повторный запуск показывает окно работающей копии,
  добавлено «Повторить» (⇧⌘Z), большой повреждённый файл данных не блокирует сохранение.
- Быстрее переключение макросов, меньше работы фоновой анимации, оптимизированная сборка.

### Установка и обновление

- **DMG:** открыть и перетащить приложение в «Программы».
- **PKG:** запустить установщик; целевая папка — `/Applications`.
- Оба пакета универсальные: Intel + Apple Silicon. Контрольные суммы — `SHA256SUMS.txt`.
- Перед обновлением завершите старый экземпляр через **⌘Q**. Макросы и настройки сохраняются.
- Если автозапуск был включён в 0.5.1, выключите и снова включите его в настройках,
  чтобы перейти на объекты входа macOS.

Приложение подписано **ad-hoc**, без нотаризации. Проверяйте источник и SHA256;
при предупреждении Gatekeeper откройте доверенную сборку через системные настройки
безопасности. Не отключайте Gatekeeper целиком.

## English

Native global hotkeys for applications and links on macOS 11+.
First stable version: **1.0 / build 7**. Updates 0.5.1.

### What changed

- **Reliable hotkeys.** Recording a shortcut no longer leaves every macro disabled: it
  stops when the window loses focus or closes, the language or style changes, or another
  app becomes active. Hotkeys refused by macOS are retried when you return to the app;
  only the duplicate macro reports a conflict.
- **Safe links.** Only websites and mail open directly, local files and scripts are blocked,
  other schemes (`smb:`, `ssh:`, app schemes) open after confirmation. “Always open”
  applies to one host and can be reset in Settings.
- **Transparent import.** Loading a config first lists its applications, links and hotkeys.
- **Launch at login** uses macOS Login Items on 13+ (a LaunchAgent on 11–12); a stale
  agent left after moving the app no longer counts as enabled.
- Pause survives restarts, launching again shows the running copy, Redo (⇧⌘Z) was added,
  and a large damaged data file no longer blocks saving.
- Faster macro switching, lighter background animation, and an optimized build.

### Install and update

- **DMG:** open it and drag the app to Applications.
- **PKG:** run the installer; it installs to `/Applications`.
- Both packages are universal: Intel + Apple Silicon. Checksums are in `SHA256SUMS.txt`.
- Quit the old instance with **⌘Q** before updating. Macros and settings are kept.
- If launch at login was enabled in 0.5.1, turn it off and on again in Settings to switch
  to macOS Login Items.

The app is **ad-hoc signed** and not notarized. Verify the source and SHA256; if Gatekeeper
warns, open the trusted build through the system security settings. Do not disable
Gatekeeper entirely.
