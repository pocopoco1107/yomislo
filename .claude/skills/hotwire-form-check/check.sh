#!/usr/bin/env bash
# hotwire-form-check: 動的フォームJS + PG配列カラムの落とし穴を検出
# Usage:
#   .claude/skills/hotwire-form-check/check.sh           # git diff の関連ファイル
#   .claude/skills/hotwire-form-check/check.sh --all     # 全対象
#   .claude/skills/hotwire-form-check/check.sh path1 path2  # 指定ファイル

set -uo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$project_root"

# schema.rb から PG配列カラムを抽出 (table_name, column_name)
declare -a ARRAY_COLUMNS=()
declare -a ARRAY_MODELS=()
if [[ -f db/schema.rb ]]; then
  current_table=""
  while IFS= read -r line; do
    if [[ "$line" =~ create_table[[:space:]]+\"([^\"]+)\" ]]; then
      current_table="${BASH_REMATCH[1]}"
    fi
    if [[ -n "$current_table" && "$line" =~ \"([a-z_]+)\".+array:[[:space:]]*true ]]; then
      col="${BASH_REMATCH[1]}"
      ARRAY_COLUMNS+=("${current_table}.${col}")
      # singularize 雑: trailing s 削除
      model="${current_table%s}"
      ARRAY_MODELS+=("$model:$col")
    fi
  done < db/schema.rb
fi

# 対象ファイル決定（macOS bash 3互換）
files=()
if [[ $# -eq 0 ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && files+=("$f")
  done < <(
    { git diff --name-only HEAD 2>/dev/null; git diff --name-only --cached 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } \
      | sort -u \
      | grep -E '\.(rb|js)$' \
      | grep -E '(controllers|models|javascript)' || true
  )
elif [[ "${1:-}" == "--all" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && files+=("$f")
  done < <(find app/controllers app/models app/javascript/controllers -type f \( -name '*.rb' -o -name '*.js' \) 2>/dev/null)
else
  files=("$@")
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "対象ファイルなし"
  exit 0
fi

echo "=== hotwire-form-check: ${#files[@]} files / 配列カラム ${#ARRAY_COLUMNS[@]}個 ==="
echo "    検出した配列カラム: ${ARRAY_COLUMNS[*]:-none}"

issues=0
warnings=0

note_fail() {
  echo ""
  echo "❌ [$1] $2"
  issues=$((issues + 1))
}

note_warn() {
  echo ""
  echo "⚠️  [$1] $2"
  warnings=$((warnings + 1))
}

# === JS 側チェック ===
for f in "${files[@]}"; do
  [[ ! -f "$f" ]] && continue
  [[ "$f" != *.js ]] && continue

  # 1. テンプレ複製で __INDEX__ を name しか置換していない（id 取り残し）
  if grep -q '__INDEX__' "$f"; then
    # 同じ関数/メソッド内に name と id の両方の置換があるか粗くチェック
    name_replace=$(grep -c 'name.*__INDEX__\|__INDEX__.*name' "$f" 2>/dev/null | tr -d '\n ' || echo 0)
    id_replace=$(grep -c '\.id\s*=.*__INDEX__\|__INDEX__.*\.id\b\|id="\?__INDEX__\|id=\\"__INDEX__' "$f" 2>/dev/null | tr -d '\n ' || echo 0)
    name_replace=${name_replace:-0}
    id_replace=${id_replace:-0}
    if [[ $name_replace -gt 0 && $id_replace -eq 0 ]]; then
      note_warn "template-replace-id" "$f: __INDEX__ を name にのみ置換、id は放置の可能性 (id重複でラベル/aria が壊れる)"
    fi
  fi

  # 2. _reindex 系で name を組み立てているのに [] 不在の配列フィールド
  # 配列フィールド名候補 = schema の配列カラム名 ∪ 既知名 (ループ毎に初期化)
  array_field_names=()
  for entry in "${ARRAY_MODELS[@]}"; do
    array_field_names+=("${entry#*:}")
  done
  array_field_names+=("confirmed_setting" "tags")

  for fname in "${array_field_names[@]}"; do
    # name="...[${fname}]" のように [] 無しで現れたら問題
    # (?<!\[)${fname}\] のような lookbehind は基本grep不可なので、まずヒットを集めてフィルタ
    hits=$(grep -nE "\[${fname}\]" "$f" 2>/dev/null || true)
    if [[ -n "$hits" ]]; then
      # [fname][] でなく [fname] で終わる name="..." パターンに絞る
      bad_hits=$(echo "$hits" | grep -E "name\s*[:=].*\[${fname}\]([^[]|\$)" || true)
      if [[ -n "$bad_hits" ]]; then
        note_fail "reindex-missing-brackets" "$f: 配列フィールド '$fname' の name に [] が付いていない可能性"
        echo "$bad_hits" | head -3 | sed 's/^/    /'
      fi
    fi
  done

  # 3. ARRAY_FIELDS 等の配列ハードコード定数があるか（INFOレベル）
  if [[ "$f" == *_form_controller.js ]]; then
    if grep -qE 'name\s*=' "$f" && ! grep -qE 'ARRAY_FIELDS|arrayFields|ARRAY_NAMES' "$f"; then
      note_warn "array-fields-list" "$f: 動的に name を組み立てているが ARRAY_FIELDS 定数なし。配列フィールド一覧を明示するとメンテしやすい"
    fi
  fi
done

# === Controller 側チェック ===
for f in "${files[@]}"; do
  [[ ! -f "$f" ]] && continue
  [[ "$f" != app/controllers/*.rb ]] && continue

  # 1. update(params) 直渡し
  if grep -nE '\.update\([a-z_]+_params\)' "$f" > /dev/null 2>&1; then
    # 対象モデルが配列カラム持ちか
    base=$(basename "$f" _controller.rb)
    model_singular="${base%s}"
    has_array=0
    for entry in "${ARRAY_MODELS[@]}"; do
      model="${entry%:*}"
      if [[ "$model" == "$model_singular" ]]; then
        has_array=1
        break
      fi
    done
    if [[ $has_array -eq 1 ]]; then
      hits=$(grep -nE '\.update\([a-z_]+_params\)' "$f")
      note_warn "array-update-direct" "$f: update(*_params) 直渡し。$model_singular は配列カラム持ち → strong params で permit(col: []) かつ Array() 正規化を確認"
      echo "$hits" | head -3 | sed 's/^/    /'
    fi
  fi

  # 2. permit(...) 内に配列カラムがある場合 col: [] 形式か
  for entry in "${ARRAY_MODELS[@]}"; do
    model="${entry%:*}"
    col="${entry#*:}"
    base=$(basename "$f" _controller.rb)
    model_singular="${base%s}"
    [[ "$model" != "$model_singular" ]] && continue

    # permit に列挙されているが col: [] 形式でない
    if grep -nE "\bpermit\(" "$f" | grep -q "$col" 2>/dev/null; then
      if ! grep -nE "${col}:\s*\[\s*\]" "$f" > /dev/null 2>&1; then
        # 同ファイルで Array(...) 正規化を経由していれば意図的 scalar 設計 → WARN 降格
        if grep -qE "Array\(\s*[a-z_:@\[\".]*${col}|${col}[^a-z_].*=.*Array\(" "$f"; then
          note_warn "permit-array-scalar" "$f: permit で $col が scalar、Array() 正規化は存在するが意図を確認"
        else
          note_fail "permit-array-scalar" "$f: permit で $col を許可しているが '$col: []' 形式でない → scalar 化される"
        fi
        grep -nE "${col}" "$f" | head -3 | sed 's/^/    /'
      fi
    fi
  done
done

# === モデル側チェック ===
for f in "${files[@]}"; do
  [[ ! -f "$f" ]] && continue
  [[ "$f" != app/models/*.rb ]] && continue

  base=$(basename "$f" .rb)
  for entry in "${ARRAY_MODELS[@]}"; do
    model="${entry%:*}"
    col="${entry#*:}"
    [[ "$model" != "$base" ]] && continue

    # セッター override が無いと scalar 代入で [] になる可能性
    if ! grep -qE "def\s+${col}=" "$f"; then
      note_warn "array-column-no-normalize" "$f: 配列カラム '$col' にセッター override なし。Array() 正規化を入れる候補"
      echo "    fix: def ${col}=(v); super(Array(v).map(&:to_s).reject(&:blank?)); end"
    fi
  done
done

# === サマリ ===
echo ""
echo "=== 結果 ==="
if [[ $issues -eq 0 && $warnings -eq 0 ]]; then
  echo "✅ 違反なし"
  exit 0
else
  echo "❌ FAIL: $issues 件 / ⚠️ WARN: $warnings 件"
  exit $((issues > 0 ? 1 : 0))
fi
