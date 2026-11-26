# Dragon Macros 3.1

[Русский](#русский) · [English](#english)

## Русский

Нативные глобальные горячие клавиши для приложений и ссылок на macOS 11+.
Версия **3.1 / build 8**. Обновляет 1.0.

### Что нового

- **Автоматическая проверка обновлений.** При запуске и раз в сутки приложение в фоне
  проверяет последний релиз на GitHub и сообщает о новой версии. Версию можно пропустить,
  проверку — выключить.
- **Установка в пару кликов.** «Загрузить и установить» скачивает установщик `.pkg` из
  релиза, сверяет его SHA256 с `SHA256SUMS.txt` того же релиза и открывает «Установщик»
  macOS. Ход загрузки виден, загрузку можно отменить. Макросы и настройки сохраняются.
- **Раздел «Обновления» в настройках:** переключатель фоновой проверки, кнопка
  «Проверить сейчас», текущая версия и время последней проверки. Пункт
  «Проверить обновления…» есть в меню приложения и в строке меню.

### Установка и обновление

- **DMG:** открыть и перетащить приложение в «Программы».
- **PKG:** запустить установщик; целевая папка — `/Applications`.
- Оба пакета универсальные: Intel + Apple Silicon. Контрольные суммы — `SHA256SUMS.txt`.
- С 1.0 обновитесь вручную, закрыв старую версию через **⌘Q**. Следующие версии 3.1
  найдёт и установит сама.

Приложение подписано **ad-hoc**, без нотаризации. Проверяйте источник и SHA256;
при предупреждении Gatekeeper откройте доверенную сборку через системные настройки
безопасности. Не отключайте Gatekeeper целиком.

## English

Native global hotkeys for applications and links on macOS 11+.
Version **3.1 / build 8**. Updates 1.0.

### What's new

- **Automatic update checks.** At launch and once a day the app checks the latest GitHub
  release in the background and tells you about a new version. You can skip a version or
  turn checking off.
- **Install in a couple of clicks.** “Download and Install” fetches the `.pkg` installer
  from the release, verifies its SHA256 against `SHA256SUMS.txt` from the same release and
  opens macOS Installer. Progress is shown and the download can be cancelled. Macros and
  settings are kept.
- **Updates section in Settings:** background check toggle, Check Now button, current
  version and last check time. “Check for Updates…” is also in the app menu and the menu bar.

### Install and update

- **DMG:** open it and drag the app to Applications.
- **PKG:** run the installer; it installs to `/Applications`.
- Both packages are universal: Intel + Apple Silicon. Checksums are in `SHA256SUMS.txt`.
- From 1.0, update manually after quitting the old version with **⌘Q**. From then on,
  3.1 finds and installs new versions itself.

The app is **ad-hoc signed** and not notarized. Verify the source and SHA256; if Gatekeeper
warns, open the trusted build through the system security settings. Do not disable
Gatekeeper entirely.
