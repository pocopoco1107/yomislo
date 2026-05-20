#!/usr/bin/env bash
# PreToolUse hook: 機密ファイルの編集をブロック
# stdin: tool input JSON
# exit 2 → 編集ブロック（メッセージはstderrでClaudeに返る）

set -euo pipefail

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

case "$path" in
  *.env|*.env.*|*/\.env|*/\.env.*)
    echo "❌ .env ファイルの編集はブロックされています (Render の env var で管理): $path" >&2
    exit 2
    ;;
  */config/master.key)
    echo "❌ config/master.key は Render の RAILS_MASTER_KEY で管理されています。ローカル編集禁止: $path" >&2
    exit 2
    ;;
  */config/credentials*.yml.enc)
    echo "⚠️ credentials.yml.enc は 'bin/rails credentials:edit' 経由で編集してください: $path" >&2
    exit 2
    ;;
esac

exit 0
