#!/usr/bin/env bash
# vote-integrity-check: 匿名性・ユニーク制約・cookie設計の静的検査

set -uo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$project_root"

fails=0
warns=0
declare -a fail_lines
declare -a warn_lines

add_fail() { fail_lines+=("$1"); fails=$((fails+1)); }
add_warn() { warn_lines+=("$1"); warns=$((warns+1)); }

schema="db/schema.rb"

# --- Rule: missing-unique-index ---
if [[ -f "$schema" ]]; then
  if ! grep -qE 'unique:\s*true' "$schema" || \
     ! grep -qE 'add_index\s+"votes".*voter_token.*shop_id.*machine_model_id.*voted_on' "$schema"; then
    # フォールバック: t.index 記法も許容
    if ! grep -A2 't.index' "$schema" | grep -qE 'voter_token.*shop_id.*machine_model_id.*voted_on'; then
      add_fail "missing-unique-index: db/schema.rb に voter_token+shop_id+machine_model_id+voted_on の unique index が見当たらない"
    fi
  fi
fi

# --- Rule: unique-validation-missing ---
vote_model="app/models/vote.rb"
if [[ -f "$vote_model" ]]; then
  if ! grep -qE 'validates\s+:voter_token' "$vote_model" || \
     ! grep -qE 'uniqueness:.*scope:' "$vote_model"; then
    add_warn "unique-validation-missing: app/models/vote.rb に voter_token+scope の uniqueness validation が見当たらない (schema unique index があれば実害は少ない)"
  fi
fi

# --- Rule: ip-column-detected / ua-column-detected ---
if [[ -f "$schema" ]]; then
  # votes / voter_profiles / voter_rankings / play_records / comments を対象
  target_tables='"votes"|"voter_profiles"|"voter_rankings"|"play_records"|"comments"'
  # awk で該当テーブルブロックだけを抽出して IP/UA カラムを検索
  ip_hit=$(awk -v pat="$target_tables" '
    /^create_table/ { in_block = 0 }
    /^create_table/ && $0 ~ pat { in_block = 1; table = $0; next }
    in_block && /end$/ { in_block = 0 }
    in_block && /(ip_address|remote_ip)/ { print table ": " $0 }
  ' "$schema")
  ua_hit=$(awk -v pat="$target_tables" '
    /^create_table/ { in_block = 0 }
    /^create_table/ && $0 ~ pat { in_block = 1; table = $0; next }
    in_block && /end$/ { in_block = 0 }
    in_block && /(user_agent|"ua")/ { print table ": " $0 }
  ' "$schema")
  [[ -n "$ip_hit" ]] && add_fail "ip-column-detected: 匿名性違反の恐れ → $ip_hit"
  [[ -n "$ua_hit" ]] && add_fail "ua-column-detected: 匿名性違反の恐れ → $ua_hit"
fi

# --- Rule: ip-write-in-controller / ua-write-in-controller ---
# controller/service で request.remote_ip / request.user_agent を assign or 保存
while IFS= read -r line; do
  add_fail "ip-write-in-controller: $line"
done < <(grep -RnE '(request\.remote_ip|request\.ip)\s*[^,)#]*=|=\s*request\.remote_ip' \
  app/controllers app/services app/models 2>/dev/null | grep -v '_spec.rb' | grep -v 'rack_attack')

while IFS= read -r line; do
  add_fail "ua-write-in-controller: $line"
done < <(grep -RnE '(request\.user_agent)\s*[^,)#]*=|=\s*request\.user_agent' \
  app/controllers app/services app/models 2>/dev/null | grep -v '_spec.rb')

# --- Rule: login-in-public-view ---
public_view_paths=(
  app/views/shops
  app/views/home
  app/views/machine_models
  app/views/rankings
  app/views/voter
  app/views/play_records
  app/views/comments
  app/views/prefectures
  app/views/feedbacks
)
for dir in "${public_view_paths[@]}"; do
  [[ ! -d "$dir" ]] && continue
  # authenticate_user!, sign_in_path, current_user. の混入検知
  while IFS= read -r line; do
    add_fail "login-in-public-view: $line"
  done < <(grep -RnE 'authenticate_user!|sign_in_path|devise_scope|current_user\.' "$dir" 2>/dev/null)
done

# public controller にも軽く: shops/home/machine_models/rankings/voter/play_records
public_ctrl_paths=(
  app/controllers/shops_controller.rb
  app/controllers/home_controller.rb
  app/controllers/machine_models_controller.rb
  app/controllers/rankings_controller.rb
  app/controllers/voter_controller.rb
  app/controllers/play_records_controller.rb
  app/controllers/votes_controller.rb
)
for f in "${public_ctrl_paths[@]}"; do
  [[ ! -f "$f" ]] && continue
  while IFS= read -r line; do
    add_fail "login-in-public-controller: $line"
  done < <(grep -nE 'authenticate_user!|current_user' "$f" 2>/dev/null)
done

# --- Rule: cookie 設計 ---
# voter_token cookie の設定箇所を探す
voter_cookie_lines=$(grep -RnE 'cookies?\..*voter_token' app/controllers app/services 2>/dev/null || true)

if [[ -n "$voter_cookie_lines" ]]; then
  # permanent の警告
  if printf '%s' "$voter_cookie_lines" | grep -qE 'cookies\.permanent'; then
    add_warn "cookie-permanent: voter_token を cookies.permanent (期限20年) で発行している。目的なら OK、意図せずなら短縮を検討"
  fi
  # httponly チェック
  # cookies.encrypted[:voter_token] = { value:..., httponly: true, ... } パターン
  if ! grep -RE 'voter_token' app/controllers app/services 2>/dev/null \
     | grep -qE 'httponly'; then
    # cookies.signed[:voter_token] = uuid のような簡易代入だけの場合
    # → デフォルトは httponly=false のブラウザ挙動なので警告 (Rails cookies デフォルトは HttpOnly ON だが明示推奨)
    if grep -RE 'cookies\[:voter_token\]\s*=' app/controllers app/services 2>/dev/null \
       | grep -qvE 'signed\[:voter_token|encrypted\[:voter_token'; then
      add_warn "cookie-not-httponly: voter_token を平文 cookies[] で書き込んでいる。cookies.signed[:voter_token] または cookies.encrypted[:voter_token] を推奨"
    fi
  fi
  # same_site 明示チェック
  if grep -RE 'voter_token' app/controllers app/services 2>/dev/null \
     | grep -qE 'same_site'; then
    :
  else
    # config/initializers/session_store.rb or config/application.rb に defaults がある場合は許容
    if ! grep -RE 'same_site|SameSite' config/initializers config/application.rb 2>/dev/null | grep -q .; then
      add_warn "cookie-not-samesite: voter_token cookie / セッション設定で same_site 指定が見当たらない (:lax 以上推奨)"
    fi
  fi
fi

# --- レポート ---
echo "## vote-integrity-check 結果"
echo
echo "| カテゴリ | 件数 | 状態 |"
echo "|---------|------|------|"
if (( fails == 0 )); then
  echo "| FAIL    | 0    | ✅ |"
else
  echo "| FAIL    | $fails | ❌ |"
fi
if (( warns == 0 )); then
  echo "| WARN    | 0    | ✅ |"
else
  echo "| WARN    | $warns | ⚠️ |"
fi
echo

if (( fails > 0 )); then
  echo "### ❌ FAIL (設計原則違反)"
  for l in "${fail_lines[@]}"; do echo "- $l"; done
  echo
fi
if (( warns > 0 )); then
  echo "### ⚠️ WARN (要確認)"
  for l in "${warn_lines[@]}"; do echo "- $l"; done
  echo
fi

if (( fails == 0 && warns == 0 )); then
  echo "**結論**: ✅ 設計原則 (匿名性 / 重複排除 / Cookie) OK"
  exit 0
elif (( fails == 0 )); then
  echo "**結論**: ✅ FAIL なし / ⚠️ 要確認 $warns 件"
  exit 0
else
  echo "**結論**: ❌ FAIL $fails 件 / ⚠️ WARN $warns 件"
  exit 1
fi
