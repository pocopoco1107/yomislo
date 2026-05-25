#!/usr/bin/env bash
# PreToolUse(Bash) hook: rake ptown:* 実行直前に snapshot を自動取得
# 対象タスク: import_machines / sync_shop_machines / import_shops / import_details /
#            import_all / merge_duplicates / cleanup / purge_pworld

set -uo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get("tool_input", {}).get("command", ""))
except Exception:
    pass
')

[[ -z "$cmd" ]] && exit 0

# rake ptown:* を検出（bundle exec rake / bin/rails / rake いずれも対応）
if printf '%s' "$cmd" | grep -qE 'rake[[:space:]]+ptown:(import_machines|sync_shop_machines|import_shops|import_details|import_all|merge_duplicates|cleanup|purge_pworld)'; then
  echo "🔍 [auto] scraping-verify snapshot を実行中..." >&2

  root="${CLAUDE_PROJECT_DIR:-/Users/kasedashouta/develop/yomislo}"
  if [[ -f "$root/.claude/skills/scraping-verify/snapshot.rb" ]]; then
    cd "$root" || exit 0
    export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"
    # snapshot を実行。出力は要約のみ stderr へ
    output=$(bin/rails runner .claude/skills/scraping-verify/snapshot.rb 2>&1 || true)
    printf '%s\n' "$output" | grep -E 'MachineModel|Shop:|SMM:|スナップショット保存' >&2
    echo "✅ [auto] snapshot 完了。rake 実行後に /scraping-verify verify で検証推奨" >&2
  else
    echo "⚠️ [auto] snapshot.rb が見つからず、スキップ" >&2
  fi
fi

exit 0
