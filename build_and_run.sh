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

cp Info.Main.plist "$MAIN_BUNDLE/Contents/Info.plist"
cp Info.Mini.plist "$MINI_BUNDLE/Contents/Info.plist"

swiftc -o "$MAIN_BUNDLE/Contents/MacOS/$APP_MAIN_NAME" \
    SystemMonitorManager.swift \
    StorageManager.swift \
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

echo "🚀 Запуск мини-окна (менюбар)..."
open "$MINI_BUNDLE"
