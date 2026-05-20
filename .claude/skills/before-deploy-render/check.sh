#!/usr/bin/env bash
# /before-deploy-render — Render.com デプロイ前チェック
# - render.yaml の妥当性 / cron スケジュール / ENV
# - 未適用マイグレーション
# - bin/render-build.sh の必須項目
# - Solid Queue 未使用の維持
# - Brakeman 警告 0
# - cron ジョブが db:migrate を呼ばないこと

set -uo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$project_root"
export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"

issues=0
warns=0
notes=0

section() { echo ""; echo "### $1"; }
ok()   { echo "  ✅ $1"; }
warn() { echo "  ⚠️  $1"; warns=$((warns+1)); }
fail() { echo "  ❌ $1"; issues=$((issues+1)); }
note() { echo "  ℹ️  $1"; notes=$((notes+1)); }

echo "=== before-deploy-render ==="

# --- 1. render.yaml 構造 ---
section "1. render.yaml"
if [[ ! -f render.yaml ]]; then
  fail "render.yaml がない"
else
  ruby -ryaml -e 'YAML.load_file("render.yaml", aliases: true)' 2>/dev/null && ok "YAML 構文OK" || fail "YAML 構文エラー"

  cron_count=$(grep -cE '^\s*-\s*type:\s*cron' render.yaml || true)
  ok "cron ジョブ数: $cron_count"

  if grep -E 'startCommand:.*db:migrate' render.yaml | grep -v '^\s*#' | grep -qv 'type: web' 2>/dev/null; then
    warn "cron ジョブが db:migrate を呼んでいる可能性 (build conflict注意)"
  fi

  if grep -qE 'buildCommand:.*bin/render-build\.sh.*cron|buildCommand:\s*bundle install\s*$' render.yaml; then
    ok "cron build は軽量 (bundle install のみ)"
  fi

  # Day 1 衝突チェック: daily-refresh(0 18 * * *) と monthly(0 18 1 * *) が同時刻
  if grep -qE 'schedule:\s*"0 18 \* \* \*"' render.yaml && grep -qE 'schedule:\s*"0 18 1 \* \*"' render.yaml; then
    if grep -q "Date.current.day == 1" app/jobs/daily_machine_refresh_job.rb 2>/dev/null; then
      ok "Day1 衝突回避: DailyMachineRefreshJob 内に skip ロジックあり"
    else
      fail "Day1 に daily-refresh と monthly が同時起動。Job 内に skip ロジックを追加"
    fi
  fi
fi

# --- 2. 未適用マイグレーション ---
section "2. マイグレーション"
status_output=$(bundle exec rails db:migrate:status 2>&1 || true)
down_count=$(printf '%s' "$status_output" | grep -c '^\s*down' || true)
if [[ "$down_count" -eq 0 ]]; then
  ok "未適用マイグレーションなし"
else
  warn "未適用マイグレーション $down_count 件 (本番デプロイ時に bin/render-build.sh が実行)"
fi

new_migrations=$(git status --porcelain db/migrate 2>/dev/null | grep -c '^??' || true)
if [[ "$new_migrations" -gt 0 ]]; then
  warn "未コミットの新規マイグレーション $new_migrations 件: git add してコミット必要"
fi

# --- 3. bin/render-build.sh の整合性 ---
section "3. bin/render-build.sh"
if [[ ! -x bin/render-build.sh ]]; then
  fail "bin/render-build.sh が実行可能でない"
else
  grep -q 'set -o errexit' bin/render-build.sh && ok "errexit 設定済" || warn "errexit 未設定"
  grep -q 'bundle install' bin/render-build.sh && ok "bundle install あり" || fail "bundle install が無い"
  grep -q 'assets:precompile' bin/render-build.sh && ok "assets:precompile あり" || fail "assets:precompile が無い"
  grep -q 'db:migrate' bin/render-build.sh && ok "db:migrate あり (web のみ)" || fail "db:migrate が無い"
  grep -q 'yarn build:css:admin' bin/render-build.sh && ok "ActiveAdmin Tailwind ビルドあり" || warn "yarn build:css:admin が無い"
fi

# --- 4. Solid Queue/Cache/Cable 未使用の確認 ---
section "4. Solid Queue/Cache/Cable (Render Starter 512MBで使わない方針)"
for gem in solid_queue solid_cache solid_cable; do
  if grep -qE "^\s*gem [\"']${gem}[\"']" Gemfile 2>/dev/null; then
    fail "$gem が有効化されている (コメントアウト必須)"
  else
    ok "$gem 無効"
  fi
done

# Solid Queue の参照が app/ にないか
if grep -rE "SolidQueue::|Solid::Queue" app/ config/ 2>/dev/null | grep -v "^Binary" | grep -v 'queue_schema.rb' >/dev/null; then
  warn "コード内に SolidQueue 参照あり (recurring.yml は参照用OKだが他はNG)"
fi

# --- 5. ENV var チェック (Render側で設定要のもの) ---
section "5. ENV vars (Render の sync:false なもの)"
required_envs=(RAILS_MASTER_KEY ADMIN_EMAIL ADMIN_PASSWORD)
for e in "${required_envs[@]}"; do
  if grep -qE "key:\s*${e}" render.yaml 2>/dev/null; then
    ok "$e が render.yaml に宣言済 (Render dashboardで値設定)"
  else
    warn "$e が render.yaml で宣言されていない"
  fi
done

# PROMOTIONS_ENABLED の状態
if grep -qE "key:\s*PROMOTIONS_ENABLED" render.yaml 2>/dev/null; then
  ok "PROMOTIONS_ENABLED 宣言済"
else
  note "PROMOTIONS_ENABLED 未宣言 (広告非表示で起動)"
fi

# config/master.key 存在
if [[ -f config/master.key ]]; then
  ok "config/master.key ローカルに存在 (RAILS_MASTER_KEY 用)"
else
  warn "config/master.key が無い"
fi

# --- 6. Brakeman 警告 ---
section "6. Brakeman セキュリティスキャン"
if ! bundle exec brakeman --version >/dev/null 2>&1; then
  warn "brakeman 未インストール"
else
  bk_output=$(bundle exec brakeman --no-progress --quiet 2>&1 || true)
  bk_warnings=$(printf '%s' "$bk_output" | grep -E "Security Warnings\s*\.\.\.+\s*[0-9]+" | sed -E 's/.*\.\.\.+\s*//' | head -1)
  if [[ "${bk_warnings:-0}" == "0" ]]; then
    ok "Security Warnings: 0"
  else
    warn "Security Warnings: $bk_warnings"
  fi
fi

# --- 7. RSpec ステータス (最後にどうだったか参考) ---
section "7. RSpec (前回実行ログ)"
if [[ -f tmp/rspec_status.txt ]]; then
  cat tmp/rspec_status.txt
else
  note "RSpec ステータス未記録。bundle exec rspec を回しておくと安心"
fi

# --- 8. 未コミット変更 ---
section "8. Git ステータス"
modified=$(git status --porcelain | wc -l | tr -d ' ')
if [[ "$modified" -eq 0 ]]; then
  ok "未コミット変更なし"
else
  warn "未コミット変更 $modified 件 (デプロイ前にコミット推奨)"
  git status --porcelain | head -10 | sed 's/^/    /'
fi

# --- 結果 ---
echo ""
echo "=== 結果 ==="
if [[ $issues -eq 0 && $warns -eq 0 ]]; then
  echo "✅ デプロイOK"
  exit 0
elif [[ $issues -eq 0 ]]; then
  echo "⚠️ WARN $warns 件 / FAIL 0 — 内容確認の上デプロイ可"
  exit 0
else
  echo "❌ FAIL $issues 件 / WARN $warns 件 — デプロイ前に解消必要"
  exit 1
fi
