#!/bin/sh
# Нативная дымовая проверка UI: отдельная временная конфигурация, без изменения пользовательских макросов.
set -eu
cd "$(dirname "$0")"
mkdir -p .build/interface-tests .build/ModuleCache
output=${1:-.build/interface-tests/window.png}
case "$output" in *../*|*/..) echo "Parent traversal is not allowed" >&2; exit 2;; esac
case "$output" in .build/*) ;; *) echo "Screenshots must stay inside .build/" >&2; exit 2;; esac
mkdir -p "$(dirname "$output")"
set --
for source in Sources/*.swift; do
  [ "$source" = Sources/main.swift ] || set -- "$@" "$source"
done
swiftc -Onone -whole-module-optimization -module-cache-path "$(pwd)/.build/ModuleCache" "$@" Tests/InterfaceSmoke/main.swift -o .build/interface-tests/InterfaceSmoke
.build/interface-tests/InterfaceSmoke "$output"
