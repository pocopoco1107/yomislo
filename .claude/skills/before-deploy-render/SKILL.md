---
name: before-deploy-render
description: >
  Render.com へデプロイする直前のチェックリスト。render.yaml の妥当性・cronスケジュール衝突・
  未適用マイグレーション・bin/render-build.sh の整合性・Solid Queue 無効維持・ENV var宣言・
  Brakeman 警告・git 状態を一気に確認する。
  Use proactively when:
  - ユーザーが「デプロイする」「Render に push する」「本番反映」と発言した
  - git push origin main / master を実行する直前
  - render.yaml / bin/render-build.sh / config/database.yml / config/puma.rb を編集した
  - 新しいマイグレーションを作成しコミットしようとしている
  - Gemfile に Solid Queue/Cache/Cable を追加しようとしている
  - ユーザーが「before-deploy-render」「Renderデプロイ前チェック」「デプロイ前確認」を依頼した
---

# Before Deploy (Render)

Render.com デプロイ前のプリフライトチェック。push する前にこれを通せば
本番で「あれ?」になる主要パターンを潰せる。

## 使い方

```bash
cd /Users/kasedashouta/develop/yomislo && .claude/skills/before-deploy-render/check.sh
```

ユーザーが `/before-deploy-render` と打ったら上記コマンドを実行。
完了まで 10〜30秒（Brakeman で時間を食う）。

## チェック項目

| # | カテゴリ | 内容 |
|---|---------|------|
| 1 | render.yaml | YAML構文・cronジョブ数・cron buildが軽量か・Day1衝突回避 |
| 2 | マイグレーション | `db:migrate:status` で未適用がないか・新規マイグレ未コミット |
| 3 | bin/render-build.sh | errexit / bundle install / assets:precompile / db:migrate / yarn build |
| 4 | Solid Queue/Cache/Cable | solid_cache は有効 (primary DB backed で :solid_cache_store)。solid_queue/cable は無効。SolidQueue コード参照が無いか |
| 5 | ENV vars | RAILS_MASTER_KEY / ADMIN_EMAIL / ADMIN_PASSWORD が render.yaml で宣言済 + config/master.key 存在 |
| 6 | Brakeman | Security Warnings = 0 |
| 7 | RSpec | 前回実行ログ（tmp/rspec_status.txt）の参照 |
| 8 | Git | 未コミット変更の有無 |

## Day1 衝突の背景

`render.yaml` に2つの 18:00 UTC ジョブがある:
- `yomislo-daily-refresh`: `0 18 * * *`（毎日）
- `yomislo-monthly`: `0 18 1 * *`（毎月1日）

毎月1日に**同時起動**してDBレース・レート制限超過のリスク。
これを `app/jobs/daily_machine_refresh_job.rb` の `return if Date.current.day == 1` で回避している。
スキルはこの skip ロジックの存在を毎回確認する。

## cron build conflict の背景

過去コミット「Fix cron build conflict: skip migrations on cron services」より、
cron サービスの `buildCommand` で `db:migrate` を呼ぶと、web の build と競合する。
本スキルでは cron の startCommand に `db:migrate` が混入していないか確認する。

## 出力例（健全時）

```
=== before-deploy-render ===
### 1. render.yaml
  ✅ YAML 構文OK
  ✅ Day1 衝突回避: DailyMachineRefreshJob 内に skip ロジックあり
### 2. マイグレーション
  ✅ 未適用マイグレーションなし
... (略)
### 結果
✅ デプロイOK
```

## 失敗時の典型対応

| FAIL/WARN | 対応 |
|-----------|------|
| YAML 構文エラー | render.yaml の indent / アンカー記法を確認 |
| 未コミット新規マイグレ | `git add db/migrate/* && git commit` |
| solid_queue / solid_cable 有効 | Gemfile でコメントアウト |
| solid_cache が別DB (database: cache) | config/cache.yml の `database: cache` 行を削除し primary DB を使う |
| ENV 宣言なし | render.yaml に `key: XXX` を追加し、Render dashboardで値設定 |
| Brakeman warnings | `bin/brakeman --no-pager` で詳細確認 |
| Day1 衝突 | DailyMachineRefreshJob に `return if Date.current.day == 1` |

## RSpec ログ記録

`tmp/rspec_status.txt` を読みに行く。テスト後に下記で記録すると便利:

```bash
bundle exec rspec > tmp/rspec_status.txt 2>&1
tail -3 tmp/rspec_status.txt > tmp/rspec_status.txt.tmp && mv tmp/rspec_status.txt.tmp tmp/rspec_status.txt
```

## 関連

- [render.yaml](../../../render.yaml)
- [bin/render-build.sh](../../../bin/render-build.sh)
- [CLAUDE.md](../../../CLAUDE.md) Renderスケジュール表
- [[project_scraping_architecture]] — cron 3本構成の背景
