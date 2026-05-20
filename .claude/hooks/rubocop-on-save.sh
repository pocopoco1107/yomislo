#!/usr/bin/env bash
# PostToolUse hook: 編集された .rb に対して rubocop -a (自動修正) を走らせる
# stdin: tool input JSON
# 出力は stderr で Claude に返る（PostToolUse の exit 2 は警告通知）

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
[[ "$path" != *.rb ]] && exit 0
[[ ! -f "$path" ]] && exit 0

# プロジェクトルート判定（hookスクリプトの祖父ディレクトリ）
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$project_root"

# rubocop が無ければスキップ
[[ ! -x "bin/bundle" ]] && [[ ! -x "$(command -v bundle)" ]] && exit 0
bundle exec rubocop --version >/dev/null 2>&1 || exit 0

# 自動修正 (安全な --autocorrect のみ)。出力は最終行サマリだけ stderr へ
output=$(bundle exec rubocop -a "$path" 2>&1 || true)
summary=$(printf '%s' "$output" | tail -3)
echo "📝 rubocop -a $path" >&2
printf '%s\n' "$summary" >&2

exit 0
