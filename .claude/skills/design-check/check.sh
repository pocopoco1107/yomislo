#!/usr/bin/env bash
# design-check: DESIGN.md の規約に違反していないかチェック
# Usage:
#   .claude/skills/design-check/check.sh           # git diff の変更ファイル
#   .claude/skills/design-check/check.sh --all     # app/views, app/assets/stylesheets 全部
#   .claude/skills/design-check/check.sh path1 path2  # 指定ファイル

set -uo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$project_root"

# 対象ファイル決定（macOS bash 3互換: mapfile使わない）
files=()
if [[ $# -eq 0 ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && files+=("$f")
  done < <(
    { git diff --name-only HEAD 2>/dev/null; git diff --name-only --cached 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } \
      | sort -u \
      | grep -E '\.(erb|html|css|js|rb)$' || true
  )
elif [[ "${1:-}" == "--all" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && files+=("$f")
  done < <(find app/views app/assets/stylesheets app/javascript -type f \( -name '*.erb' -o -name '*.html' -o -name '*.css' -o -name '*.js' \) 2>/dev/null)
else
  files=("$@")
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "対象ファイルなし"
  exit 0
fi

echo "=== design-check: ${#files[@]} files ==="

issues=0
warnings=0

scan() {
  local label="$1" pattern="$2" severity="$3" hint="$4"
  shift 4
  local hits
  hits=$(grep -nHE "$pattern" "${files[@]}" 2>/dev/null | grep -vE '^Binary file' || true)
  [[ -z "$hits" ]] && return 0

  local count
  count=$(printf '%s\n' "$hits" | wc -l | tr -d ' ')

  if [[ "$severity" == "FAIL" ]]; then
    echo ""
    echo "❌ [$label] $count 件 — $hint"
    issues=$((issues + count))
  else
    echo ""
    echo "⚠️  [$label] $count 件 — $hint"
    warnings=$((warnings + count))
  fi
  printf '%s\n' "$hits" | head -10 | sed 's/^/    /'
  [[ $count -gt 10 ]] && echo "    ... (+$((count - 10)) more)"
}

# === 違反パターン ===

# 1. ハードコードHEX (3桁/6桁、CSS変数経由でない)
# 許容: var(--xxx), tw-* クラス
scan "hardcoded-hex" \
  '#[0-9a-fA-F]{6}([^0-9a-fA-F]|$)|#[0-9a-fA-F]{3}([^0-9a-fA-F]|$)' \
  "WARN" \
  "ハードコードHEX値。--primary 等のセマンティックトークンを使う"

# 2. rgb()/rgba() 直書き
scan "raw-rgb" \
  'rgb\(|rgba\(' \
  "WARN" \
  "rgb()/rgba() 直書き。CSS変数経由を推奨"

# 3. レインボーグラデーション (3+ via)
scan "rainbow-gradient" \
  'bg-gradient-(to-[trbl]+|conic|radial).*via-[a-z]+-[0-9]+.*via-[a-z]+-[0-9]+' \
  "FAIL" \
  "レインボーグラデーション (3+ via)。DESIGN.md Don'ts"

# 4. グラデーションブロブ (blur + opacity + huge size)
scan "gradient-blob" \
  '(blur-3xl|blur-2xl).*opacity-[0-9]+|opacity-[0-9]+.*blur-3xl' \
  "WARN" \
  "グラデーションブロブ背景の可能性。DESIGN.md Don'ts"

# 5. bg-clip-text + 日本語混在の可能性 (.erb で text-transparent)
scan "japanese-gradient-text" \
  'bg-clip-text.*text-transparent|text-transparent.*bg-clip-text' \
  "WARN" \
  "日本語テキストへのグラデーション禁止。確認推奨"

# 6. hidden と flex/grid の併用 (Tailwind v4 既知バグ)
scan "hidden-flex-conflict" \
  'class=".*\bhidden\b.*\b(flex|grid)\b|class=".*\b(flex|grid)\b.*\bhidden\b' \
  "FAIL" \
  "Tailwind v4 で hidden + flex/grid 競合。style.display で制御"

# 7. 禁止用語（コピーライティング）
scan "banned-copy-words" \
  '集合知|可視化|集約|ソリューション|最適化された' \
  "WARN" \
  "AIっぽい硬い用語。打ち手口調に書き換え"

# 8. ネオングリーン
scan "neon-green" \
  '#00[fF][fF]00|#0[fF]0([^0-9a-fA-F]|$)|rgb\(0,\s*255,\s*0' \
  "FAIL" \
  "ネオングリーン禁止。エメラルド系 (--primary #10b981) を使う"

# 9. Turbo Frame 内の render_promotion (Ruby/erb)
# 簡易チェック: 同一ファイル内に turbo_frame_tag と render_promotion が両方あるか
for f in "${files[@]}"; do
  [[ "$f" != *.erb && "$f" != *.html ]] && continue
  [[ ! -f "$f" ]] && continue
  if grep -q 'turbo_frame_tag\|<turbo-frame' "$f" && grep -q 'render_promotion' "$f"; then
    if [[ $issues -eq 0 && $warnings -eq 0 ]]; then echo ""; fi
    echo "⚠️  [promotion-in-frame] $f"
    echo "    Turbo Frame と render_promotion が同居。Frame外配置を推奨"
    warnings=$((warnings + 1))
  fi
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
