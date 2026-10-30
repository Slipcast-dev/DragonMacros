#!/bin/sh
# Сборка DragonMacros.app без Xcode (достаточно Command Line Tools).
# По умолчанию — архитектура этого Mac; "./build.sh universal" — Intel + Apple Silicon (дольше).
# Аргументы можно сочетать: "install" копирует приложение в ~/Applications, "dmg" делает dist/DragonMacros-<версия>-macOS.dmg.
# Пример: "./build.sh universal install dmg".
set -e
cd "$(dirname "$0")"
APP=.build/DragonMacros.app
rm -rf "$APP"
mkdir -p .build "$APP/Contents/MacOS" "$APP/Contents/Resources"
case " $* " in *" universal "*) UNIVERSAL=1;; esac
case " $* " in *" install "*) INSTALL=1;; esac
case " $* " in *" dmg "*) DMG=1;; esac
if [ -n "$UNIVERSAL" ]; then
  for arch in x86_64 arm64; do
    swiftc -O -target $arch-apple-macos11 Sources/main.swift -o .build/dragonmacros-$arch
  done
  lipo -create .build/dragonmacros-x86_64 .build/dragonmacros-arm64 -output "$APP/Contents/MacOS/DragonMacros"
else
  swiftc -Onone Sources/main.swift -o "$APP/Contents/MacOS/DragonMacros"
fi
# Иконки (приложение и строка меню) из эмблемы дракона
python3 -I Icon/make_icons.py >/dev/null
cp .build/icons/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp ".build/icons/StatusIcon@2x.png" "$APP/Contents/Resources/StatusIcon@2x.png"
cp Icon/source/dragon-emblem.png Icon/source/dragon-mark.png "$APP/Contents/Resources/"
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
  <key>CFBundleShortVersionString</key><string>0.2</string>
  <key>CFBundleVersion</key><string>2</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Hardened runtime + ad-hoc подпись (без нотаризации)
codesign --force --options runtime --sign - "$APP"
echo "Готово: $(pwd)/$APP"
if [ -n "$INSTALL" ]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/DragonMacros.app"
  cp -R "$APP" "$HOME/Applications/DragonMacros.app"
  echo "Установлено: $HOME/Applications/DragonMacros.app"
fi
if [ -n "$DMG" ]; then
  mkdir -p dist .build/dmg
  rm -rf .build/dmg/* && cp -R "$APP" .build/dmg/ && ln -s /Applications .build/dmg/Applications
  OUT=dist/DragonMacros-0.2-macOS.dmg
  rm -f "$OUT"
  hdiutil create -quiet -volname "Dragon Macros" -srcfolder .build/dmg -ov -format UDZO "$OUT"
  (cd dist && shasum -a 256 "$(basename "$OUT")" > SHA256SUMS.txt)
  echo "Установщик: $(pwd)/$OUT"
fi
