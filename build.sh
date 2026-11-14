#!/bin/sh
# Сборка DragonMacros.app без Xcode (достаточно Command Line Tools).
# По умолчанию — архитектура этого Mac; "./build.sh universal" — Intel + Apple Silicon (дольше).
# Аргументы можно сочетать: "install" копирует приложение в ~/Applications, "dmg" делает dist/DragonMacros-<версия>-macOS.dmg,
# "pkg" делает установочный пакет dist/DragonMacros-<версия>-macOS.pkg (установка в /Applications).
# "test-app" обновляет DragonMacros-Test.app в корне проекта без установки в Applications.
# Пример: "./build.sh universal test-app dmg pkg".
set -e
cd "$(dirname "$0")"
VERSION=0.5.1
APP=.build/DragonMacros.app
rm -rf "$APP"
mkdir -p .build "$APP/Contents/MacOS" "$APP/Contents/Resources"
# Кэш модулей хранится рядом со сборкой: домашний каталог может быть недоступен в CI/песочнице.
MODULE_CACHE="$(pwd)/.build/ModuleCache"
mkdir -p "$MODULE_CACHE"
case " $* " in *" universal "*) UNIVERSAL=1;; esac
case " $* " in *" install "*) INSTALL=1;; esac
case " $* " in *" dmg "*) DMG=1;; esac
case " $* " in *" pkg "*) PKG=1;; esac
case " $* " in *" test-app "*) TEST_APP=1;; esac
if [ -n "$UNIVERSAL" ]; then
  for arch in x86_64 arm64; do
    swiftc -O -whole-module-optimization -module-cache-path "$MODULE_CACHE" -target "$arch-apple-macos11" Sources/*.swift -o .build/dragonmacros-$arch
  done
  lipo -create .build/dragonmacros-x86_64 .build/dragonmacros-arm64 -output "$APP/Contents/MacOS/DragonMacros"
else
  swiftc -Onone -module-cache-path "$MODULE_CACHE" Sources/*.swift -o "$APP/Contents/MacOS/DragonMacros"
fi
# Иконка приложения из японского солнца; значок строки меню сохраняет силуэт дракона.
python3 -I Icon/make_icons.py >/dev/null
cp .build/icons/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp ".build/icons/StatusIcon@2x.png" "$APP/Contents/Resources/StatusIcon@2x.png"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>DragonMacros</string>
  <key>CFBundleDisplayName</key><string>Dragon Macros</string>
  <key>CFBundleIdentifier</key><string>dev.slipcast.dragonmacros</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleExecutable</key><string>DragonMacros</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.5.1</string>
  <key>CFBundleVersion</key><string>6</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Hardened runtime + ad-hoc подпись (без нотаризации)
codesign --force --options runtime --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "Готово: $(pwd)/$APP"
if [ -n "$TEST_APP" ]; then
  # Сначала проверяем готовую копию; старый тестовый пакет заменяется только после успеха.
  # Имя пакета отличается, но bundle identifier и пользовательское хранилище общие.
  TEST_STAGE=.build/test-app/DragonMacros-Test.app
  rm -rf "$TEST_STAGE"
  mkdir -p .build/test-app
  ditto "$APP" "$TEST_STAGE"
  codesign --verify --deep --strict "$TEST_STAGE"
  rm -rf DragonMacros-Test.app
  mv "$TEST_STAGE" DragonMacros-Test.app
  echo "Тестовое приложение: $(pwd)/DragonMacros-Test.app"
fi
if [ -n "$INSTALL" ]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/DragonMacros.app"
  cp -R "$APP" "$HOME/Applications/DragonMacros.app"
  echo "Установлено: $HOME/Applications/DragonMacros.app"
fi
if [ -n "$DMG" ]; then
  mkdir -p dist .build/dmg
  rm -rf .build/dmg/* && cp -R "$APP" .build/dmg/ && ln -s /Applications .build/dmg/Applications
  OUT=dist/DragonMacros-$VERSION-macOS.dmg
  rm -f "$OUT"
  hdiutil create -volname "Dragon Macros" -srcfolder .build/dmg -ov -format UDZO "$OUT"
  echo "Установщик: $(pwd)/$OUT"
fi
if [ -n "$PKG" ]; then
  mkdir -p dist .build/pkgroot
  rm -rf .build/pkgroot/* && cp -R "$APP" .build/pkgroot/
  OUT=dist/DragonMacros-$VERSION-macOS.pkg
  rm -f "$OUT"
  pkgbuild --quiet --root .build/pkgroot --identifier dev.slipcast.dragonmacros.pkg --version "$VERSION" --install-location /Applications "$OUT"
  echo "Установщик: $(pwd)/$OUT"
fi
if [ -n "$DMG$PKG" ]; then
  (cd dist && shasum -a 256 DragonMacros-$VERSION-macOS.* > SHA256SUMS.txt)
fi
