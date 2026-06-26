#!/usr/bin/env bash
# PostToolUse hook: 編集された *_spec.rb だけを単発で実行する
# 全体 rspec (533 examples) は重いので、編集対象 1 本だけ流して即座にフィードバックを返す
# 失敗時は stderr に最終 20 行を出す

set -uo pipefail

input=$(cat)
path=$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    p = data.get("tool_input", {}).get("file_path", "")
    print(p)
except Exception:
    pass
')

[[ -z "$path" ]] && exit 0
[[ "$path" != *_spec.rb ]] && exit 0
[[ ! -f "$path" ]] && exit 0

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$project_root"

# bundle が無ければスキップ
command -v bundle >/dev/null 2>&1 || exit 0
bundle exec rspec --version >/dev/null 2>&1 || exit 0

echo "🧪 rspec $(basename "$path")" >&2
output=$(bundle exec rspec "$path" --fail-fast --format progress --no-color 2>&1 || true)

# 成功判定（"0 failures" を含むか）
if printf '%s' "$output" | grep -qE '0 failures'; then
  summary=$(printf '%s' "$output" | tail -3 | tr -d '\r')
  printf '%s\n' "$summary" >&2
  exit 0
else
  printf '%s' "$output" | tail -20 >&2
  echo "❌ spec failed: $path" >&2
  # PostToolUse での exit 2 は警告通知 (ブロックではない)
  exit 2
fi
