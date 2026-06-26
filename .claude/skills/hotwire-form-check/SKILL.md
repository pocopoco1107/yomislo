---
name: hotwire-form-check
description: >
  Hotwire 動的フォーム（JS で name/id を組み立て・再構築する箇所）と
  Postgres 配列カラム代入の落とし穴を検出。
  name[] の付け忘れ・id 重複・配列カラムへの scalar 代入（黙ったデータ消失）を防ぐ。
  Use proactively when:
  - app/javascript/controllers/*_form_controller.js (特に play_record_form, vote 系) を編集した
  - 配列カラムを持つモデル（Vote#confirmed_setting, PlayRecord#tags 等）の controller / update / params を編集した
  - app/views で fields_for / cocoon 系の動的エントリ追加・削除 UI を作った
  - 「フォームが配列で送られない」「配列カラムが空配列になる」と発言された
  Use when ユーザーが「hotwire-form-check」「フォームチェック」「配列カラム確認」を依頼したとき。
---

# Hotwire 動的フォーム + 配列カラム チェック

[[feedback-hotwire-array-params]] で記録UI（最重要ページ）に2回バグが出た系統の落とし穴を、編集時に再発させないため。

## 使い方

| シーン | コマンド |
|--------|----------|
| 現在の git diff （関連ファイル）を確認 | `.claude/skills/hotwire-form-check/check.sh` |
| 特定ファイルを確認 | `.claude/skills/hotwire-form-check/check.sh app/controllers/votes_controller.rb` |
| 全対象を確認 | `.claude/skills/hotwire-form-check/check.sh --all` |

ユーザーが `/hotwire-form-check` と打ったら引数なしで diff モード。

```bash
cd /Users/kasedashouta/develop/yomislo && .claude/skills/hotwire-form-check/check.sh
```

## 検出パターン

### JS 側（app/javascript/controllers/*.js）

| ID | 重要度 | 内容 |
|----|--------|------|
| reindex-missing-brackets | **FAIL** | `name = ` で配列フィールド名を組み立てる箇所で `[]` を付け忘れていないか（配列名候補リストを保持し、設計上配列なはずなのに [] が付いていないと FAIL） |
| template-replace-id | WARN | テンプレ複製で `__INDEX__` を `name` のみ置換し `id` を放置していないか |
| array-fields-list | INFO | コントローラ内に **「配列としてサーバへ送るフィールド名」** をハードコードした配列があるか（メンテ性の指標）。例: `const ARRAY_FIELDS = ["confirmed_setting", "tags"]` |

### Controller 側（app/controllers/*.rb）

| ID | 重要度 | 内容 |
|----|--------|------|
| array-update-direct | **FAIL** | `model.update(params)` 直渡しで、配列カラムが strong params の `permit(col: [])` 経由でなく scalar として渡る可能性 |
| array-cast-missing | WARN | 配列カラムへの代入で `Array(param)` 正規化していない（nil/scalar/単一要素で壊れる） |

### モデル側（app/models/*.rb）

| ID | 重要度 | 内容 |
|----|--------|------|
| array-column-no-normalize | WARN | `t.text :col, array: true` カラムを持つモデルにセッター override が無く、scalar 代入で `[]` に潰される可能性 |

## 対象になる主要ファイル

- 配列カラム: `Vote#confirmed_setting`(text[]) / `PlayRecord#tags`(text[])
- 動的フォーム: `app/javascript/controllers/play_record_form_controller.js` / `vote_controller.js` 等
- ヘッダ参照: `db/schema.rb` の `array: true` カラム一覧

## 結果の読み方

- ✅ **違反なし**: そのまま OK
- ⚠️ **WARN**: 文脈次第。bypass する正当な理由があれば無視可
- ❌ **FAIL**: 過去同種バグで実害が出た形なので修正必須

## ユーザーへの報告フォーマット

```
## hotwire-form-check 結果

| カテゴリ | 件数 | 状態 |
|---------|------|------|
| FAIL    | 1    | ❌ |
| WARN    | 0    | ✅ |

### 詳細
- `array-update-direct`: app/controllers/votes_controller.rb:42
  → `vote.update(vote_params)` 直渡しで confirmed_setting が String 化される可能性
  → fix: `vote.update(vote_params.merge(confirmed_setting: Array(vote_params[:confirmed_setting]).reject(&:blank?)))`

**結論**: ❌ FAIL 1 件 — 修正必須
```

## 限界

- JS の AST 解析はせず正規表現ベースのため、変数経由で name を組み立てる箇所は検出できない
- 「設計上配列」かどうかは `ARRAY_FIELDS` 風の定数 or schema.rb の `array: true` カラム名 で判定（命名規約依存）
- ActiveRecord の `serialize` で配列扱いするケースは未対応（PG ネイティブ array のみ）

## 関連

- [[feedback-hotwire-array-params]] — 同種バグ2件の原典
- [[feedback-tailwind-v4-display]] — Hotwire 周辺の別系統落とし穴
- [[project-ui-overhaul-2026-06]] — 記録UI再構築の文脈
- [[project-companion-pet]] — 記録フックがペット進化と連動するため壊すと影響大
