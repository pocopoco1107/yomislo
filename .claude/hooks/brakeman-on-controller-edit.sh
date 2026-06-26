#!/usr/bin/env bash
# PostToolUse hook: app/controllers/*.rb (および models/services) を編集したら
# Brakeman を --only-files で軽量実行する。
# SQL injection / mass assignment / open redirect / XSS の静的検知。

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
case "$path" in
  app/controllers/*.rb|app/models/*.rb|app/services/*.rb|app/helpers/*.rb) ;;
  */app/controllers/*.rb|*/app/models/*.rb|*/app/services/*.rb|*/app/helpers/*.rb) ;;
  *) exit 0 ;;
esac
[[ ! -f "$path" ]] && exit 0

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$project_root"

# 相対パスに正規化
rel="${path#$project_root/}"

command -v bundle >/dev/null 2>&1 || exit 0
bundle exec brakeman --version >/dev/null 2>&1 || exit 0

echo "🔒 brakeman --only-files $rel" >&2
# --quiet で進捗を抑制、--no-progress、--format plain で軽量
output=$(bundle exec brakeman --only-files "$rel" --quiet --no-progress --format plain 2>&1 || true)

# "No warnings" or "0 warnings" を検知
if printf '%s' "$output" | grep -qiE 'no warnings found|0 security warnings|No warnings'; then
  echo "  ✅ no security warnings" >&2
  exit 0
fi

# warnings ありなら警告通知
echo "$output" | tail -30 >&2
echo "⚠️  brakeman: review warnings above" >&2
exit 2
