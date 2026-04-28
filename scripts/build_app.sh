#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${CONFIG:-release}"
# 表示名は Nudge、Swift プロダクト名（バイナリファイル名）は ReminderMenu のまま据え置き
# （Bundle ID と FDA 許可、Shortcuts.app 上のショートカット名互換のため）
DISPLAY_NAME="Nudge"
PRODUCT_NAME="ReminderMenu"
APP_DIR="$ROOT_DIR/build/$DISPLAY_NAME.app"

cd "$ROOT_DIR"
mkdir -p "$ROOT_DIR/.build/clang-module-cache"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"
swift build -c "$CONFIG"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp ".build/$CONFIG/$PRODUCT_NAME" "$APP_DIR/Contents/MacOS/$PRODUCT_NAME"
cp "$ROOT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
chmod +x "$APP_DIR/Contents/MacOS/$PRODUCT_NAME"

# サブタスク用ショートカットなどのバンドルリソースをコピー
if [[ -d "$ROOT_DIR/Resources" ]]; then
  cp -R "$ROOT_DIR/Resources/." "$APP_DIR/Contents/Resources/"
fi

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

if [[ "${1:-}" == "--install" ]]; then
  mkdir -p "$HOME/Applications"
  # 旧名 (ReminderMenu.app) があれば削除して付け替え
  rm -rf "$HOME/Applications/ReminderMenu.app"
  rm -rf "$HOME/Applications/$DISPLAY_NAME.app"
  cp -R "$APP_DIR" "$HOME/Applications/$DISPLAY_NAME.app"
  echo "$HOME/Applications/$DISPLAY_NAME.app"
else
  echo "$APP_DIR"
fi
