---
name: i18n-key-check
description: >
  app/views/*.erb や app/controllers/*.rb で使われている t(".key") / t("a.b.c") に
  対応する config/locales/ja.yml のキーが実在するかを検証する。
  本番で `translation missing` が表示されるのを未然に防ぐ。
  Use proactively when:
    - app/views/**/*.erb を編集して t(...) が増えた
    - app/controllers/**/*.rb / app/helpers/**/*.rb を編集して t(...) が増えた
    - config/locales/*.yml を編集した
  Use when ユーザーが「i18n-key-check」「翻訳チェック」「翻訳キー確認」を依頼したとき。
---

# i18n Key Check

`t(".key")` (lazy lookup) と `t("a.b.c")` (絶対パス) で参照されている翻訳キーが
`config/locales/ja.yml` に実在するかを照合するスキル。

## 使い方

| シーン | コマンド |
|--------|----------|
| 現在の git diff から検出（既定） | `.claude/skills/i18n-key-check/check.sh` |
| 特定ファイルを確認 | `.claude/skills/i18n-key-check/check.sh app/views/shops/show.html.erb` |
| プロジェクト全体 | `.claude/skills/i18n-key-check/check.sh --all` |

ユーザーが `/i18n-key-check` と打ったら引数なし（diff モード）で実行する。

```bash
cd /Users/kasedashouta/develop/yomislo && .claude/skills/i18n-key-check/check.sh
```

## 検出ルール

| ID | 重要度 | 内容 |
|----|--------|------|
| missing-key | **FAIL** | `t(".key")` / `t("a.b.c")` の参照先が ja.yml に無い |
| orphan-key | WARN | ja.yml にあるが、コード側で誰も参照していない（`--all` 時のみ判定） |
| ja-only-en-missing | WARN | ja.yml にはあるが en.yml に対応キーが無い (en.yml が存在する場合のみ) |

## lazy lookup の解決ルール

`t(".foo")` をビューで使った場合、次の順で絶対パスに変換される:

- `app/views/shops/show.html.erb` の `t(".title")` → `shops.show.title`
- `app/views/shops/_machine_vote_row.html.erb` の `t(".label")` → `shops.machine_vote_row.label` (アンダースコア先頭は drop)
- `app/controllers/shops_controller.rb` の `t(".created")` → `shops.created`

このスキルでは ruby スクリプトを使い、上記ルールで lazy lookup を展開してから照合する。

## 出力フォーマット

```
🌐 i18n-key-check
  ❌ app/views/shops/show.html.erb
     [missing-key] L42: t(".empty_state") → shops.show.empty_state が ja.yml に無い
  ✅ app/views/home/index.html.erb
```

FAIL があれば exit 1、WARN のみなら exit 0。

## 仕組み

1. 対象ファイルから `t\(\s*["']\.?[a-zA-Z0-9_.]+["']` を全て抽出
2. lazy lookup なら呼び出し元ファイルパスから絶対パスに展開
3. `config/locales/ja.yml` を YAML としてロード、ネスト辿って存在確認
4. 欠落をレポート

依存: `ruby` (Rails 環境なので必ずある) と `yaml` 標準ライブラリ。

## 関連

- `copy-reviewer` サブエージェント — 文体チェック (担当が違うのでこちらは欠落のみ)
- DESIGN.md — UI 用語の指針
