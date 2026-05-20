#!/usr/bin/env bash
# PostToolUse hook: .erb / .html / .css 編集時に design-check を自動実行
# - 違反 0 件なら無言で終わる（編集体験を邪魔しない）
# - FAIL/WARN 検出時のみ stderr 通知

set -uo pipefail

input=$(cat)
path=$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get("tool_input", {}).get("file_path", ""))
except Exception:
    pass
')

[[ -z "$path" ]] && exit 0
case "$path" in
  *.erb|*.html|*.css) ;;
  *) exit 0 ;;
esac

root="${CLAUDE_PROJECT_DIR:-/Users/kasedashouta/Desktop/develop/yomislo}"
[[ ! -x "$root/.claude/skills/design-check/check.sh" ]] && exit 0

cd "$root" || exit 0
output=$("$root/.claude/skills/design-check/check.sh" "$path" 2>&1 || true)

# 違反があれば（❌ or ⚠️ を含む）stderr へ要約通知
if printf '%s' "$output" | grep -qE '❌|⚠️'; then
  echo "🎨 [auto] design-check: $path" >&2
  printf '%s\n' "$output" | grep -E '❌|⚠️|→' | head -10 | sed 's/^/    /' >&2
fi

exit 0
