# ヨミスロ - プロジェクトガイド

## プロジェクト概要
パチスロの設定・リセット情報を匿名ワンタップ記録で集め、集合知として可視化するCGMサイト。

## 技術スタック
- **Ruby 4.0.0** / **Rails 8.0.4** / **PostgreSQL 17**
- Hotwire (Turbo + Stimulus) / Tailwind CSS v4
- Devise (管理者認証のみ) / ActiveAdmin
- pg_search / kaminari / rack-attack / meta-tags / sitemap_generator
- RSpec + FactoryBot + Faker
- デプロイ先: Render.com（未デプロイ）

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

## 主要モデル
| モデル | 概要 |
|--------|------|
| Prefecture | 47都道府県 (seed) |
| Shop | 店舗 (5,761件。レート・換金率・台数・駐車場・電話・朝入場・アクセス・特徴・喫煙詳細等) |
| MachineModel | パチスロ機種 (active: ~1,300 / inactive: ~3,500。ptown_id, type_detail, ceiling_info, reset_info, display_typeあり) |
| ShopMachineModel | 店舗×機種の設置紐づけ (N:N中間テーブル) |
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

## テスト
```bash
bundle exec rspec  # 533 examples, 0 failures, 72% coverage
```

## P-WORLDスクレイピング設計
- **統合メソッド**: `PworldScraper.sync_shop_from_pworld(shop, cleanup_stale:, update_details:)` が単一エントリポイント
  - 1回のHTTPリクエストで機種リスト + 台数 + 店舗詳細を全取得
  - `normalize_slug(name)` で全slugを統一生成
  - 数字画像は `@digit_image_cache` でクロスショップキャッシュ
- **パチンコ判定**: `extract_slot_links(doc)` が `data-machine-type="S"` で構造判別。正規表現はフォールバック専用

## Render.com バッチスケジュール (render.yaml)
| cronジョブ | スケジュール(UTC) | 内容 |
|-----------|------------------|------|
| `yomislo-daily-refresh` | 0 18 * * * | 新台 + 全店同期(機種+台数) ~4h |
| `yomislo-daily-aggregation` | 0 19 * * * | ランキング+収支+Profile (数秒、SNS停止中) |
| `yomislo-monthly` | 0 18 1 * * | 全店フル同期(機種+台数+詳細) ~4h |

- 毎月1日: daily-refresh はスキップ、monthly が代わりに実行
- recurring.yml は Solid Queue 無効のため参照用のみ

## Rakeタスク（pworld:）
| タスク | 説明 |
|--------|------|
| `scrape_shops[slug]` | 都道府県の店舗をP-WORLDからインポート |
| `scrape_shop_details` | 全店舗の詳細情報を取得（営業時間/駐車場/電話等、約4時間） |
| `scrape_shop_details_by_pref[slug]` | 県単位で詳細取得 |
| `refresh_shop_machines` | 全店舗の設置機種リスト更新（sync_shop_from_pworld経由） |
| `refresh_by_pref[slug]` | 県単位で設置機種更新 |
| `import_machines` | 機種マスタ更新（新台含む） |
| `cleanup_orphan_machines` | 設置0の機種を非アクティブ化 |
| `update_unit_counts` | 全店舗の機種別設置台数を更新（数字画像デコード方式） |
| `update_unit_counts_by_pref[slug]` | 県単位で設置台数更新 |
| `weekly_refresh` | 週次バッチ（新台+設置機種+クリーンアップ） |
| `monthly_refresh` | 月次バッチ（店舗詳細の全項目再取得） |

## Rakeタスク（ptown:）
| タスク | 説明 |
|--------|------|
| `import_machines` | DMMぱちタウンから機種一覧取得・更新 |
| `import_details` | DMMぱちタウンから機種詳細（天井・リセット・タイプ）取得 |
| `import_all` | 一覧→詳細の全取得 |
| `import_events[area]` | DMMぱちタウンからイベント情報取得（取材・新台入替等） |

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
1. **パチンコ混入チェック**: P-WORLDの `data-machine-type="S"` セクションからのみスロットを取得（`extract_slot_links`）。正規表現フィルタ (`pachinko_name?`) はフォールバック用のみ
2. **重複チェック**: Unicode NFKC正規化で全角/半角の重複がないか
3. **件数の妥当性チェック**: 変更前後の件数を表示し、大幅な増減がないか確認
4. **レート・設備情報の取得率を報告** (目標: レート75%+, 設備88%+)

### P-WORLDスクレイピング規約
- エンコーディング: EUC-JP (`Encoding::EUC_JP`)
- レート制限: `sleep 2.5` (1リクエストあたり)
- User-Agent: YomiSloBot UA使用
- Net::HTTP直接使用 (WebFetchは404になる)
- **同一ページの重複フェッチ禁止**: 新データ取得は `sync_shop_from_pworld` に統合する
- **パチンコ判定**: `data-machine-type="S"` 構造判別が正。正規表現は不正確

## UI/フロントエンド規約

### Tailwind CSS v4
- `@import "tailwindcss"` + `@theme` ブロック (v4形式)
- カスタムカラーは `app/assets/tailwind/application.css` の `@theme` で定義
- 設定ヒートマップ: 1=blue→2=cyan→3=emerald→4=amber→5=orange→6=red

### Hotwire パターン
- 記録UI: Turbo Frame (`<turbo-frame id="vote_...">`) で部分更新
- 開閉UI: Stimulus `accordion` コントローラ
- お気に入り: localStorage + Stimulus `favorite` / `favorites-list`
- フィルタ: Stimulus `machine-filter` コントローラ

### モバイルファースト
- `sm:` ブレークポイントでデスクトップ対応
- タップ領域: 最小44x44px
- 機種記録行: コンパクトさ重視（縦幅を抑える）

## Rakeタスク命名規約
- namespace: `pworld:`
- 都道府県指定: `rake pworld:task_name[prefecture_slug]`
- 全国一括: `rake pworld:task_name` (引数なし)
- 進捗表示: `puts "#{index}/#{total} ..."` 形式
