---
name: promotion-placement
description: >
  ASP アフィリエイト広告（render_promotion）の配置ルールを自動検証する。
  既知スロットキーのみ・1ページ2枠まで・Turbo Frame内禁止・rel/target/PR ラベル必須、
  ENV ガード（PROMOTIONS_ENABLED）の存在を確認。
  Use proactively when:
  - app/views/**/*.erb で render_promotion を追加・変更・削除した
  - app/helpers/promotions_helper.rb / app/models/promotion.rb / app/views/shared/_promotion_*.erb を編集した
  - Promotion 関連の ActiveAdmin (app/admin/promotions.rb) を編集した
  - 新しい広告スロットを追加しようとしている
  - ユーザーが「promotion-placement」「広告配置チェック」「広告レビュー」「PR タグ確認」と依頼した
---

# Promotion Placement

ヨミスロのアフィリエイト広告枠（`render_promotion`）の配置規約チェック。
ASP案件のキュレーション運用で守るべきルールを自動検証する。

## 規約（CLAUDE.md 由来）

| ルール | 詳細 |
|--------|------|
| 既知スロットのみ | 7スロット以外の `slot_key` は使わない |
| 1ページ最大2枠 | 同一ファイル内の `render_promotion` 呼び出しは 2 個まで |
| Turbo Frame 内禁止 | `turbo_frame_tag do ... end` および `<turbo-frame>` 内に置かない（再描画でASP計測が暴れる） |
| `rel="sponsored noopener"` 必須 | 景表法・特商法・Google推奨 |
| `target="_blank"` 必須 | 外部ASPサイトへ新規タブで遷移 |
| 「PR」ラベル必須 | ユーザーに広告と明示 |
| ENV ガード | `PROMOTIONS_ENABLED=true` の時のみ描画。promotions_helper.rb で判定 |

## 既知スロット一覧（CLAUDE.md と一致させる）

| slot_key | variant | 配置 |
|----------|---------|------|
| `home_hero` | banner | ホーム ヒーロー直下 |
| `home_zone_split` | card | ホーム Zone A 末尾 |
| `shop_detail_top` | banner | 店舗詳細 ヘッダー下 |
| `shop_detail_bottom` | card | 店舗詳細 機種リスト末尾 |
| `machine_detail` | banner | 機種詳細 スペック下・設置店舗前 |
| `voter_status` | card | マイステータス 履歴上 |
| `rankings_top` | banner | ランキング テーブル上 |

## 使い方

```bash
cd /Users/kasedashouta/Desktop/develop/yomislo && ruby .claude/skills/promotion-placement/check.rb
```

ユーザーが `/promotion-placement` と打ったら上記コマンドを実行する。
スクレイピングと違いネットワーク不要・数秒で完了。

## 出力例

```
=== promotion-placement ===

実装済みスロット: 7 箇所 / 既知 7 スロット

✅ 違反なし
```

問題があれば:
```
❌ FAIL 2 件:
  - [unknown-slot] app/views/shops/show.html.erb:79 未定義スロット :shop_top
  - [in-frame] app/views/shops/_machine_vote_row.html.erb:42 render_promotion が Turbo Frame 内にある
⚠️  WARN 1 件:
  - [wrong-variant] app/views/home/index.html.erb:37 :home_hero は variant: :banner 推奨（現状 :card）
```

## 検出ロジック

`check.rb` 内のロジック:

1. `app/views/**/*.erb` を全走査して `render_promotion :slot, variant: :v` を抽出
2. `ALLOWED_SLOTS` テーブルと突合（未知スロット / variantミスマッチ）
3. ファイル単位で件数カウント（>2でFAIL）
4. `turbo_frame_tag do ... end` / `<turbo-frame>` の開閉を行番号で追跡、内包する `render_promotion` を検出
5. `app/views/shared/_promotion_banner.html.erb` / `_promotion_card.html.erb` の `sponsored` / `target="_blank"` / `PR` 表記を検証
6. `promotions_helper.rb` の `PROMOTIONS_ENABLED` 判定の存在確認
7. 未実装スロットを Note 出力

## 限界

- Turbo Frame の検出は erb の単純行マッチ。条件分岐内のフレームは取れない場合あり
- Variant ミスマッチは推奨値とのズレを WARN にしている（FAIL ではない）
- 1ページ2枠の判定は同一ファイル単位。`render :partial` 経由で別ファイルから挿入されている場合は別計算

## メンテナンス

スロットを追加・廃止する場合は以下を**同期更新**:
1. [CLAUDE.md](../../../CLAUDE.md) のスロット一覧
2. このスキルの `ALLOWED_SLOTS` 定数（`check.rb` 内）
3. `app/models/promotion.rb` の `slot_keys` バリデーション（あれば）

## 関連

- [CLAUDE.md](../../../CLAUDE.md) — 配置ルール本体
- [app/helpers/promotions_helper.rb](../../../app/helpers/promotions_helper.rb)
- [app/views/shared/_promotion_banner.html.erb](../../../app/views/shared/_promotion_banner.html.erb)
- [app/views/shared/_promotion_card.html.erb](../../../app/views/shared/_promotion_card.html.erb)
