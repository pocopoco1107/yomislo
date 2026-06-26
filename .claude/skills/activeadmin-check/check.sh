#!/usr/bin/env bash
# activeadmin-check: ActiveAdmin 4 リソース追加・編集時の落とし穴を検出
# Usage:
#   .claude/skills/activeadmin-check/check.sh           # git diff の admin 関連
#   .claude/skills/activeadmin-check/check.sh --all     # app/admin 全部
#   .claude/skills/activeadmin-check/check.sh path1 path2  # 指定ファイル

set -uo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$project_root"

# 対象ファイル決定（macOS bash 3互換: mapfile使わない）
admin_files=()
if [[ $# -eq 0 ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && admin_files+=("$f")
  done < <(
    { git diff --name-only HEAD 2>/dev/null; git diff --name-only --cached 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } \
      | sort -u \
      | grep -E '^app/admin/.+\.rb$' || true
  )
elif [[ "${1:-}" == "--all" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && admin_files+=("$f")
  done < <(find app/admin -type f -name '*.rb' 2>/dev/null)
else
  admin_files=("$@")
fi

echo "=== activeadmin-check: ${#admin_files[@]} admin files ==="

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

# === 1. ApplicationController が AdminAuthentication を include しているか ===
app_ctrl="app/controllers/application_controller.rb"
if [[ -f "$app_ctrl" ]]; then
  if ! grep -q 'include AdminAuthentication' "$app_ctrl"; then
    note_fail "auth-include" "ApplicationController に \`include AdminAuthentication\` がない → AA4 認証が動かない"
    echo "    fix: $app_ctrl に include AdminAuthentication を追加"
  fi
fi

# === 2. ApplicationRecord 継承（Ransack デフォルト allowlist 経由）===
# 新規 admin リソース → 対応モデルが ApplicationRecord 継承か確認
for f in "${admin_files[@]}"; do
  [[ ! -f "$f" ]] && continue
  resource=$(basename "$f" .rb)
  resource_singular="${resource%s}"
  model_file=$(find app/models -maxdepth 2 -type f -iname "${resource_singular}.rb" 2>/dev/null | head -1)
  if [[ -n "$model_file" ]] && ! grep -qE 'class\s+\w+\s*<\s*ApplicationRecord' "$model_file"; then
    note_warn "ransack-allowlist" "$model_file が ApplicationRecord を継承していない → Ransack allowlist 手動定義必要"
  fi
done

# === 3. enum prefix と scope DSL の整合 ===
# admin リソース内の scope :name, default: true を抽出し、対応モデルの enum prefix と照合
for f in "${admin_files[@]}"; do
  [[ ! -f "$f" ]] && continue
  resource=$(basename "$f" .rb)
  resource_singular="${resource%s}"
  model_file=$(find app/models -maxdepth 2 -type f -iname "${resource_singular}.rb" 2>/dev/null | head -1)
  [[ -z "$model_file" ]] && continue

  # モデル側に enum prefix があるか
  prefix=$(grep -oE 'enum\s+:\w+,\s*\{[^}]+\},\s*prefix:\s*:\w+' "$model_file" | grep -oE 'prefix:\s*:\w+' | grep -oE ':\w+$' | tr -d ':' | head -1)
  [[ -z "$prefix" ]] && continue

  # admin の scope :xxx 行が prefix なしで呼ばれていないか（ブロック形式でないもの）
  while IFS= read -r line; do
    # "scope :xxx" の "xxx" が prefix_xxx なら OK
    scope_name=$(echo "$line" | grep -oE 'scope\s+:\w+' | grep -oE ':\w+$' | tr -d ':')
    [[ -z "$scope_name" ]] && continue
    # ActiveAdmin 組み込みスコープは enum と無関係 → 除外
    case "$scope_name" in all|active|inactive|recent|archived|draft|published) continue ;; esac
    # ブロック形式（do |s| s.prefix_xxx end）なら問題なし
    if echo "$line" | grep -qE '\bdo\s*\|'; then
      continue
    fi
    # モデル側に該当 enum 値 ($scope_name) が実在するときのみ警告 → 完全に無関係な scope は除外
    if ! grep -qE "enum\s+:\w+.*\b${scope_name}\b" "$model_file"; then
      continue
    fi
    if [[ ! "$scope_name" =~ ^${prefix}_ ]]; then
      note_warn "enum-prefix-scope" "$f:$line"
      echo "    モデル $model_file は enum prefix :$prefix を持つので scope は ${prefix}_${scope_name} か do |s| s.${prefix}_${scope_name} end ブロック形式に"
    fi
  done < <(grep -nE '^\s*scope\s+:\w+' "$f" || true)
done

# === 4. slug を to_param で返すモデルの find_resource override ===
for f in "${admin_files[@]}"; do
  [[ ! -f "$f" ]] && continue
  resource=$(basename "$f" .rb)
  resource_singular="${resource%s}"
  model_file=$(find app/models -maxdepth 2 -type f -iname "${resource_singular}.rb" 2>/dev/null | head -1)
  [[ -z "$model_file" ]] && continue

  if grep -qE 'def\s+to_param\b' "$model_file" && grep -qE '\bslug\b' "$model_file"; then
    if ! grep -q 'def find_resource' "$f"; then
      note_fail "slug-finder" "$f: モデル $resource_singular が to_param で slug 返すが find_resource override なし"
      echo "    fix: controller do ... def find_resource; scoped_collection.find_by(slug: params[:id]) || super; end ... end"
    fi
  fi
done

# === 5. check_boxes 配列カラムのモデルセッター ===
for f in "${admin_files[@]}"; do
  [[ ! -f "$f" ]] && continue
  # admin に as: :check_boxes が使われているか
  cb_attrs=$(grep -oE ':\w+\s*,\s*as:\s*:check_boxes' "$f" | sed -E 's/^:([a-z_]+).*/\1/' | sort -u || true)
  [[ -z "$cb_attrs" ]] && continue

  resource=$(basename "$f" .rb)
  resource_singular="${resource%s}"
  model_file=$(find app/models -maxdepth 2 -type f -iname "${resource_singular}.rb" 2>/dev/null | head -1)
  [[ -z "$model_file" ]] && continue

  for attr in $cb_attrs; do
    if ! grep -qE "def\s+${attr}=" "$model_file"; then
      note_warn "array-column-setter" "$f は $attr に as: :check_boxes を使うが $model_file にセッター $attr= がない"
      echo "    fix: def ${attr}=(v); super(Array(v).map(&:to_s).reject(&:blank?)); end"
    elif ! grep -A 3 "def[[:space:]]\+${attr}=" "$model_file" | grep -qE 'reject\(&:blank\?\)|reject\s*\{.*blank\?'; then
      note_warn "array-column-setter" "$f: $attr セッターに blank 除去 (reject(&:blank?)) がないかも"
    fi
  done
done

# === 6. I18n キー（プロジェクト全体・1回だけチェック）===
i18n_file="config/locales/ja.yml"
if [[ -f "$i18n_file" ]]; then
  required_keys=("date.formats.default" "date.day_names" "date.month_names" "time.formats.default" "time.am" "time.pm")
  missing=()
  for key in "${required_keys[@]}"; do
    # キーの末尾要素で grep（ネスト深いので雑に）
    last=$(echo "$key" | awk -F. '{print $NF}')
    if ! grep -q "^\s*${last}:" "$i18n_file"; then
      missing+=("$key")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    note_warn "i18n-keys" "config/locales/ja.yml に欠落の可能性: ${missing[*]}"
    echo "    AA4 は v3 より多くの I18n キーを要求する"
  fi
fi

# === 7-8. 目視確認項目（情報出力のみ）===
echo ""
echo "--- 目視確認項目 ---"
echo "[ ] config/initializers/active_admin_breadcrumb.rb で slug フォールバック健在"
echo "[ ] admin を curl で確認する時は -H \"Accept: text/html\" を必ず付与 (AA4 は restrict_download_format_access! デフォルト有効)"

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
