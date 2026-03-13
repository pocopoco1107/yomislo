# ヨミスロ サービス仕様書

## 1. サービス概要

### コンセプト
パチスロの設定・リセット情報を**匿名ワンタップ記録**で集め、集合知として蓄積する CGM (Consumer Generated Media) サイト。

### ターゲットユーザー
- パチスロユーザー（朝イチ狙い・設定狙い層）
- 「今日の設定状況を知りたい」「リセットされているか確認したい」ユーザー

### 差別化ポイント
- **ログイン不要**: Cookie (`voter_token`) による匿名識別。ユーザー登録の障壁ゼロ
- **ワンタップ記録**: リセット YES/NO、設定 1〜6 をタップするだけ
- **集合知アプローチ**: 多数の記録を集計し、統計的に信頼度の高い情報を提供
- **全国網羅**: 47都道府県 5,761店舗 × 1,358機種のデータベース

---

## 2. 画面一覧・遷移図

### 公開ページ一覧

| URL | コントローラ | 役割 | 認証 |
|-----|-------------|------|------|
| `/` | `HomeController#index` | トップページ（ヒーロー・統計・ランキング・都道府県一覧） | 不要 |
| `/prefectures/:slug` | `PrefecturesController#show` | 都道府県ページ（店舗一覧・統計・フィルタ） | 不要 |
| `/shops/:slug` | `ShopsController#show` | 店舗ページ（記録UI・機種一覧・コメント・レビュー） | 不要 |
| `/shops/:slug/dates/:date` | `ShopsController#show_date` | 店舗ページ（日付指定） | 不要 |
| `/shops/favorites` | `ShopsController#favorites` | お気に入り店舗一覧（Ajax） | 不要 |
| `/machines/:slug` | `MachinesController#show` | 機種ページ（全店舗横断の設定傾向・設置店舗） | 不要 |
| `/machines/search` | `MachinesController#search` | 機種検索（Ajax、店舗ページから呼出） | 不要 |
| `/search` | `SearchController#index` | 全国横断検索（複合条件フィルタ） | 不要 |
| `/votes` | `VotesController#create` | 記録作成（POST） | 不要 |
| `/votes/:id` | `VotesController#update` | 記録更新（PATCH） | 不要 |
| `/comments` | `CommentsController#create` | コメント投稿（POST） | 不要 |
| `/shops/:slug/reviews` | `ShopReviewsController#create` | レビュー投稿（POST） | 不要 |
| `/reports` | `ReportsController#create` | 通報（POST） | 不要 |
| `/feedbacks/new` | `FeedbacksController#new` | 要望・不具合報告フォーム | 不要 |
| `/feedbacks` | `FeedbacksController#create` | 要望送信（POST） | 不要 |
| `/shop_requests/new` | `ShopRequestsController#new` | 店舗追加リクエストフォーム | 不要 |
| `/shop_requests` | `ShopRequestsController#create` | 店舗追加リクエスト送信（POST） | 不要 |
| `/shop_requests/:id` | `ShopRequestsController#show` | リクエスト状況確認 | 不要 |
| `/voter/status` | `VoterController#status` | マイステータス（称号・ストリーク・的中率・記録統計） | 不要 |
| `POST /voter/restore` | `VoterController#restore` | voter_token復元（トークン入力で引き継ぎ） | 不要 |
| `/rankings` | `RankingsController#index` | 記録ランキング（週間/月間/累計 × 全国/県別） | 不要 |
| `/play_records` | `PlayRecordsController#index` | 収支カレンダー（記録・閲覧・集計） | 不要 |
| `POST /play_records` | `PlayRecordsController#create` | 収支記録作成 | 不要 |
| `PATCH /play_records/:id` | `PlayRecordsController#update` | 収支記録更新 | 不要 |
| `DELETE /play_records/:id` | `PlayRecordsController#destroy` | 収支記録削除 | 不要 |
| `/404` | `ErrorsController#not_found` | 404エラーページ | 不要 |
| `/500` | `ErrorsController#internal_server_error` | 500エラーページ | 不要 |
| `/admin/*` | ActiveAdmin | 管理画面 | **Devise必須** |

### メイン遷移フロー

```
                    ┌────────────┐
                    │  ホーム  / │
                    └─────┬──────┘
                          │
        ┌─────────┬───────┼───────┬──────────┐
        ▼         ▼       ▼       ▼          ▼
  ┌──────────┐ ┌───────┐ ┌──────────┐ ┌──────────┐ ┌────────────┐
  │ 都道府県 │ │ 検索  │ │ ステータス│ │ ランキング│ │ 収支カレンダー│
  │/prefectures│/search │ │/voter/   │ │/rankings │ │/play_records│
  └────┬─────┘ └───┬───┘ │ status   │ └──────────┘ └────────────┘
       │            │     └──────────┘
       ▼            │
  ┌──────────┐      │
  │ 店舗     │◄─────┘
  │/shops/:slug│
  └────┬─────┘
       │
  ┌────┼──────────┐
  ▼    ▼          ▼
記録  コメント  レビュー

  ┌──────────┐
  │ 機種     │◄── ホームの注目機種 / 店舗ページの機種名
  │/machines/│
  └──────────┘
```

---

## 3. 機能仕様

### 3-1. 記録システム

#### 記録の種類
| 種別 | 内容 | 選択肢 |
|------|------|--------|
| リセット記録 | 朝イチのリセット有無を記録 | YES (1) / NO (0) |
| 設定推測 | 設定を推測して記録 | 1〜6 (整数) |
| 確定演出タグ | 確定演出の情報を共有 | `偶数確`, `奇数確`, `2以上`, `3以上`, `4以上`, `5以上`, `6確` |

#### 記録ルール
- **1人1日1店舗1機種1件**: `voter_token + shop_id + machine_model_id + voted_on` でユニーク制約
- **個別マージ**: リセット記録と設定記録は独立して更新可能（片方だけの記録も可）
- **確定タグはトグル式**: 同じタグを再度タップすると解除
- **記録対象期間**: 当日と前日のみ（未来の日付は不可）

#### ユーザー識別
- `voter_token`: Cookie に保存される `SecureRandom.hex(16)` の32文字トークン
- 有効期限: 1年間、`httponly: true`, `same_site: :lax`

#### VoteSummary（集計キャッシュ）
- Vote の `after_save` / `after_destroy` で `VoteSummary.refresh_for` を自動実行
- `pg_advisory_xact_lock` で同時更新の競合を防止
- 集計内容: 合計記録数、リセット YES/NO カウント、設定平均値、設定分布 (1〜6)、確定タグカウント
- `enough_data?`: 3件以上で信頼度ありと判定

### 3-2. 検索・フィルタ

#### 県内フィルタ（Stimulus `machine-filter`）
都道府県ページに設置。クライアントサイドで即時フィルタリング。
- 換金率（等価 / 5.6枚 / 5.0枚 / 非等価）
- レート（20スロ / 5スロ / 2スロ / 1スロ）
- 設備（加熱式たばこ遊技OK / Wi-Fi / 充電器 / 駐車場あり）
- 開店時間（9時台 / 10時台）
- 朝の入場ルールあり

#### 全国横断検索（`/search`）
`SearchController` でサーバーサイド検索。複合条件の AND/OR 組み合わせ。
- 都道府県（複数選択 OR）
- 換金率（同カテゴリ内 OR）
- レート（OR、`slot_rates` 配列カラムの `ANY` 検索）
- 設備（AND、`notes` カラムの LIKE 検索 + `sanitize_sql_like`）
- 開店時間（OR）
- 朝入場ルール
- フリーワード（店舗名部分一致）
- URLパラメータで条件保存・共有可能
- kaminari でページネーション（30件/ページ）

#### 統計逆引き
県ページの統計項目をクリック → 該当条件でフィルタ適用

#### 機種逆引き
- 機種ページに設置店舗リスト（都道府県フィルタ付き）
- 店舗ページから「同じレートの近くの店舗」リンク（同県・同レートで最大5件）

### 3-3. レビュー・コメント

#### コメント
- Polymorphic (`commentable_type: Shop`)
- 匿名投稿（`commenter_name` 任意、デフォルト「名無し」）
- 日付別表示（`target_date`）
- Polymorphic type allowlist: `Shop` のみ許可

#### レビュー（ShopReview）
- 1店舗につき1ユーザー1件（`voter_token` + `shop_id` でユニーク）
- 星評価（`rating` 1〜5）+ カテゴリ + タイトル + 本文
- `reviewer_name` 任意（デフォルト「名無し」）

#### 通報（Report）
- Polymorphic（対象: `Comment`, `ShopReview`）
- 理由（`reason` enum）
- Polymorphic type allowlist: `Comment`, `ShopReview` のみ許可

### 3-4. お気に入り
- **localStorage** に店舗 slug を保存（ログイン不要）
- Stimulus `favorite` コントローラでトグル
- Stimulus `favorites-list` コントローラでホームにお気に入り店舗一覧表示
- `/shops/favorites` エンドポイントで slug リストから店舗データ取得

### 3-5. マイステータス（`/voter/status`）
- Cookie (`voter_token`) で過去の記録を識別
- 表示項目: 総記録数、店舗数、機種数、都道府県数、直近の記録10件
- 実績バッジ:

| バッジ | 条件 |
|--------|------|
| 初記録 | 1件以上 |
| データ提供者 | 10件以上 |
| 常連記録者 | 50件以上 |
| エキスパート | 100件以上 |
| マスター | 500件以上 |
| 旅打ち | 3県以上で記録 |
| 機種マニア | 10機種以上で記録 |

### 3-6. 店舗追加リクエスト
- ユーザーが未登録店舗の追加を申請
- 必須: 店舗名、都道府県 / 任意: 住所、URL、メモ
- `voter_token` で申請者識別
- ステータス管理（`status` enum）→ Admin で承認/却下

### 3-7. SNS情報収集（SnsReport）
- RSS フィード日次収集（ちょんぼりすた・スロットジン）— **現在停止中**（有効なフィードが少なく効果薄）
- Admin で承認/却下キュー管理
- 機種ページに SNS 情報セクション表示（既存データのみ）

### 3-8. 機種攻略リンク（MachineGuideLink）
- 機種ごとの攻略情報リンク集
- `link_type` / `status` enum で分類・管理
- 機種ページに表示

### 3-9. 称号システム（VoterProfile）
ユーザーのモチベーション向上のためのゲーミフィケーション機能。

#### 称号ランク（上位優先）
| 称号 | 最小記録数 | 最小的中率 |
|------|-----------|-----------|
| 伝説の記録者 | 1,000件 | 70% |
| 設定看破マスター | 300件 | 60% |
| 目利き師 | 100件 | 40% |
| 常連 | 50件 | — |
| 記録者 | 10件 | — |
| 見習い | 0件 | — |

#### ストリーク
- 連続記録日数を計算（当日 or 前日起点）
- `current_streak` / `max_streak` を記録
- マイステータスにドットカレンダーで視覚的に表示

#### 的中率
- **多数派一致率** (`accuracy_majority`): 自分の設定記録が多数派（最頻値）と一致した割合
  - 最低5件以上かつ集計3件以上のデータのみ対象
- **高設定率** (`high_setting_rate`): 設定4/5/6を記録した割合
- `VoterProfile.refresh_for(voter_token)` で一括更新

### 3-10. 記録ランキング（VoterRanking）
記録数に基づく匿名ランキング。`/rankings` ページで閲覧。

#### 期間タイプ
| 期間 | period_type | 最小記録数 |
|------|------------|-----------|
| 週間 | `weekly` | 5件 |
| 月間 | `monthly` | 10件 |
| 累計 | `all_time` | 1件 |

#### スコープ
- **全国** (`scope_type: "national"`)
- **県別** (`scope_type: "prefecture"`, `scope_id: prefecture_id`)

#### 更新
- `ranking:refresh` Rakeタスクで全期間一括更新
- `VoterRanking.refresh_weekly!` / `refresh_monthly!` / `refresh_all_time!`

### 3-11. 収支カレンダー（PlayRecord）
パチスロの収支を記録・可視化する機能。`/play_records` ページで管理。

#### 記録内容
- 必須: 日付（`played_on`）、店舗、収支額（`result_amount`, -999,999 〜 +999,999）
- 任意: 機種、投資額（`investment`）、回収額（`payout`）、メモ（500文字以内）、タグ
- 公開/非公開切替（`is_public`、デフォルト公開）

#### タグ
`ロングフリーズ`, `有利区間リセ`, `天井`, `朝一`, `設定変更`, `据え置き`, `高設定確定`, `万枚`

#### 制約
- 1人1日1店舗1機種1件（voter_token + shop_id + machine_model_id + played_on ユニーク）
- 過去90日以内のみ記録可能
- 未来の日付は不可

#### 集計キャッシュ（PlayRecordSummary）
- スコープ: 機種別 / 店舗別 / 県別
- 期間: 月次 / 累計
- 集計項目: 総件数、合計収支、平均収支、勝率、曜日別統計
- 公開レコードのみ集計（`is_public: true`、`ABS(result_amount) <= 500,000`）
- `play_records:refresh_summaries` Rakeタスクで一括更新

### 3-12. voter_token復元
- `POST /voter/restore` でトークンを入力し、Cookieを上書き
- 端末移行・ブラウザ変更時にデータ引き継ぎ可能

---

## 4. データ設計

### ER概要図

```
Prefecture ──< Shop ──< ShopMachineModel >── MachineModel
                │                                  │
                ├──< Vote                          ├──< Vote
                │                                  │
                ├──< VoteSummary >─────────────────┘
                │
                ├──< Comment (polymorphic)
                ├──< ShopReview ──< Report (polymorphic)
                │
                ├──< PlayRecord >── MachineModel (optional)
                │
                └──< ShopRequest

MachineModel ──< SnsReport
             ──< MachineGuideLink

VoterProfile (voter_token で Vote と紐づけ)
VoterRanking (voter_token で Vote と紐づけ, scope_id で Prefecture 参照)
PlayRecordSummary (scope_type/scope_id で MachineModel/Shop/Prefecture 参照)

User (Admin only, Devise)
Feedback (standalone)
```

### 主要テーブル

| テーブル | 役割 | 主要カラム |
|---------|------|-----------|
| `prefectures` | 47都道府県マスタ | `name`, `slug` |
| `shops` | パチスロ店舗 | `name`, `slug`, `address`, `lat/lng`, `slot_rates[]`, `exchange_rate`, `total_machines`, `slot_machines`, `business_hours`, `parking_spaces`, `phone_number`, `morning_entry`, `access_info`, `features`, `pworld_url` |
| `machine_models` | パチスロ機種マスタ | `name`, `slug`, `maker`, `active`, `is_smart_slot`, `generation`, `payout_rate_min/max`, `introduced_on`, `type_detail`, `image_url`, `ceiling_info`, `reset_info`, `ptown_id` |
| `shop_machine_models` | 店舗×機種の設置紐づけ (N:N) | `shop_id`, `machine_model_id`, `unit_count` |
| `votes` | 記録データ | `voter_token`, `shop_id`, `machine_model_id`, `voted_on`, `reset_vote`, `setting_vote`, `confirmed_setting[]` |
| `vote_summaries` | 記録集計キャッシュ | `shop_id`, `machine_model_id`, `target_date`, `total_votes`, `reset_yes/no_count`, `setting_avg`, `setting_distribution`, `confirmed_setting_counts` |
| `comments` | コメント (polymorphic) | `commentable_type/id`, `body`, `target_date`, `commenter_name`, `voter_token` |
| `shop_reviews` | 店舗レビュー | `shop_id`, `voter_token`, `rating`, `title`, `body`, `category`, `reviewer_name` |
| `sns_reports` | SNS/RSS収集データ | `machine_model_id`, `shop_id`, `source`, `source_url`, `trophy_type`, `suggested_setting`, `confidence`, `status` |
| `shop_requests` | 店舗追加リクエスト | `name`, `prefecture_id`, `address`, `url`, `note`, `voter_token`, `status` |
| `feedbacks` | ユーザー要望 | `name`, `email`, `category`, `body`, `voter_token`, `status` |
| `reports` | 通報 (polymorphic) | `reportable_type/id`, `reason`, `resolved`, `voter_token` |
| `machine_guide_links` | 機種攻略リンク | `machine_model_id`, `url`, `title`, `source`, `link_type`, `status` |
| `voter_profiles` | ユーザープロフィールキャッシュ | `voter_token`, `total_votes`, `weekly_votes`, `monthly_votes`, `current_streak`, `max_streak`, `last_voted_on`, `accuracy_confirmed`, `accuracy_majority`, `high_setting_rate`, `rank_title` |
| `voter_rankings` | ランキング集計キャッシュ | `voter_token`, `period_type`, `period_key`, `scope_type`, `scope_id`, `vote_count`, `rank_position` |
| `play_records` | 収支記録 | `voter_token`, `shop_id`, `machine_model_id`, `played_on`, `result_amount`, `investment`, `payout`, `memo`, `tags[]`, `is_public` |
| `play_record_summaries` | 収支集計キャッシュ | `scope_type`, `scope_id`, `period_type`, `period_key`, `total_records`, `total_result`, `avg_result`, `win_count`, `lose_count`, `win_rate`, `weekday_stats` |
| `users` | 管理者ユーザー (Devise) | `email`, `nickname`, `role`, `trust_score` |

### データ規模

| 項目 | 件数 |
|------|------|
| 店舗 | 5,761（全国47都道府県） |
| アクティブ機種 | ~1,358（パチスロのみ、パチンコ自動除外） |
| 50店舗以上設置の主要機種 | ~418 |
| 店舗×機種リンク | 403,368 |
| レート情報取得率 | 100% |
| 設備情報取得率 | 88% |

### データソースマッピング

| データ項目 | ソース | 更新頻度 |
|-----------|--------|---------|
| 店舗一覧・pworld_url | P-WORLD (`pworld:import_shops`) | 初回のみ |
| 店舗詳細（営業時間・駐車場・電話等） | P-WORLD (`pworld:scrape_shop_details`) | 月次 |
| 設置機種リスト | P-WORLD (`pworld:refresh_shop_machines`) | 日次 |
| 設置台数 | P-WORLD (`pworld:update_unit_counts`) | 日次 |
| 機種一覧（名前・メーカー・機械割・導入日・画像） | DMMぱちタウン (`ptown:import_machines`) | 日次 |
| 機種詳細（天井・リセット・タイプ） | DMMぱちタウン (`ptown:import_details`) | 随時 |
| イベント情報（取材・新台入替） | DMMぱちタウン (`ptown:import_events`) | 日次 |
| 記録・コメント・レビュー | ユーザー入力 | リアルタイム |

---

## 5. 技術アーキテクチャ

### 技術スタック

| カテゴリ | 技術 |
|---------|------|
| 言語 | Ruby 4.0.0 |
| フレームワーク | Rails 8.0.4 |
| データベース | PostgreSQL 17 |
| フロントエンド | Hotwire (Turbo + Stimulus) / Tailwind CSS v4 |
| 認証 | Devise（管理者のみ） |
| 管理画面 | ActiveAdmin |
| 検索 | pg_search（`tsearch` prefix モード） |
| ページネーション | kaminari |
| レート制限 | Rack::Attack |
| SEO | meta-tags / sitemap_generator |
| テスト | RSpec + FactoryBot + Faker |
| CI | GitHub Actions |

### Hotwire パターン

| パターン | 用途 | 実装 |
|---------|------|------|
| Turbo Frame 記録 | 記録ボタン押下→行だけ部分更新 | `<turbo-frame id="vote_...">` |
| Turbo Stream コメント | コメント投稿→リスト先頭に追加 | `turbo_stream.prepend` |
| Turbo Stream レビュー | レビュー投稿→フォーム+リスト更新 | `turbo_stream.replace` |

### Stimulus コントローラ

| コントローラ | 機能 |
|-------------|------|
| `vote` | 記録ボタンの無効化 + pulse アニメーション |
| `accordion` | 都道府県地域の開閉 |
| `favorite` | 店舗お気に入りトグル (localStorage) |
| `favorites-list` | ホームでお気に入り店舗一覧表示 |
| `machine-filter` | 県ページの店舗フィルタ + 店舗ページの機種名絞り込み |
| `machine-search` | 店舗ページで機種検索→記録行追加 |
| `dismissable` | アラート等の非表示 |
| `calendar` | 収支カレンダーの日セル選択ハイライト |
| `play-record-form` | 収支入力フォームの簡易/詳細モード切替 |
| `tag-select` | タグチップ選択トグル (hidden input同期) |
| `result-input` | 収支額±切替UI |
| `ranking-tab` | ランキング期間/スコープ切替 (Turbo navigation) |
| `nearby` | 近隣店舗の位置情報取得・表示 |
| `trend-tab` | トレンドデータのタブ切替 |
| `shop-filter` | 全国検索ページのフィルタUI |
| `machine-shop-filter` | 機種ページの設置店舗フィルタ |
| `star-rating` | レビュー星評価入力UI |
| `theme` | ダークモード切替 |
| `carousel` | カルーセル表示 |
| `mobile-nav` | モバイルナビゲーションメニュー |

### PWA
- Service Worker によるオフラインフォールバック
- ホーム画面追加対応
- テーマカラー設定

### テーマシステム
- CSS カスタムプロパティ（`@theme` ブロック、Tailwind CSS v4 形式）
- `app/assets/tailwind/application.css` でカスタムカラー定義
- 3段階ダークモード対応
- 設定ヒートマップ配色: 1=blue → 2=cyan → 3=emerald → 4=amber → 5=orange → 6=red

---

## 6. 運用設計

### デプロイ

| 項目 | 設定 |
|------|------|
| プラットフォーム | Render.com |
| デプロイ方式 | Blueprint (`render.yaml`) + Git 直接デプロイ |
| Web サービス | `bundle exec puma -C config/puma.rb`（Starter プラン） |
| データベース | PostgreSQL（Free → Starter） |
| ビルド | `./bin/render-build.sh` |
| 環境変数 | `DATABASE_URL`, `RAILS_MASTER_KEY`, `RAILS_ENV=production`, `RAILS_LOG_TO_STDOUT=1`, `RAILS_SERVE_STATIC_FILES=1` |

### 定期バッチ

| バッチ | スケジュール (JST) | Cron (UTC) | 内容 |
|--------|-------------------|------------|------|
| `pworld:weekly_refresh` | 毎週日曜 03:00 | `0 18 * * 6` | 新台インポート + 設置機種リスト更新 + 孤立機種非アクティブ化 |
| `pworld:monthly_refresh` | 毎月1日 02:00 | `0 17 1 * *` | 店舗詳細の全項目再取得 |

### Rake タスク一覧

| タスク | 説明 |
|--------|------|
| `pworld:scrape_shops[slug]` | 都道府県の店舗を P-WORLD からインポート |
| `pworld:scrape_shop_details` | 全店舗の詳細情報を取得（約4時間） |
| `pworld:scrape_shop_details_by_pref[slug]` | 県単位で詳細取得 |
| `pworld:refresh_shop_machines` | 全店舗の設置機種リスト更新 |
| `pworld:refresh_by_pref[slug]` | 県単位で設置機種更新 |
| `pworld:import_machines` | 機種マスタ更新（新台含む） |
| `pworld:cleanup_orphan_machines` | 設置0の機種を非アクティブ化 |
| `pworld:update_unit_counts` | 全店舗の機種別設置台数を更新 |
| `pworld:update_unit_counts_by_pref[slug]` | 県単位で設置台数更新 |
| `pworld:weekly_refresh` | 週次バッチ |
| `pworld:monthly_refresh` | 月次バッチ |

### スクレイピング規約
- データソース: P-WORLD
- エンコーディング: EUC-JP (`Encoding::EUC_JP`)
- レート制限: `sleep 2.5` 秒/リクエスト
- User-Agent: 標準ブラウザ UA
- HTTP クライアント: `Net::HTTP` 直接使用
- リトライ: 最大3回

### レート制限 (Rack::Attack)

| ルール | 制限 | 期間 |
|--------|------|------|
| 一般リクエスト (`req/ip`) | 60回 | 1分 |
| 記録 (`votes/ip`) | 50回 | 1日 |
| コメント (`comments/ip`) | 10回 | 1時間 |
| 通報 (`reports/ip`) | 10回 | 1時間 |
| フィードバック (`feedbacks/ip`) | 5回 | 1時間 |
| 店舗イベント (`shop_events/ip`) | 5回 | 1時間 |
| 収支記録 (`play_records/ip`) | 20回 | 1時間 |

制限超過時: HTTP 429 + `Retry-After` ヘッダー + 日本語メッセージ

### データ品質チェック
スクレイピング後に必ず実施:
1. **パチンコ混入チェック**: `Ｐ`, `ＣＲ`, `ｅ`, `PA`, `PF`, `CR`, `ぱちんこ`, `デジハネ`, `甘デジ`, `羽根モノ` 等のパターン
2. **重複チェック**: Unicode NFKC 正規化で全角/半角の重複検出
3. **件数の妥当性チェック**: 変更前後の件数比較
4. **取得率レポート**: レート 100%+ / 設備 88%+

### 外部 API
- Google Custom Search API: 機種攻略リンク自動収集（無料 100回/日）

---

## 7. SEO・マーケティング

### メタタグ
- `meta-tags` gem で全ページに `title`, `description`, `keywords` を設定
- OGP (`og:title`, `og:description`, `og:type`, `og:url`, `og:image`)
- Twitter Card (`twitter:card: summary`)

### サイトマップ (`config/sitemap.rb`)
- ホーム: `daily`, priority 1.0
- 店舗: `daily`, priority 0.9
- 都道府県: `daily`, priority 0.8
- 機種（active のみ）: `weekly`, priority 0.7
- 検索ページ: `weekly`, priority 0.6
- ホスト: `https://yomislo.com`

### robots.txt
- 標準設定

### noindex 対象
- `/voter/status`（マイステータス）
- `/feedbacks/new`（要望フォーム）
- `/shop_requests/new`（店舗追加リクエスト）

---

## 8. セキュリティ

### Content Security Policy (CSP)

```
default-src: 'self'
font-src:    'self' https://fonts.gstatic.com
img-src:     'self' data: https:
object-src:  'none'
script-src:  'self' 'unsafe-inline' (nonce)
style-src:   'self' 'unsafe-inline' https://fonts.googleapis.com
connect-src: 'self'
frame-src:   'none'
base-uri:    'self'
form-action: 'self'
```

- Nonce: `script-src` に適用（`request.session.id` ベース）

### Rack::Attack
- IP ベースのレート制限（上記「レート制限」セクション参照）
- 429 レスポンスに `Retry-After` ヘッダー付与

### Polymorphic Type Allowlist
- `CommentsController`: `commentable_type` を `Shop` のみ許可
- `ReportsController`: `reportable_type` を `Comment`, `ShopReview` のみ許可
- 不正な型は `ActionController::BadRequest` を raise

### SQL インジェクション対策
- `sanitize_sql_like` でユーザー入力の LIKE パターンをエスケープ
- `SearchController`, `MachinesController` で適用

### 同時実行制御
- `pg_advisory_xact_lock` で VoteSummary の同時更新を防止

### その他
- `allow_browser versions: :modern` で古いブラウザをブロック
- Cookie: `httponly: true`, `same_site: :lax`
- 管理画面: Devise 認証必須（`/admin`）

---

## 9. コスト見積もり

| 項目 | Phase 3 (デプロイ初期) | Phase 4 (AI導入後) |
|------|----------------------|-------------------|
| Render.com Web (Starter) | $7/月 | $7/月 |
| Render.com DB (Free→Starter) | $0 → $7/月 | $7/月 |
| ドメイン | ~¥1,500/年 | ~¥1,500/年 |
| Google Custom Search API | $0 (100回/日無料) | $0 |
| Claude Haiku API | — | $5〜15/月 |
| X API | — | $200/月 (要検討) |
| **合計** | **約¥1,500/月** | **約¥3,000〜5,000/月** (X API除く) |
