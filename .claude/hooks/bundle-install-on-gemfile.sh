#!/usr/bin/env bash
# PostToolUse hook: Gemfile 編集後に bundle install を自動実行
# - Gemfile.lock が更新されない静かな失敗を防ぐ
# - 成功時は "no lock diff" or lock 差分のサマリだけ stderr へ

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
case "$(basename "$path")" in
  Gemfile) ;;
  *) exit 0 ;;
esac
[[ ! -f "$path" ]] && exit 0

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$project_root"

command -v bundle >/dev/null 2>&1 || exit 0

echo "💎 [auto] bundle install (Gemfile 編集検知)" >&2

# lock 差分の事前スナップショット
lock_before=""
[[ -f Gemfile.lock ]] && lock_before=$(shasum -a 256 Gemfile.lock | awk '{print $1}')

output=$(bundle install --quiet 2>&1)
status=$?

if (( status != 0 )); then
  printf '%s\n' "$output" | tail -15 >&2
  echo "❌ bundle install failed" >&2
  exit 2
fi

lock_after=""
[[ -f Gemfile.lock ]] && lock_after=$(shasum -a 256 Gemfile.lock | awk '{print $1}')

if [[ "$lock_before" == "$lock_after" ]]; then
  echo "  ✅ no Gemfile.lock diff" >&2
else
  echo "  ✅ bundle installed. Gemfile.lock 更新あり → コミット対象に含めること" >&2
  # 変更 gem を軽く列挙 (2列目: gem 名)
  if command -v git >/dev/null 2>&1; then
    changed=$(git diff --unified=0 Gemfile.lock 2>/dev/null \
      | grep -E '^\+ {4}[a-z0-9_-]+' \
      | awk '{print $2}' | sort -u | head -10)
    [[ -n "$changed" ]] && printf '  updated: %s\n' "$(echo "$changed" | tr '\n' ' ')" >&2
  fi
fi

exit 0
