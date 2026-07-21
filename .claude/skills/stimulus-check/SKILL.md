---
name: stimulus-check
description: >
  Stimulus コントローラの命名・登録・data 属性整合性をチェック。
  data-controller 名と *_controller.js のファイル名対応、
  targets/values/classes の宣言と HTML 側の data-*-target/data-*-value/data-*-class 属性の齟齬、
  イベントアクション (data-action) のメソッド未定義、controllers/index.js への登録漏れ (該当時) を検出する。
  Use proactively when app/javascript/controllers/*.js を追加・変更したとき、
  app/views/**/*.erb で data-controller / data-*-target / data-action を追加・変更したとき。
  Use when ユーザーが「stimulus-check」「Stimulus整合性チェック」を依頼したとき。
---

# Stimulus Check

Stimulus コントローラと HTML 側 `data-*` 属性の整合性を静的検査するスキル。
本番で `console.warn: Element has undefined target` や `Missing controller` を出さないための守り。

## 使い方

| シーン | コマンド |
|--------|----------|
| 現在の git diff から自動検出（既定） | `.claude/skills/stimulus-check/check.sh` |
| 特定コントローラを対象 | `.claude/skills/stimulus-check/check.sh app/javascript/controllers/vote_controller.js` |
| 特定ビューを対象 | `.claude/skills/stimulus-check/check.sh app/views/shops/show.html.erb` |
| 全コントローラ横断 | `.claude/skills/stimulus-check/check.sh --all` |

ユーザーが `/stimulus-check` と打ったら、引数なしで diff モードで実行する。

```bash
cd /Users/kasedashouta/develop/yomislo && .claude/skills/stimulus-check/check.sh
```

## 前提: 登録機構

`app/javascript/controllers/index.js` は `eagerLoadControllersFrom("controllers", application)` で
`app/javascript/controllers/*_controller.js` を自動登録する。手動 `application.register` は無い。
したがって以下が命名規則で決まる:

- `foo_bar_controller.js` の中身 `export default class extends Controller` は `data-controller="foo-bar"` で読み出される
- underscore を hyphen に変換する Stimulus 標準変換に従う

## 検出ルール

| ID | 重要度 | 内容 |
|----|--------|------|
| filename-mismatch | **FAIL** | `*_controller.js` の suffix を持たないコントローラファイル |
| unknown-controller | **FAIL** | `data-controller="foo"` で参照されているが `foo_controller.js` が存在しない |
| unused-controller | WARN | `*_controller.js` が存在するが `data-controller` から一度も参照されていない |
| undeclared-target | **FAIL** | `data-foo-target="bar"` に対し `foo_controller.js` の `static targets = [...]` に `"bar"` が無い |
| undeclared-value | **FAIL** | `data-foo-bar-value="..."` に対し `static values = { ... }` の宣言が無い |
| undeclared-class | **FAIL** | `data-foo-bar-class="..."` に対し `static classes = [...]` の宣言が無い |
| unresolved-action | WARN | `data-action="click->foo#doSomething"` のメソッドが `foo_controller.js` に存在しない |
| deprecated-target-syntax | WARN | `data-target="foo.bar"` (旧構文)。`data-foo-target="bar"` (新構文) に統一 |

## 結果の読み方

- ✅ **違反なし**: OK
- ⚠️ **WARN**: 状況次第。動的に `Controller#find` で参照している場合など誤検知の可能性
- ❌ **FAIL**: 修正必須（本番で機能しない可能性）

## ユーザーへの報告フォーマット

```
## stimulus-check 結果

| カテゴリ | 件数 | 状態 |
|---------|------|------|
| FAIL    | 0    | ✅ |
| WARN    | 1    | ⚠️ |

### 詳細
- `undeclared-target`: app/views/shops/show.html.erb
  → data-vote-target="button" が参照されているが vote_controller.js の
    static targets に "button" が無い

**結論**: ✅ FAIL なし / ⚠️ 要確認 1 件
```

## 限界

- ERB ヘルパー経由 (`stimulus_controller("vote")` のような helper) の動的組み立ては検出不可
- data 属性を JS 側で動的に付与する場合（play_record_form_controller など）は false positive
- 継承 (`extends OtherController`) の targets/values は追跡しない

## 関連

- [[feedback_hotwire_array_params.md]] — Hotwire 動的フォームの落とし穴（参考）
- [hotwire-form-check] — 動的 name/id 組み立ての検査（役割分担: form 系はあちら）
