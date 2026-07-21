---
name: vote-integrity-check
description: >
  Vote モデルの匿名性・ユニーク制約・cookie 設計に関するチェック。
  voter_token が生成/参照される全パス、ユニーク制約 (voter_token + shop_id + machine_model_id + voted_on)、
  IP/UA を保存していないか、cookie の有効期限・secure/httponly、admin以外にログイン導線が入っていないかを点検する。
  Use when ユーザーが「vote-integrity-check」「投票整合性チェック」を依頼したとき、
  または app/controllers/votes_controller.rb / app/models/vote*.rb / app/models/voter_*.rb /
  db/migrate/*vote*.rb を編集した直後に自己点検が必要なとき。
---

# Vote Integrity Check

ヨミスロの最重要設計判断:

- **1人1日1店舗1機種1件**: `voter_token + shop_id + machine_model_id + voted_on` でユニーク
- **ログイン不要**: 公開機能は全て匿名。voter_token は Cookie のみ
- **IP / UA を保存しない**: `Vote` テーブル・付随テーブルに IP/UA 列が絶対に無い

これらは Vote / VoterProfile / VoterRanking / PlayRecord などの周辺コード変更で
簡単に壊れうる (誰も気づかないまま重複投稿が入り込む・匿名性が崩れる)。
本スキルはそれを検出するための静的検査 + ガイド。

## 使い方 (User-only)

副作用の恐れがあるため、明示的な依頼で発火する（PostToolUse hookからの自動起動はしない）。

```bash
cd /Users/kasedashouta/develop/yomislo && .claude/skills/vote-integrity-check/check.sh
```

## チェック観点

### 1. ユニーク制約の維持
- `db/schema.rb` に `index_votes_on_voter_token_and_shop_id_and_machine_model_id_and_voted_on` が unique
- Vote モデルに `validates_uniqueness_of` の対応バリデーション
- controller で `find_or_initialize_by` パターンが崩れていないか
- 新規 migration で unique index を drop していないか

### 2. voter_token の匿名性
- `voter_token` が SecureRandom.hex/uuid で生成されている (推測不可能)
- Cookie の `httponly: true`, `same_site: :lax` 以上
- Cookie 有効期限が短すぎ (7日未満) / 長すぎ (10年超) でないか
- ユーザー識別可能なフォールバック (session id など) に切り替えていないか

### 3. IP / User-Agent の非保存
- `votes` / `voter_profiles` / `voter_rankings` / `play_records` / `comments` に
  `ip_address`, `remote_ip`, `user_agent`, `ua` 相当のカラムが無い
- controller で `request.remote_ip` / `request.user_agent` を Model に保存していない
- ログには rack-attack 側の rate-limit 目的以外で残していない

### 4. ログイン導線の混入検知
- 公開画面 (`app/views/{shops,home,machine_models,rankings,voter,play_records}/**`) に
  `sign_in`, `devise_scope`, `authenticate_user!`, `current_user.` の混入が無い
- Devise は `/admin` のみで許容

### 5. 集計チェーンの匿名性
- VoterRanking / VoterProfile のキャッシュキーに個人特定情報を混ぜていないか
- 表示名は `voter_profile.display_name` (自己申告) のみ

## check.sh の検出ルール

| ID | 重要度 | 内容 |
|----|--------|------|
| missing-unique-index | **FAIL** | schema.rb の votes 表に対象 unique index が無い |
| unique-validation-missing | **FAIL** | Vote モデルに uniqueness validation が無い |
| ip-column-detected | **FAIL** | schema.rb に ip_address / remote_ip 相当カラム |
| ua-column-detected | **FAIL** | schema.rb に user_agent / ua 相当カラム |
| ip-write-in-controller | **FAIL** | app/controllers に `request.remote_ip` の Model 保存 |
| ua-write-in-controller | **FAIL** | app/controllers に `request.user_agent` の Model 保存 |
| login-in-public-view | **FAIL** | 公開 view に authenticate_user! / current_user. / sign_in_path |
| cookie-permanent | WARN | voter_token を `cookies.permanent` (期限20年) にしている |
| cookie-not-httponly | **FAIL** | voter_token cookie に httponly が付いていない |
| cookie-not-samesite | WARN | voter_token cookie に same_site が指定されていない |

## 結果の読み方

- ✅ FAIL 0件: 匿名性・重複排除 OK
- ⚠️ WARN: 現状は許容だが将来的に改善検討
- ❌ FAIL: 修正必須（設計原則違反）

## 手動確認が必要な観点

check.sh では拾えないが、レビュー時に確認する:

- Turbo Frame の部分更新で voter_token が URL に露出していないか
- 通報 (Report) 機能で被通報者の voter_token が admin 以外に表示されないか
- CSV export 系タスクで voter_token を平文出力していないか
- log に voter_token を残していないか (`Rails.logger.info vote.voter_token` パターン)

## ユーザーへの報告フォーマット

```
## vote-integrity-check 結果

| 観点 | 状態 |
|------|------|
| ユニーク制約 | ✅ |
| 匿名性 (IP/UA非保存) | ✅ |
| Cookie 設計 | ⚠️ |
| ログイン導線 | ✅ |

### ⚠️ 要確認
- cookie-not-samesite: app/controllers/votes_controller.rb#set_voter_token
  → cookies[:voter_token] に same_site 指定なし。:lax 以上を推奨

**結論**: ✅ 設計原則 OK / ⚠️ Cookie 設計 1 件
```

## 関連

- CLAUDE.md「重要な設計判断」節
- [[project_data_quality.md]] — Vote/PlayRecord 投稿数の実態
- [[feedback_hotwire_array_params.md]] — 配列カラム保存の落とし穴
