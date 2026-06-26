---
name: migration-safety-check
description: >
  db/migrate/*.rb の本番安全性チェック。NOT NULL 追加・大規模テーブルへの index 追加・
  破壊的なカラム削除/rename・enum 並び替え・disable_ddl_transaction! 漏れを検出する。
  Render 本番運用 (Web + cron 3本) で停止リスクを未然に防ぐ。
  Use proactively when:
    - db/migrate/*.rb を新規作成・編集した
    - 「マイグレ作成」「migration追加」「db:migrate 本番反映」と発言された
  Use when ユーザーが「migration-safety-check」「マイグレチェック」を依頼したとき。
---

# Migration Safety Check

ヨミスロの本番 (Render Postgres Basic / Singapore) で `db:migrate` を実行する際に
踏みやすい落とし穴を `db/migrate/*.rb` から自動検出するスキル。

## 使い方

| シーン | コマンド |
|--------|----------|
| 現在の git diff にあるマイグレを確認（既定） | `.claude/skills/migration-safety-check/check.sh` |
| 特定ファイルを確認 | `.claude/skills/migration-safety-check/check.sh db/migrate/202xxxx_foo.rb` |
| 直近 N 件のマイグレを確認 | `.claude/skills/migration-safety-check/check.sh --recent 3` |

ユーザーが `/migration-safety-check` と打ったら引数なし（diff モード）で実行する。

```bash
cd /Users/kasedashouta/develop/yomislo && .claude/skills/migration-safety-check/check.sh
```

## 検出ルール

| ID | 重要度 | 内容 | 対処 |
|----|--------|------|------|
| not-null-on-existing | **FAIL** | 既存テーブルに `change_column_null :col, false` または `null: false` 追加 | default 値を先に設定 or backfill マイグレを分離 |
| add-index-no-concurrently | WARN | 大規模テーブル (shops/machine_models/votes/play_records) に `add_index` で `algorithm: :concurrently` 無し | `add_index ..., algorithm: :concurrently` + `disable_ddl_transaction!` |
| concurrently-in-transaction | **FAIL** | `algorithm: :concurrently` あるが `disable_ddl_transaction!` が無い | 先頭に `disable_ddl_transaction!` 追加 |
| remove-column | **FAIL** | `remove_column` を含む | 2段階デプロイ (1: コード側で参照削除 → 2: マイグレ) を経たか確認 |
| rename-column | **FAIL** | `rename_column` を含む | 別名カラム追加→backfill→旧削除の3段階に分けたか確認 |
| rename-table | **FAIL** | `rename_table` を含む | 同上 (view やコード参照の事前置換が必要) |
| drop-table | **FAIL** | `drop_table` を含む（`create_table` の rollback ではなく単独） | データ消失リスク。バックアップ取得確認 |
| change-column-type | **FAIL** | `change_column ..., :type, ...` で型変換 | テーブルロック発生。新カラム→backfill→入替の手順か確認 |
| enum-reorder | WARN | `add_column ..., :integer` で既存 enum 列を触る兆候 | enum 値の追加は末尾のみ。並び替え/削除禁止 |
| no-disable-ddl-when-concurrently | **FAIL** | concurrently あるのに先頭 `disable_ddl_transaction!` が無い | 上記参照 |
| missing-irreversible | WARN | `up`/`down` を分けて `down` 側で `raise ActiveRecord::IrreversibleMigration` も `change` も無い | 巻き戻し戦略を明示 |

## 大規模テーブル定義

ヨミスロ本番で行数が多く index/NOT NULL 追加が危険なテーブル:

- `shops`           : 約 10,000 行
- `machine_models`  : 約 800 行（だが頻繁に参照される）
- `shop_machine_models` : 約 200,000 行（最大級）
- `votes`           : ユーザー記録蓄積。日次増加
- `play_records`    : ユーザー記録蓄積。日次増加
- `vote_summaries`  : votes と同オーダー

このリストにあるテーブルへの `add_index` / `NOT NULL` 追加は **必ず** WARN 以上で検知する。

## 出力フォーマット

```
🔍 migration-safety-check
  ✅ 20260623060737_create_pets.rb  (clean)
  ⚠️  20260520145937_add_facility_columns_to_shops.rb
     [add-index-no-concurrently] L12: add_index :shops, :wifi_available
     → 推奨: add_index :shops, :wifi_available, algorithm: :concurrently
            (先頭に disable_ddl_transaction! を追加)
```

FAIL があれば exit 1、WARN のみなら exit 0。

## 仕組み

`db/migrate/*.rb` の差分を `git diff --diff-filter=A --name-only` で取得 (or 引数指定) し、
正規表現ベースで上記ルールを走らせる。`disable_ddl_transaction!` の有無は同ファイル内 grep。

## 関連

- [BACKLOG.md](../../../BACKLOG.md) — 本番反映前のチェックリスト
- `before-deploy-render` スキル — デプロイ前の包括チェック (こちらはマイグレ単体)
- `migration-reviewer` サブエージェント — このスキルの結果を踏まえた構造的レビュー
