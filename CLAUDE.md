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
| Shop | 店舗 (DMMぱちタウンから取得。ptown_shop_id必須) |
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

## DMMぱちタウン スクレイピング設計
- **モジュール**: `PtownScraper` (`lib/tasks/ptown.rake`)
- **BASE_URL**: `https://p-town.dmm.com`
- **レート制限**: `sleep 3.0` (1リクエストあたり)
- **正規化**: `normalize_slug()` で NFKC正規化 + 空白→ハイフン + 記号除去 + downcase
- **core_name()**: 接頭辞(L/S/パチスロ/スマスロ等)・末尾型式コード除去で重複検出用
- **parse_shop_detail()**: JSON-LDから店舗基本情報 + #anc-slot セクションから機種リスト取得

## Render.com バッチスケジュール (render.yaml)
| cronジョブ | スケジュール(UTC) | 内容 |
|-----------|------------------|------|
| `yomislo-daily-refresh` | 0 18 * * * | 機種マスタ + 全店設置機種同期 ~5h |
| `yomislo-daily-aggregation` | 0 19 * * * | ランキング+収支+Profile (数秒) |
| `yomislo-monthly` | 0 18 1 * * | 店舗マスタ + 機種詳細 + 設置機種フル同期 ~5h |

- 毎月1日: daily-refresh はスキップ、monthly が代わりに実行
- recurring.yml は Solid Queue 無効のため参照用のみ

## Rakeタスク（ptown:）
| タスク | 説明 |
|--------|------|
| `import_machines` | DMMぱちタウンから機種一覧取得・更新 |
| `import_details` | DMMぱちタウンから機種詳細（天井・リセット・タイプ）取得 |
| `import_all` | 一覧→詳細の全取得 |
| `import_shops[slug]` | DMMぱちタウンから店舗一覧取得（都道府県別 or 全国） |
| `sync_shop_machines[slug]` | 設置機種+台数+店舗詳細を同期（都道府県別 or 全国） |
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
- namespace: `ptown:`
- 都道府県指定: `rake ptown:task_name[prefecture_slug]`
- 全国一括: `rake ptown:task_name` (引数なし)
- 進捗表示: `puts "#{index}/#{total} ..."` 形式
