---
name: scraping-verify
description: >
  DMMぱちタウンへのスクレイピング実行の前後でDB状態のスナップショットを取り、
  件数差分・データ品質（パチンコ混入・NFKC重複・設置機種なし店舗の変化）を自動チェックする。
  Use when ユーザーが「scraping-verify」「スクレイピング検証」「rake ptown:* の前後チェック」を依頼したとき、
  または rake ptown:import_machines / sync_shop_machines / import_shops を実行する直前/直後。
---

# Scraping Verify

DMMぱちタウンスクレイピング（`rake ptown:*`）の品質ゲート。
**実行前にスナップショット → 実行 → 実行後に差分＋検証** の流れで使う。

## いつ使うか

| シーン | コマンド |
|--------|----------|
| `rake ptown:import_machines` を回す前 | `snapshot` |
| `rake ptown:sync_shop_machines[osaka]` 完了後 | `verify` |
| 単発で現状確認したい | `verify`（スナップショット無しで品質チェックのみ実行する旨は伝える） |

ユーザーが `/scraping-verify` と打ったら、引数からモードを判定する:
- `snapshot` / `スナップショット` / `before` → snapshotモード
- `verify` / `検証` / `after` / 引数なし（スナップショットが既にある場合）→ verifyモード

## 実行コマンド

### 1. `snapshot` — 実行前スナップショット保存

```bash
cd /Users/kasedashouta/Desktop/develop/yomislo && export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH" && bin/rails runner .claude/skills/scraping-verify/snapshot.rb
```

成功すると `tmp/scraping_snapshots/latest.json` と `snapshot_YYYYMMDD_HHMMSS.json` が生成される。
報告後、ユーザーに「これでスクレイピング実行OK。完了したら `/scraping-verify verify`」と促す。

### 2. `verify` — 実行後検証（スナップショット差分 + 品質チェック）

```bash
cd /Users/kasedashouta/Desktop/develop/yomislo && export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH" && bin/rails runner .claude/skills/scraping-verify/verify.rb
```

出力例:
```
=== スクレイピング検証: 2026-05-20T17:14:38+09:00 → 現在 ===
[machine_model]
  active                  594 → 612 (↑18 / 3.0%)
  ...
[パチンコ混入] ✅ OK: 0件
[NFKC重複] ✅ OK: 0グループ

=== 結果 ===
✅ 異常なし
```

## 検証ロジック（verify.rb の内容）

| カテゴリ | チェック内容 | 閾値 |
|---------|-------------|------|
| MachineModel | total, active, with_ptown_id, smart_slot, with_image, with_ceiling, with_reset | ±10%減・±20%増でWARN |
| Shop | total, with_ptown_id, synced, with_address, with_latlng | ±5%減・±10%増でWARN |
| ShopMachineModel | total, with_unit_count | ±15%減・±30%増でWARN |
| パチンコ混入 | `^PA`/`^CR`/`ぱちんこ`/`デジハネ`/`甘デジ`/`羽根モノ`等で active 検出 | >0でFAIL |
| NFKC重複 | active.name を NFKC正規化してグループ化 | >0でWARN |
| 設置機種なし店舗 | `ptown_shop_id` あり ∧ `shop_machine_models` なし。既知 ~1,002店 | +50件以上でWARN |

## 報告フォーマット

実行後、出力をマークダウン形式で要約してユーザーに報告:

```
## スクレイピング検証結果

| カテゴリ | before → now | 差分 | 状態 |
|---------|--------------|------|------|
| MachineModel.active | 594 → 612 | +18 (3.0%) | ✅ |
| Shop.synced | 6051 → 6053 | +2 (0.0%) | ✅ |

**品質チェック**: パチンコ混入 ✅ / NFKC重複 ✅ / 設置機種なし ✅

**結論**: ✅ OK

**推奨アクション**: なし
```

問題があれば「推奨アクション」に対応 rake タスクを書く:
- パチンコ混入 → `rake ptown:cleanup`
- NFKC重複 → `rake ptown:merge_duplicates`
- 件数大幅減 → スクレイピングログ確認 / 該当県のみ再 import

## 注意

- スナップショットは `tmp/scraping_snapshots/` に保存（`tmp/` は gitignore済）
- `latest.json` は常に最新、`snapshot_YYYYMMDD_HHMMSS.json` は履歴
- 既存の `rake ptown:verify_data` は**ネットワーク経由で県別件数差分を取る**重い検証（約2.5分）。本スキルは**ローカルDBのみ**の軽量チェック（数秒）
- 関連: `.claude/skills/data-check.md`（充足率チェックの旧スキル、本スキルとは別観点）

## メンテナンス

スキーマ変更時は `snapshot.rb` と `verify.rb` のカラム参照を更新:
- Shop: `lat` / `lng`（`latitude`/`longitude` ではない）
- MachineModel: `ceiling_info` / `reset_info` は **jsonb**（空判定は `::text <> '{}'`）
