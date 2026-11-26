#!/bin/sh
# Изолированные регрессионные тесты хранилища без запуска приложения и внешних зависимостей.
set -eu
cd "$(dirname "$0")"
mkdir -p .build/tests .build/module-cache
export CLANG_MODULE_CACHE_PATH="$(pwd)/.build/module-cache"
export SWIFT_MODULECACHE_PATH="$CLANG_MODULE_CACHE_PATH"
swiftc -module-cache-path "$CLANG_MODULE_CACHE_PATH" \
  Sources/Models.swift Sources/Settings.swift Sources/Hotkeys.swift Sources/MacroStore.swift Sources/Actions.swift Sources/Updater.swift \
  Tests/main.swift -o .build/tests/DragonMacrosTests
.build/tests/DragonMacrosTests
