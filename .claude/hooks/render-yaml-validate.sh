#!/usr/bin/env bash
# PostToolUse hook: render.yaml 編集後の軽量バリデーション
# - YAML 構文チェック
# - cron スケジュール衝突検出 (同一時刻に複数 cron が走らないか)
# - startCommand 妥当性 (rails runner / bundle exec 等の頻出 typo)

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
  render.yaml|render.yml) ;;
  *) exit 0 ;;
esac
[[ ! -f "$path" ]] && exit 0

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$project_root"

echo "🚀 [auto] render.yaml validate" >&2

result=$(python3 - "$path" <<'PY'
import sys, re
try:
    import yaml
except ImportError:
    print("SKIP: PyYAML unavailable", file=sys.stderr)
    sys.exit(0)

path = sys.argv[1]
warnings = []
fails = []

try:
    with open(path) as f:
        data = yaml.safe_load(f)
except yaml.YAMLError as e:
    print(f"❌ YAML syntax error: {e}")
    sys.exit(2)

services = (data or {}).get("services", []) or []
crons = [s for s in services if s.get("type") == "cron"]

# 1. schedule 衝突検出
schedule_owners = {}
for s in crons:
    sch = s.get("schedule")
    name = s.get("name", "?")
    if not sch:
        fails.append(f"cron {name}: schedule 欄が空")
        continue
    if sch in schedule_owners:
        warnings.append(f"schedule conflict: {sch!r} が {schedule_owners[sch]} と {name} で重複")
    else:
        schedule_owners[sch] = name

# 2. cron 記法の粗い妥当性 (5 or 6 field)
for s in crons:
    sch = s.get("schedule", "")
    parts = sch.strip().split()
    if len(parts) not in (5, 6):
        fails.append(f"cron {s.get('name','?')}: schedule 記法が {len(parts)} フィールド (5 or 6 が正常): {sch!r}")

# 3. startCommand 妥当性
for s in services:
    sc = s.get("startCommand", "")
    if not sc:
        continue
    if "rails runner" in sc and "bundle exec" not in sc:
        warnings.append(f"{s.get('name','?')}: startCommand に 'rails runner' あり、'bundle exec rails runner' を推奨: {sc}")
    if "perform_now" in sc and "perform_later" in sc:
        warnings.append(f"{s.get('name','?')}: perform_now と perform_later が混在: {sc}")

# 4. plan/region の欠落チェック (Free/Starter/Basic 前提)
for s in services + (data.get("databases") or []):
    if s.get("type") == "cron" or s.get("type") == "web" or "databaseName" in s:
        if not s.get("plan"):
            warnings.append(f"{s.get('name','?')}: plan が指定されていない (starter/basic/free)")
        if not s.get("region"):
            warnings.append(f"{s.get('name','?')}: region が指定されていない (singapore 推奨)")

# 5. env vars: sync: false の秘密キー確認
for s in services:
    for ev in (s.get("envVars") or []):
        key = ev.get("key", "")
        if key in ("RAILS_MASTER_KEY", "SENTRY_DSN", "ADMIN_PASSWORD", "ADMIN_EMAIL") and ev.get("sync") is not False:
            warnings.append(f"{s.get('name','?')} envVars.{key}: 秘密情報は sync: false 推奨")

for f in fails:
    print(f"❌ {f}")
for w in warnings:
    print(f"⚠️  {w}")

if not fails and not warnings:
    print("✅ render.yaml OK (schedule/plan/region/env vars 妥当)")

sys.exit(2 if fails else 0)
PY
)
status=$?

if [[ -n "$result" ]]; then
  printf '%s\n' "$result" | sed 's/^/  /' >&2
fi

# fails > 0 のときのみ exit 2 で警告通知 (ブロックはしない)
exit $status
