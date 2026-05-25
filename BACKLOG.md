# ヨミスロ BACKLOG

実装済みの機能改善・調査タスクを積んでおくバックログ。優先度や着手予定は項目ごとに決める。
作業着手時は GitHub Issue 化するか、直接ブランチ切って進める。

## 目次

- [UI / UX](#ui--ux)
- [検索 / 発見性](#検索--発見性)
- [機能追加・検討](#機能追加検討)
- [バグ調査](#バグ調査)
- [広告 / 収益化](#広告--収益化)
- [インフラ / 運用](#インフラ--運用)
- [このセッションでの残課題](#このセッションでの残課題)

---

## UI / UX

### UI・UX 全体の見直し・改修
現状ベタ書きのコンポーネントが多いため、サーフェス階層・余白・カラートークン使用の一貫性を再点検する。DESIGN.md と照合してズレを潰す。

### 細かいテキストの文章検討
プレースホルダー、空状態、エラーメッセージ、ボタンラベルなどのマイクロコピーを横断レビュー。AIっぽい硬さが残っている箇所を絞る（[feedback_copywriting] 参照）。

### ロゴ・キャッチコピーの再検討
現ヒーローキャッチ「みんなの記録で設定が見えてくる」「勝負の1台を記録しよう」等の時間帯切替バリエーションも含めて再評価。ロゴは現在のピクセル風で続けるかも要検討。

### AI 全体レビュー
- DESIGN.md 違反箇所の自動検出（`design-check` skill 活用）
- 重複コード、過剰抽象、デッドコードの洗い出し
- N+1、不要 JS、巨大 view の特定

---

## 検索 / 発見性

### 検索にひっかかりやすい・ユーザーに探しだしてもらう工夫
SEO 観点。
- meta タグ、構造化データ (LocalBusiness / WebSite / SearchAction) の網羅性
- サイトマップ生成と Google Search Console 登録
- パンくず構造
- 店舗・機種ページのタイトル / description テンプレート最適化

### 検索メニューで都道府県が必要か、設備・サービスの詳細項目は適切かの検討
現在の検索 UI（都道府県セレクター・設備チェックボックス）が打ち手にとって本当に使いやすいか。
- 都道府県を地図ベースに変えるか
- 設備フィルタは「全て表示」か「絞り込み主軸の3-5項目」か
- ユーザーテスト or 分析データで判断

### 「現在地から探す」にて期待する全店舗が探しきれていない問題【原因特定済 2026-05-22】

**原因**: `lat`/`lng` が NULL の店舗が **347 件**（全6,053店の5.7%）存在し、`ShopsController#nearby_query` の `where.not(lat: nil).where.not(lng: nil)` で完全除外されている。さらに 1,030 件が `precision=0`（住所部分一致）で `@imprecise_shops` 側に落ちている。

**根本原因**: `rake geocode:shops` (`lib/tasks/geocode.rake`, GSI primary + Nominatim fallback) が**どの cron にも組み込まれていない**。DMMぱちタウンの JSON-LD に `geo` 情報がある店舗だけ自動で座標が入り、それ以外は手動 rake 実行待ち。新店舗が DMM 側で増えるたび穴が拡大する。

**修正方針（優先度順）**:
1. **即時**: 本番 Web Shell から `bundle exec rake geocode:shops RAILS_ENV=production` を1回実行（347件 × 1.5秒 = 約9分）
   - 熊本だけなら `rake geocode:shops[kumamoto]` で4件、6秒
2. **恒久**: `render.yaml` の `yomislo-daily-refresh` start command 末尾に `geocode:shops` を連結、または `DailyMachineRefreshJob` 内で geocode 呼び出し
3. **精度改善**: `precision=0` の 1,030 件に対し `rake geocode:fix_imprecise` を別途実行
4. **UI改善**: 検索半径 10km 固定 → 20km/50km 切替、`@imprecise_shops` の見せ方再検討
5. **長期**: PostGIS 化 + 空間インデックス（GIST）で距離計算高速化

**再現例**: ベルエアマックス北部店（熊本県熊本市北区四方寄町1666）
- 現状: id=8742, lat=NULL, lng=NULL, precision=0, last_synced_at=2026-05-21
- GSI API 実測値: **lat=32.859932, lng=130.708618**（precision=3）
- 修正SQL: `UPDATE shops SET lat=32.859932, lng=130.708618, geocode_precision=3 WHERE id=8742;`

**熊本県内の同症状店舗（全4件）**: id=8742 ベルエアマックス北部店 / id=8384 テンガイ戸島店 / id=8394 パムズ 甲佐 / id=8383 パムズ県庁東

**修正実績（2026-05-25 本番Shellで `rake geocode:shops` 実行）**:
- 347件中 346件成功、1件失敗（ラカータ大宮駅前店）
- lat/lng NULL の店舗: 347 → **1**
- precision≥2 の高精度店舗: 4,302 → **4,622**（+320）
- ベルエアマックス北部店 ✅ lat=32.8599320, lng=130.7086180, precision=3

### 派生バグ: 住所末尾の `...` truncation（388件）【新規発見 2026-05-25】

DMMぱちタウンのスクレイピング時、`shops.address` が末尾 `...` で切れて DB に保存されている店舗が **388件** 存在。
例: ラカータ大宮駅前店 (id=7690) の address = `"埼玉県さいたま市大宮区桜木町1-4..."` (20文字で切れている)。

**影響**:
- GSI ジオコーディングで「unexpected end of input」エラーになる（GSIは `...` を含む末尾を正しくパースできない場合がある）
- precision が下がる、もしくは座標取得失敗

**修正方針**:
1. **即時**: `lib/tasks/geocode.rake` の `geocode_with_gsi` / `geocode_with_nominatim` で、API呼び出し前に末尾 `...` を strip するワンライナー追加
   ```ruby
   address = address.to_s.gsub(/[.。…]+$/, '').strip
   ```
2. **根本**: `PtownScraper#parse_shop_detail` で住所を取得している箇所を確認し、なぜ truncate されているかを調査（JSON-LD の `address.streetAddress` を直接見ているなら、別セレクタを試す）

**ラカータ大宮駅前店 個別修正用SQL**（本番Rails consoleから）:
```ruby
Shop.find(7690).update_columns(lat: 35.904591, lng: 139.623001, geocode_precision: 3)
```

---

## 機能追加・検討

### ユーザーに名前設定機能の検討
現状 voter_token (`#efba`等) で匿名識別。
- 表示名を任意で設定できる機能を追加するか
- ランキング・コメント表示でどう影響するか
- 既存の VoterProfile.display_name との関係整理

### ランキングメニューはあくまで補助のお楽しみ機能として目立たせない検討
記録 UI が本筋。ランキングを前面に出しすぎると「ゲーミフィケーション目的の投稿」を誘発し、データ品質が落ちるリスク。
- ナビ位置・配色の優先度を下げる
- ホームでの露出を縮小する
- ただし投稿動機としては有効なのでバランス調整

---

## バグ調査

### 細かい部分のバグ調査
レポート未取得の細かいバグを洗い出すフェーズ。
- ブラウザコンソールのエラー監視
- Sentry / Honeybadger 導入検討
- 投稿フローのエッジケース（同日複数投稿、Cookie削除後の再投票）
- モバイル特有の挙動（タップ範囲、SafariのCookie）

---

## 広告 / 収益化

### 広告の位置検討
現状 7 スロット定義済み (`Promotion::SLOT_KEYS`)。実運用してから:
- クリック率の高い位置を実測して残し、低い位置は削除
- in-feed (vote rows 隣接) は禁止だが、別の自然な位置に追加余地ないか
- モバイルでの表示頻度・スクロール深度との関係を分析

### 現実的な収益化プランをたてる（インフラ費用も考える）
月間 PV と RPM の見積もりからインフラコストの黒字化ラインを算出。
- 現在のインフラ費用: 月 $28〜35（Render Singapore × 4 services + DB）
- 損益分岐 PV を計算
- 90日後の Postgres 課金開始も折り込む
- ASP 案件別の期待 EPC を試算
- 必要なら Render → 安価 VPS (Lightsail Tokyo + Kamal) への移行コスト試算

---

## インフラ / 運用

### 🔥 Postgres Free プラン → 有料プラン移行【期限 2026-06-18】
作成から30日でDB自動削除されるため期限前に必ず移行。
- 現状: `yomislo-db` (dpg-d863th5ckfvc73ec2t3g-a) Free / Singapore / v18
- 候補プラン:
  - Basic $7/mo（1GB RAM, HA無し） — 個人サイト初期はこれで十分
  - Standard $19/mo（4GB RAM, HA有り） — トラフィック増えてから
- 手順:
  1. `mcp__render__create_postgres` で新インスタンス作成（同region Singapore、v18）
  2. `pg_dump` で旧DB → `pg_restore` で新DBへ
  3. `DATABASE_URL` env を新DBに切替
  4. Web + Cron 全部の動作確認
  5. 旧Free DB削除
- 詳細手順: `project_render_deploy.md` 参照

### Puma cluster mode 警告解消
本番ログに `WARNING: Detected running cluster mode with 1 worker.` が出続けている。
- `config/puma.rb` で `workers ENV.fetch("WEB_CONCURRENCY", 0).to_i` に変更（worker=0でsingle mode化）
- もしくは `silence_single_worker_warning` フラグを追加して警告だけ抑制
- Starter plan は 512MB なので workers増やすメリットは薄い → single mode 推奨

### エラー監視の導入
現状、本番でエラーが起きても気づく手段がない（Renderダッシュボードのログを能動的に見るだけ）。
- 候補: Sentry（無料枠5k errors/月）, Honeybadger, Bugsnag
- 通知先: Discord webhook or メール
- Rails 8 / Ruby 4.0 互換性要確認

### HTTP リクエスト計測の確認
`mcp__render__get_metrics` で直近1時間のリクエスト数が全て0だった。
- 本当にトラフィックゼロか、`/up` ヘルスチェックが除外されているだけか
- Google Analytics or 軽量アクセス解析（Plausible, Umami）の導入検討

### Render リージョンの再検討
現在 Singapore region。日本ユーザー向けには Tokyo が理想だが Render はまだ未対応。
- レイテンシ実測（Singapore → 日本: 70-100ms 程度）
- 将来的に Render Tokyo 開設されたら移行、もしくは Lightsail Tokyo / Cloudflare Workers 等の検討

---

## このセッションでの残課題

### ASP 本格登録 → 3 案件再アクティブ化
現在 INACTIVE の楽天カード / SBI証券 / U-NEXT を本番有効化。
- A8.net 登録（サイトURL `https://yomislo.onrender.com` で申請）
- もしもアフィリエイト登録
- バリューコマース登録（楽天カード独占案件のため）
- 各案件の提携申請 → 承認 → アフィリエイトURL取得
- ActiveAdmin から `target_url` 更新 + `active: true` に戻し

### 特商法ページ運営者情報の placeholder 実名化
`/legal/tokushou` は現在「請求があった場合に遅滞なく開示」方式。金融系案件（楽天カード、SBI証券）取扱開始時に実名・所在地表記に切り替え必要。バリューコマース等は審査でこの記載を見る。

### モッピー・ハピタス紹介報酬監視
管理画面（モッピー・ハピタス側）に時々ログインして紹介経由の登録があるか確認。
- 最初の数件は誰が踏んだかすぐ分かる
- ペースが立ち上がってきたら通知設定検討

### 並行作業中の未コミット差分の整理
本セッション期間中、ユーザー並行作業の修正がいくつか同期されているが、当方で差分内容を未把握:
- `app/views/search/index.html.erb` の変更
- その他の積み残し
次セッション開始時に `git log` を眺めて状況把握する

---

## メタ

- 作成: 2026-05-21
- 最終更新: 2026-05-22（Render本番状況調査 → インフラ/運用セクション追加、現在地検索バグの再現例追加）
- 関連メモリ: `feedback_activeadmin_4_migration.md` §8、`project_render_deploy.md`、`project_promotions_runtime.md`、`project_asp_compliance.md`
