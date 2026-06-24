# ヨミスロ - プロジェクトガイド

## プロジェクト概要
パチスロの設定・リセット情報を匿名ワンタップ記録で集め、集合知として可視化するCGMサイト。

## 技術スタック
- **Ruby 4.0.0** / **Rails 8.0.4** / **PostgreSQL 17**
- Hotwire (Turbo + Stimulus) / Tailwind CSS v4
- Devise (管理者認証のみ) / ActiveAdmin
- pg_search / kaminari / rack-attack / meta-tags / sitemap_generator
- RSpec + FactoryBot + Faker
- デプロイ先: **Render.com（本番運用中: https://yomislo.onrender.com ）**

## 環境セットアップ
```bash
export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"
brew services start postgresql@17
bundle install
bin/rails db:create db:migrate db:seed
bin/dev  # サーバー起動 (Tailwind watch + Rails)
```

## 重要な設計判断
- **ログイン不要**: 公開機能は全て匿名。Cookie (`voter_token`) で重複記録防止
- **管理者のみDevise**: `/admin` へのアクセスのみログイン必須
- **コンテナ不要**: Docker/Kamal削除済み。Render.comにGit直接デプロイ
- **1人1日1店舗1機種1件**: `voter_token + shop_id + machine_model_id + voted_on` でユニーク制約

## データソース
**DMMぱちタウン (https://p-town.dmm.com) に一本化**。P-WORLDは廃止済み。

| データ | ソース | タスク | 頻度 |
|--------|--------|--------|------|
| 機種マスタ | DMMぱちタウン | `ptown:import_machines` + `ptown:import_details` | 日次 |
| 店舗マスタ | DMMぱちタウン | `ptown:import_shops` | 月次 |
| 設置機種 + 台数 + 店舗詳細 | DMMぱちタウン | `ptown:sync_shop_machines` | 日次 |
| 交換率 | ユーザー投稿 | （未実装） | リアルタイム |
| ランキング・集計 | 内部計算 | `ranking:refresh` / `play_records:refresh_summaries` | 日次 |

## 主要モデル
| モデル | 概要 |
|--------|------|
| Prefecture | 47都道府県 (seed) |
| Shop | 店舗 (DMMぱちタウンから取得。ptown_shop_id必須。設備フラグ: wifi_available/charging_available/heated_tobacco_ok/slot_smoking_ok/low_rate_slot/data_publishing/okislot/ticket_distribution、入場: entry_method、メタ: facility_parsed_at) |
| MachineModel | パチスロ機種 (DMMぱちタウンから取得。ptown_id必須。ceiling_info, reset_info, image_url等) |
| ShopMachineModel | 店舗×機種の設置紐づけ (N:N中間テーブル、unit_count付き) |
| Vote | 設定記録 (voter_tokenで匿名識別。confirmed_setting配列あり) |
| VoteSummary | 記録集計キャッシュ (Vote保存時に自動更新) |
| SnsReport | SNS/RSS自動収集データ (トロフィー・確定演出情報、日次バッチ停止中) |
| VoterProfile | ユーザープロフィールキャッシュ (称号・ストリーク・的中率) |
| VoterRanking | ランキング集計キャッシュ (週間/月間/累計×全国/県別) |
| PlayRecord | 収支記録 (voter_token, shop, machine_model, result_amount, tags) |
| PlayRecordSummary | 収支集計キャッシュ (機種別/店舗別/県別 × 月次/累計) |
| Feedback | ユーザー要望・不具合報告 |
| Comment | コメント (匿名、commenter_name任意) |
| Report | 通報 |
| Promotion | おすすめ案件（アフィリエイト広告枠、ActiveAdmin管理） |

## 重要ファイル
- `app/views/shops/show.html.erb` — 最重要ページ（記録UI）
- `app/views/shops/_machine_vote_row.html.erb` — Turbo Frame記録行
- `app/views/home/index.html.erb` — ホームページ（ヒーロー+統計+ランキング+オンボーディング）
- `app/controllers/votes_controller.rb` — 記録ロジック（リセット/設定を個別マージ）
- `app/models/vote_summary.rb` — `refresh_for` で集計更新
- `app/models/voter_profile.rb` — 称号・ストリーク・的中率の算出
- `app/models/voter_ranking.rb` — 週間/月間/累計ランキング集計
- `app/controllers/play_records_controller.rb` — 収支記録CRUD
- `app/controllers/rankings_controller.rb` — ランキング表示
- `app/views/voter/status.html.erb` — マイステータス（称号・ストリーク・収支）
- `config/initializers/rack_attack.rb` — レート制限

## Seed管理者
- email: admin@example.com / password: password

## Git
- リポジトリ: https://github.com/pocopoco1107/yomislo (Private)
- ローカルgit user: pocopoco1107 (--local設定)
- グローバルgit (shota-kaseda) はこのプロジェクトでは使わない

## Stimulusコントローラ
| コントローラ | 機能 |
|-------------|------|
| vote | 記録ボタンの無効化+pulseアニメーション |
| accordion | 都道府県地域の開閉 |
| favorite | 店舗お気に入りトグル (localStorage) |
| favorites-list | ホームでお気に入り店舗一覧表示 |
| machine-filter | 店舗ページの機種名絞り込み + 県ページの店舗名絞り込み（市区町村グループ対応） |
| machine-search | 店舗ページで機種検索→記録行追加 |
| dismissable | アラート等の非表示 |
| nearby | 近隣店舗の位置情報取得・表示 |
| trend-tab | トレンドデータのタブ切替 |
| shop-filter | 全国検索ページのフィルタUI |
| machine-shop-filter | 機種ページの設置店舗フィルタ |
| star-rating | レビュー星評価入力UI |
| theme | ダークモード切替 |
| carousel | カルーセル表示 |
| mobile-nav | モバイルナビゲーションメニュー |
| calendar | 収支カレンダーの日セル選択ハイライト |
| play-record-form | 収支入力フォームの簡易/詳細モード切替 |
| tag-select | タグチップ選択トグル (hidden input同期) |
| result-input | 収支額±切替UI |
| ranking-tab | ランキング期間/スコープ切替 (Turbo navigation) |
| hero-search | ホームの店舗名/機種名ライブ検索 (インクリメンタル候補表示) |
| shop-autocomplete | 収支記録モーダルの店舗名オートコンプリート (/shops/autocomplete) |
| record-modal | 収支カレンダーの記録モーダル開閉 (日付指定/今日) |
| auto-submit | select変更で親formを自動submit (機種詳細の設置店舗 県フィルタ等) |
| image-fallback | 機種画像の読み込み失敗時フォールバック |

## テスト
```bash
bundle exec rspec  # 533 examples, 0 failures, 72% coverage
```

## DMMぱちタウン スクレイピング設計
- **モジュール**: `PtownScraper` (`lib/tasks/ptown.rake`)
- **BASE_URL**: `https://p-town.dmm.com`
- **レート制限**: `sleep 3.0` (1リクエストあたり)
- **正規化**: `normalize_slug()` で NFKC正規化 + 空白→ハイフン + 記号除去 + downcase
- **core_name()**: 接頭辞(L/S/パチスロ/スマスロ等)・末尾型式コード除去で重複検出用
- **parse_shop_detail()**: JSON-LDから店舗基本情報 + #anc-slot セクションから機種リスト + `table.default-table` から設備情報
- **parse_basic_info_table()**: 設備/サービス/特徴/入場ルール/整理券のセルから boolean/enum を判定。FACILITY_KEYWORD_MAP 定数でキーワード管理、`keyword_present?` で否定形を排除
- **設備フラグの保持方針**: boolean は NULL 許容 (nil=未確認, true=あり, false=なし)。検索フィルタは `where(col: true)` で true のみ絞る。sync で nil を返した場合は既存値を維持（毎回上書きで消さない）

## Render.com 本番環境

### サービス構成
| 種別 | サービス名 | ID | プラン | リージョン |
|------|-----------|-----|--------|-----------|
| Web | `yomislo` | srv-d863tqlckfvc73ec34fg | Starter | Singapore |
| Cron | `yomislo-daily-refresh` | crn-d863tqlckfvc73ec34d0 | Starter | Singapore |
| Cron | `yomislo-daily-aggregation` | crn-d863tqlckfvc73ec34e0 | Starter | Singapore |
| Cron | `yomislo-monthly` | crn-d863tqlckfvc73ec34eg | Starter | Singapore |
| Postgres | `yomislo-db` (v18) | dpg-d863th5ckfvc73ec2t3g-a | Basic ($6/mo) | Singapore |

- Web URL: https://yomislo.onrender.com
- ヘルスチェック: `/up`
- auto-deploy: `main` ブランチ commit トリガー
- ビルド: `./bin/render-build.sh`、起動: `bundle exec puma -C config/puma.rb`
- ダッシュボード: https://dashboard.render.com/web/srv-d863tqlckfvc73ec34fg

### Postgres プラン
- 2026-06-22 に Free → Basic ($6/mo) へアップグレード済み
- 詳細運用は [project_render_deploy.md](/Users/kasedashouta/.claude/projects/-Users-kasedashouta-develop-yomislo/memory/project_render_deploy.md) 参照

### バッチスケジュール (render.yaml)
| cronジョブ | スケジュール(UTC) | start command | 内容 |
|-----------|------------------|---------------|------|
| `yomislo-daily-refresh` | 0 18 * * * | `rails runner "DailyMachineRefreshJob.perform_now"` | 機種マスタ + 全店設置機種同期 + lat/lng未取得店のgeocode + 孤立機種非アクティブ化 ~5h |
| `yomislo-daily-aggregation` | 0 19 * * * | `rails runner "VoterRanking.refresh_* + PlayRecordSummary.refresh_all! + VoterProfile.refresh_for"` | ランキング+収支+Profile (数秒) |
| `yomislo-monthly` | 0 18 1 * * | `rails runner "MonthlyShopDetailsJob.perform_now"` | 店舗マスタ + 機種詳細 + 設置機種フル同期 + 新規店geocode + cleanup ~5h |

- 毎月1日: daily-refresh はスキップ、monthly が代わりに実行
- recurring.yml は Solid Queue 無効のため参照用のみ

## Rakeタスク（ptown:）
| タスク | 説明 |
|--------|------|
| `import_machines` | DMMぱちタウンから機種一覧取得・更新 |
| `import_details` | DMMぱちタウンから機種詳細（天井・リセット・タイプ）取得 |
| `import_all` | 一覧→詳細の全取得 |
| `import_shops[slug]` | DMMぱちタウンから店舗一覧取得（都道府県別 or 全国） |
| `sync_shop_machines[slug]` | 設置機種+台数+店舗詳細+設備情報を同期（都道府県別 or 全国、`FORCE=1` で24h以内も再sync） |
| `sync_one_shop[ptown_shop_id]` | 1店舗だけ強制再sync (debug用) |
| `dump_facility_text[per_pref]` | 設備キーワードのサンプリングCSV出力 (`tmp/ptown_facility_dump.csv`) |
| `verify_parse_basic_info` | フィクスチャHTMLで parse_basic_info_table を実行 (debug) |
| `import_events[area]` | DMMぱちタウンからイベント情報取得（取材・新台入替等） |
| `merge_duplicates` | core_name一致で重複機種をマージ |
| `cleanup` | type_detail汚染修正、is_smart_slot補正、孤立機種の再アクティブ化 |
| `purge_pworld` | P-WORLD由来データの一括整理（ユーザーデータ移行→機種inactive化→店舗削除） |

## Rakeタスク（ranking: / play_records:）
| タスク | 説明 |
|--------|------|
| `ranking:refresh` | 記録ランキング全期間更新（週間/月間/累計） |
| `play_records:refresh_summaries` | 収支集計キャッシュ更新（機種別/店舗別/県別） |

## ユーザーの方針
- ログイン式にしない
- コンテナ管理不要
- 最新・トレンド技術を好む
- 破壊的操作は事前確認必須
- 会社アカウント (shota-kaseda / spice-factory) をこのプロジェクトで使わない

---

## データ品質ルール（毎回チェック必須）

### スクレイピング後の必須チェック
1. **重複チェック**: Unicode NFKC正規化 + `core_name()` で全角/半角・接頭辞の重複がないか
2. **件数の妥当性チェック**: 変更前後の件数を表示し、大幅な増減がないか確認
3. **パチンコ混入チェック**: `pachinko_name?` でパチンコ機種が混入していないか

### 既知のデータ制限
- **設置機種未掲載店舗**: DMMぱちタウン側で `#anc-slot` セクションがない店舗が約1,002件存在（パチンコ専門店・小規模店が中心）
- 確認クエリ:
  ```ruby
  Shop.where.not(ptown_shop_id: nil)
      .where.not(last_synced_at: nil)
      .left_joins(:shop_machine_models)
      .group('shops.id')
      .having('count(shop_machine_models.id) = 0')
  ```

### DMMぱちタウンスクレイピング規約
- レート制限: `sleep 3.0` (1リクエストあたり)
- User-Agent: 標準ブラウザUA使用
- Net::HTTP + Nokogiri
- **機種名正規化**: NFKC正規化必須。`core_name()` で接頭辞/末尾型式コード除去

## 動作確認・UI検証
- 実装や修正の後は **Claude Preview モード** (`preview_start` → `preview_snapshot` / `preview_screenshot` 等) で動作・UIを確認する
- ブラウザ操作ツール (Claude in Chrome) ではなく、必ず Preview ツール群を使うこと
- dev サーバー起動: `bin/dev`（ポート 3000）
- 確認手順: preview_start でサーバー起動 → preview_snapshot / preview_console_logs でエラー確認 → preview_screenshot で視覚確認 → 問題あればソース修正して再確認
- テスト (`bundle exec rspec`) は正確性の検証、Preview は実際のUI/UXの検証。両方やる

## UI/フロントエンド規約
→ **`DESIGN.md`** を参照（カラートークン、サーフェス、タイポグラフィ、コンポーネント、Do's/Don'ts）

### Hotwire パターン
- 記録UI: Turbo Frame (`<turbo-frame id="vote_...">`) で部分更新
- 開閉UI: Stimulus `accordion` コントローラ
- お気に入り: localStorage + Stimulus `favorite` / `favorites-list`
- フィルタ: Stimulus `machine-filter` コントローラ

### 広告（おすすめ案件キュレーション）

- ASP アフィリエイト案件を自社キュレーションして「おすすめ」として掲載。AdSense は採用しない（パチスロ系は配信品質・BANリスクの面で不向き）
- モデル: `Promotion`（title / description / image_url / target_url / category / slot_keys / priority / active）
- 管理: ActiveAdmin `/admin/promotions`
- 表示制御: `ENV['PROMOTIONS_ENABLED']` が `"true"` の場合のみ描画。未設定/false なら全スロットで何も出ない
- 描画: `<%= render_promotion :slot_key, variant: :banner | :card %>`（[app/helpers/promotions_helper.rb](app/helpers/promotions_helper.rb)）
- スロット一覧（実装と一致させること）:
  - `home_hero` (banner) — ホーム ヒーロー直下
  - `home_zone_split` (card) — ホーム Zone A 末尾
  - `shop_detail_top` (banner) — 店舗詳細 ヘッダー下
  - `shop_detail_bottom` (card) — 店舗詳細 機種リスト末尾
  - `machine_detail` (banner) — 機種詳細 スペック下・設置店舗前
  - `voter_status` (card) — マイステータス 履歴上
  - `rankings_top` (banner) — ランキング テーブル上
- 配置ルール: 1ページ最大2枠、リスト前後・セクション境界のみ。**in-feed（機種リスト中・vote row 隣接）禁止**（記録動線阻害回避）
- リンクは `target="_blank" rel="sponsored noopener"` 必須（景表法・特商法・Google推奨）。右上に「PR」ラベル必須
- Turbo Frame 内には絶対に置かない（再描画でASP計測が暴れる）

## Rakeタスク命名規約
- namespace: `ptown:`
- 都道府県指定: `rake ptown:task_name[prefecture_slug]`
- 全国一括: `rake ptown:task_name` (引数なし)
- 進捗表示: `puts "#{index}/#{total} ..."` 形式

---

## Claude スキル / Hook 一覧

プロジェクト固有の自動化が `.claude/` 配下に揃っている。Claudeは文脈に応じて自動で呼ぶこと。

### スキル（`.claude/skills/`）

| スキル | 自動呼び出しトリガー |
|--------|-------------------|
| `scraping-verify` | rake ptown:* の直前/直後（Hook で snapshot 自動化済み） |
| `data-check` | 「データチェック」「件数確認」「DB状況」「機種何件？」等の質問 |
| `design-check` | .erb / .css / .html 編集の直後（Hook で自動実行済み） |
| `promotion-placement` | render_promotion を含むファイル、Promotion 関連の編集 |
| `before-deploy-render` | git push 直前、render.yaml/migration 編集、「デプロイする」発言 |
| `wrap-up` | 「振り返り」「まとめ」「終わり」 |
| `handoff` | 「引き継ぎ」「ハンドオフ」「新セッション」発言 or 会話の散らかり兆候を自動検出 |

### サブエージェント（`.claude/agents/`）

| エージェント | 呼ぶタイミング |
|-------------|-------------|
| `scraping-reviewer` | lib/tasks/ptown.rake / pworld_supplement.rake / PtownScraper 編集後 |
| `copy-reviewer` | app/views/*.erb / config/locales/*.yml の文言追加・変更 |

### Hooks（`.claude/hooks/`）— 自動実行

| Hook | 動作 |
|------|------|
| block-secrets | .env / config/master.key / credentials.yml.enc 編集をブロック |
| rubocop-on-save | .rb 編集後に `bundle exec rubocop -a` 自動実行 |
| auto-scraping-snapshot | `rake ptown:*` 実行前に scraping-verify snapshot を自動取得 |
| auto-design-check | .erb / .html / .css 編集後に design-check を実行（違反時のみ通知） |
