#!/usr/bin/env bash
# Hutch をソースから入れているユーザー向けの更新スクリプト。
#
# 使い方:
#   ./scripts/update.sh
#
# 流れ:
#   1. ローカル変更チェック（あれば中断 or 続行を促す）
#   2. git pull --ff-only で main を最新化
#   3. リリースビルド + ~/Applications にインストール
#   4. 起動中のプロセスを kill して再起動

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# ANSI カラー（端末でなければ無効化）
if [[ -t 1 ]]; then
  BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'
else
  BLUE=''; GREEN=''; YELLOW=''; RED=''; RESET=''
fi

step() { printf "${BLUE}==>${RESET} %s\n" "$1"; }
ok()   { printf "${GREEN}✓${RESET} %s\n" "$1"; }
warn() { printf "${YELLOW}!${RESET} %s\n" "$1"; }
fail() { printf "${RED}✗${RESET} %s\n" "$1" >&2; exit 1; }

# 1. リポジトリチェック
[[ -d .git ]] || fail "ここは Hutch のリポジトリではありません: $ROOT_DIR"

# 2. ローカル変更検査
if ! git diff --quiet || ! git diff --cached --quiet; then
  warn "ローカルに未コミットの変更があります："
  git status --short
  echo
  read -p "続行しますか？ (y/N) " -n 1 -r ANSWER
  echo
  [[ $ANSWER =~ ^[Yy]$ ]] || fail "中断しました。"
fi

# 3. 現在のブランチを確認
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  warn "main ブランチではありません（現在: $CURRENT_BRANCH）。main で更新します。"
  git checkout main
fi

BEFORE_SHA="$(git rev-parse HEAD)"

# 4. 最新を取得
step "最新の main を取得しています..."
git pull --ff-only origin main

AFTER_SHA="$(git rev-parse HEAD)"

if [[ "$BEFORE_SHA" == "$AFTER_SHA" ]]; then
  ok "既に最新です ($(git rev-parse --short HEAD))"
  echo
  read -p "それでも再ビルドしますか？ (y/N) " -n 1 -r ANSWER
  echo
  [[ $ANSWER =~ ^[Yy]$ ]] || { ok "アップデート不要、終了します。"; exit 0; }
fi

# 5. ビルド + インストール
step "ビルド中..."
./scripts/build_app.sh --install >/dev/null

ok "ビルドとインストールが完了しました。"

# 6. 起動中のプロセスを再起動
if pgrep -f "Hutch.app" >/dev/null 2>&1; then
  step "起動中の Hutch を再起動しています..."
  pkill -f "Hutch.app" 2>/dev/null || true
  sleep 0.5
fi

open "$HOME/Applications/Hutch.app"
ok "Hutch を再起動しました。"

# 7. 取り込んだ変更のサマリ
echo
step "取り込んだ変更:"
git --no-pager log --oneline "${BEFORE_SHA}..${AFTER_SHA}" | head -20
