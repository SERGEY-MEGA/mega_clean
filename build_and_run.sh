#!/bin/bash

set -euo pipefail

APP_MAIN_NAME="MegaCleaner"
APP_MINI_NAME="MegaCleanerMini"
BUILD_DIR="./build"

MAIN_BUNDLE="$BUILD_DIR/$APP_MAIN_NAME.app"
MINI_BUNDLE="$BUILD_DIR/$APP_MINI_NAME.app"

SDK_PATH="$(xcrun --show-sdk-path --sdk macosx)"
TARGET="arm64-apple-macosx11.0" # поменяй на x86_64-apple-macosx11.0 если Intel

mkdir -p "$MAIN_BUNDLE/Contents/MacOS" "$MAIN_BUNDLE/Contents/Resources"
mkdir -p "$MINI_BUNDLE/Contents/MacOS" "$MINI_BUNDLE/Contents/Resources"

# Generate icons if missing
mkdir -p "./Resources"
if [[ ! -f "./Resources/AppIcon.icns" || ! -f "./Resources/MiniIcon.icns" ]]; then
  echo "🎨 Генерация иконок…"
  swift ./generate_icons.swift
  iconutil -c icns "./Resources/AppIcon.iconset" -o "./Resources/AppIcon.icns"
  iconutil -c icns "./Resources/MiniIcon.iconset" -o "./Resources/MiniIcon.icns"
fi

cp Info.Main.plist "$MAIN_BUNDLE/Contents/Info.plist"
cp Info.Mini.plist "$MINI_BUNDLE/Contents/Info.plist"

cp "./Resources/AppIcon.icns" "$MAIN_BUNDLE/Contents/Resources/AppIcon.icns"
cp "./Resources/MiniIcon.icns" "$MINI_BUNDLE/Contents/Resources/MiniIcon.icns"

swiftc -o "$MAIN_BUNDLE/Contents/MacOS/$APP_MAIN_NAME" \
    SystemMonitorManager.swift \
    StorageManager.swift \
    CleanerScanManager.swift \
    SharedUI.swift \
    MainWindowView.swift \
    MegaCleanerMainApp.swift \
    -sdk "$SDK_PATH" \
    -target "$TARGET"

swiftc -o "$MINI_BUNDLE/Contents/MacOS/$APP_MINI_NAME" \
    SystemMonitorManager.swift \
    StorageManager.swift \
    SharedUI.swift \
    MenuView.swift \
    AppDelegate.swift \
    MegaCleanerMiniApp.swift \
    -sdk "$SDK_PATH" \
    -target "$TARGET"

echo "✅ Собрано:"
echo " - $MAIN_BUNDLE"
echo " - $MINI_BUNDLE"

# Install to /Applications (if permitted)
DEST="/Applications"
if [[ -w "${DEST}" ]]; then
  echo "📦 Установка в ${DEST}..."
  rm -rf "${DEST}/${APP_MAIN_NAME}.app" "${DEST}/${APP_MINI_NAME}.app" || true
  ditto "${MAIN_BUNDLE}" "${DEST}/${APP_MAIN_NAME}.app"
  ditto "${MINI_BUNDLE}" "${DEST}/${APP_MINI_NAME}.app"
  echo "✅ Установлено в ${DEST}"
else
  echo "ℹ️ Нет прав записи в ${DEST}."
  echo "   Установить можно так:"
  echo "   sudo ditto \"${MAIN_BUNDLE}\" \"${DEST}/${APP_MAIN_NAME}.app\" && sudo ditto \"${MINI_BUNDLE}\" \"${DEST}/${APP_MINI_NAME}.app\""
fi

echo "🚀 Запуск мини-окна (менюбар)..."
open "$MINI_BUNDLE"
