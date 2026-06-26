---
name: activeadmin-check
description: >
  ActiveAdmin 4 (4.0.0.beta22) のリソース追加・編集時に踏みやすい8つの落とし穴を
  自動検出する。authenticate include / Ransack allowlist / I18n / enum prefix /
  slug finder / breadcrumb / Accept ヘッダ / check_boxes バグ。
  Use proactively when:
  - app/admin/*.rb を新規作成・編集した
  - config/initializers/active_admin*.rb / config/initializers/active_admin_breadcrumb.rb を編集した
  - 「ActiveAdmin」「admin リソース追加」「/admin で 500」「Ransack エラー」と発言された
  - ActiveAdmin gem の major/minor バージョンを上げた
  Use when ユーザーが「activeadmin-check」「AAチェック」「admin リソース確認」を依頼したとき。
---

# ActiveAdmin 4 リソースチェック

`a7e5cb2` での AA3→AA4 アップグレード時に踏んだ実害 8 件を、新規 admin リソース追加時に再発させないためのチェックリスト。grep ベースの自動検出と、目視確認項目を組み合わせる。

## 使い方

| シーン | コマンド |
|--------|----------|
| 現在の git diff （admin関連）を確認 | `.claude/skills/activeadmin-check/check.sh` |
| 特定リソースを確認 | `.claude/skills/activeadmin-check/check.sh app/admin/promotions.rb` |
| 全admin リソースを確認 | `.claude/skills/activeadmin-check/check.sh --all` |

ユーザーが `/activeadmin-check` と打ったら引数なしで diff モード。

```bash
cd /Users/kasedashouta/develop/yomislo && .claude/skills/activeadmin-check/check.sh
```

## 8 チェック項目（[[feedback-activeadmin-4-migration]] 由来）

### 自動検出可能（check.sh で実装）

| ID | 重要度 | 内容 |
|----|--------|------|
| auth-include | **FAIL** | `ApplicationController` が `include AdminAuthentication` を持っているか |
| ransack-allowlist | WARN | 新規モデルが `ApplicationRecord` を継承している（= デフォルト allowlist 経由）か |
| enum-prefix-scope | **FAIL** | `app/admin/*.rb` の `scope :name, default: true` が、モデル側 `enum :col, {...}, prefix: :p` の prefix と合っているか |
| slug-finder | WARN | `to_param` で slug 返すモデル（Shop/MachineModel）の admin リソースに `find_resource` override があるか |
| array-column-setter | **FAIL** | `as: :check_boxes` を使う属性（配列カラム）のモデルセッターに `Array(value).reject(&:blank?)` 正規化があるか |
| i18n-keys | WARN | `config/locales/ja.yml` に必須キー（`date.formats.default`, `time.formats.default`, `date.day_names`, `time.am`/`pm` 等）が揃っているか |

### 目視確認項目（Claude が報告で促す）

| ID | 内容 |
|----|------|
| breadcrumb-slug | `config/initializers/active_admin_breadcrumb.rb` で slug フォールバックが定義されているか（gem autoload 順序トラップあり、initializer 経由が正解） |
| curl-accept-html | admin 動作を curl で確認するときは `-H "Accept: text/html"` を必ず付ける（AA4 は `restrict_download_format_access!` がデフォルト有効、`*/*` だと 302 リダイレクト） |

## 結果の読み方

- ✅ **違反なし**: そのまま OK
- ⚠️ **WARN**: 文脈次第。新リソースが SENSITIVE 属性を持つなら手動 allowlist 必要、など
- ❌ **FAIL**: 修正必須（500 が出る or データが黙って壊れる）

## ユーザーへの報告フォーマット

```
## activeadmin-check 結果

| カテゴリ | 件数 | 状態 |
|---------|------|------|
| FAIL    | 0    | ✅ |
| WARN    | 1    | ⚠️ |

### 詳細
- `slug-finder`: app/admin/shops.rb
  → Shop は `to_param` で slug を返すが find_resource override なし。
    slug URL で /admin/shops/<slug> を開くと RecordNotFound

### 目視確認
- [ ] config/locales/ja.yml に必須 I18n キー一式
- [ ] curl で admin 確認時は `-H "Accept: text/html"`
- [ ] config/initializers/active_admin_breadcrumb.rb の slug フォールバック健在

**結論**: ✅ FAIL なし / ⚠️ 要確認 1 件
```

## 限界

- enum prefix 検出は正規表現ベース。複数行にまたがる enum 定義（`enum :status do ... end` ブロック形式）は誤検知の可能性
- Ransack allowlist は `ApplicationRecord` 継承の有無のみで判断。`SENSITIVE_RANSACK_ATTRIBUTES` を新規に増やすべきケース（token系・password系カラム追加時）は目視必要
- AA4 のさらなる beta バージョン更新で API が変わる可能性

## 関連

- [[feedback-activeadmin-4-migration]] — 8チェックの実害コンテキスト
- [[project-promotions-runtime]] — check_boxes バグの実例（Promotion#slot_keys）
- [[feedback-hotwire-array-params]] — 配列カラム代入の他系統落とし穴
