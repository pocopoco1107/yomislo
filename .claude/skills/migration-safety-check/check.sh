#!/usr/bin/env bash
# migration-safety-check: db/migrate/*.rb の本番安全性を静的解析する
# Usage:
#   check.sh                       # 現在の git diff から検出
#   check.sh db/migrate/xxxx.rb    # 指定ファイル
#   check.sh --recent N            # 直近 N 件のマイグレ
#   check.sh --all                 # db/migrate 全件

set -uo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$project_root"

LARGE_TABLES="shops machine_models shop_machine_models votes play_records vote_summaries"

fail=0
warn=0
inspected=0

# 対象ファイルの解決
files=()
if [[ $# -eq 0 ]]; then
  # git diff から AM 状態のマイグレを拾う (untracked も含める)
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    files+=("$line")
  done < <(git -C "$project_root" status --porcelain db/migrate 2>/dev/null \
    | awk '{print $NF}' \
    | grep -E '^db/migrate/.*\.rb$' || true)
elif [[ "$1" == "--all" ]]; then
  while IFS= read -r f; do files+=("$f"); done < <(ls db/migrate/*.rb 2>/dev/null)
elif [[ "$1" == "--recent" ]]; then
  n="${2:-3}"
  while IFS= read -r f; do files+=("$f"); done < <(ls -1 db/migrate/*.rb 2>/dev/null | sort | tail -n "$n")
else
  files=("$@")
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "🔍 migration-safety-check: 対象なし (git diff にマイグレ変更なし)"
  exit 0
fi

echo "🔍 migration-safety-check (${#files[@]} files)"

# 大規模テーブル名を | 区切りの正規表現に
large_re=$(echo "$LARGE_TABLES" | tr ' ' '|')

for f in "${files[@]}"; do
  [[ ! -f "$f" ]] && continue
  inspected=$((inspected + 1))
  base=$(basename "$f")
  findings=()

  body=$(cat "$f")
  has_concurrently=$(printf '%s' "$body" | grep -cE 'algorithm:\s*:concurrently' || true)
  has_disable_ddl=$(printf '%s' "$body" | grep -cE '^[[:space:]]*disable_ddl_transaction!' || true)
  is_initial=$(printf '%s' "$base" | grep -cE 'create_(.+)|initial_schema' || true)

  # ルール: NOT NULL 追加 (既存テーブル想定)
  while IFS= read -r m; do
    [[ -z "$m" ]] && continue
    findings+=("FAIL|not-null-on-existing|${m}|既存テーブルへの NOT NULL 追加。default + backfill を分離せよ")
  done < <(printf '%s' "$body" | grep -nE 'change_column_null[^,]+,\s*false|add_column.*null:\s*false|change_column.*null:\s*false' || true)

  # ルール: remove_column
  while IFS= read -r m; do
    [[ -z "$m" ]] && continue
    findings+=("FAIL|remove-column|${m}|remove_column はデプロイ2段階化が必要 (参照削除→反映後にカラム削除)")
  done < <(printf '%s' "$body" | grep -nE '^\s*remove_column\b' || true)

  # ルール: rename_column / rename_table
  while IFS= read -r m; do
    [[ -z "$m" ]] && continue
    findings+=("FAIL|rename-column|${m}|rename_column は禁止。新カラム→backfill→旧削除の3段階に分割")
  done < <(printf '%s' "$body" | grep -nE '^\s*rename_column\b' || true)
  while IFS= read -r m; do
    [[ -z "$m" ]] && continue
    findings+=("FAIL|rename-table|${m}|rename_table は禁止。view 経由 or 段階移行")
  done < <(printf '%s' "$body" | grep -nE '^\s*rename_table\b' || true)

  # ルール: drop_table (create_table の rollback でない単独)
  if [[ "$is_initial" -eq 0 ]]; then
    while IFS= read -r m; do
      [[ -z "$m" ]] && continue
      findings+=("FAIL|drop-table|${m}|drop_table はデータ消失。バックアップ確認とロールバック戦略必須")
    done < <(printf '%s' "$body" | grep -nE '^\s*drop_table\b' || true)
  fi

  # ルール: change_column の型変換
  while IFS= read -r m; do
    [[ -z "$m" ]] && continue
    findings+=("FAIL|change-column-type|${m}|型変換はテーブルロック。新カラム→backfill→入替手順に分けよ")
  done < <(printf '%s' "$body" | grep -nE '^\s*change_column\s+:[a-z_]+,\s*:[a-z_]+,\s*:[a-z_]+' || true)

  # ルール: 大規模テーブルへの add_index 非 concurrent
  while IFS= read -r m; do
    [[ -z "$m" ]] && continue
    line=$(printf '%s' "$m" | cut -d: -f1)
    content=$(printf '%s' "$m" | cut -d: -f2-)
    if ! printf '%s' "$content" | grep -qE 'algorithm:\s*:concurrently'; then
      findings+=("WARN|add-index-no-concurrently|${line}: ${content}|大規模テーブル。algorithm: :concurrently + disable_ddl_transaction! 推奨")
    fi
  done < <(printf '%s' "$body" | grep -nE "add_index\s+:(${large_re})\b" || true)

  # ルール: concurrently 使ってるのに disable_ddl 無い
  if [[ "$has_concurrently" -gt 0 && "$has_disable_ddl" -eq 0 ]]; then
    findings+=("FAIL|no-disable-ddl-when-concurrently|file|algorithm: :concurrently を使うなら先頭に disable_ddl_transaction! が必須")
  fi

  # ルール: irreversible 戦略の明示
  if printf '%s' "$body" | grep -qE '^\s*def\s+up\b' && printf '%s' "$body" | grep -qE '^\s*def\s+down\b'; then
    down_block=$(printf '%s' "$body" | awk '/def down/,/^  end/')
    if ! printf '%s' "$down_block" | grep -qE 'IrreversibleMigration|drop_table|remove_|change_'; then
      findings+=("WARN|missing-irreversible|def down|down 側に巻き戻し or IrreversibleMigration を明示せよ")
    fi
  fi

  # 出力
  if [[ ${#findings[@]} -eq 0 ]]; then
    echo "  ✅ ${base}"
  else
    has_fail=0
    for finding in "${findings[@]}"; do
      level=$(echo "$finding" | cut -d'|' -f1)
      [[ "$level" == "FAIL" ]] && has_fail=1
    done
    if [[ $has_fail -eq 1 ]]; then
      echo "  ❌ ${base}"
      fail=$((fail + 1))
    else
      echo "  ⚠️  ${base}"
      warn=$((warn + 1))
    fi
    for finding in "${findings[@]}"; do
      IFS='|' read -r level rule where msg <<< "$finding"
      icon="⚠️ "
      [[ "$level" == "FAIL" ]] && icon="❌"
      echo "     ${icon} [${rule}] ${where}"
      echo "        → ${msg}"
    done
  fi
done

echo ""
echo "📊 inspected=${inspected} fail=${fail} warn=${warn}"

[[ $fail -gt 0 ]] && exit 1
exit 0
