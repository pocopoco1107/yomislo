#!/usr/bin/env bash
# i18n-key-check: ビュー/コントローラ/ヘルパーの t(...) 参照が ja.yml に存在するか検証
# Usage:
#   check.sh                       # 現在の git diff から検出
#   check.sh app/views/foo.erb     # 指定ファイル
#   check.sh --all                 # app/views, app/controllers, app/helpers 全件

set -uo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$project_root"

LOCALE_FILE="config/locales/ja.yml"
RUBY_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/check.rb"

if [[ ! -f "$LOCALE_FILE" ]]; then
  echo "🌐 i18n-key-check: $LOCALE_FILE が無い (skip)"
  exit 0
fi

# 対象ファイル解決
files=()
if [[ $# -eq 0 ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    files+=("$line")
  done < <(git -C "$project_root" status --porcelain 2>/dev/null \
    | awk '{print $NF}' \
    | grep -E '^app/(views|controllers|helpers|mailers)/.*\.(erb|rb)$' || true)
elif [[ "$1" == "--all" ]]; then
  while IFS= read -r f; do files+=("$f"); done < <(
    find app/views app/controllers app/helpers app/mailers -type f \( -name '*.erb' -o -name '*.rb' \) 2>/dev/null
  )
else
  files=("$@")
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "🌐 i18n-key-check: 対象なし"
  exit 0
fi

LANG=ja_JP.UTF-8 ruby -E UTF-8 "$RUBY_SCRIPT" "$LOCALE_FILE" "${files[@]}"
