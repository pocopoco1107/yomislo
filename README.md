# スロリセnavi

パチスロの設定・リセット情報を匿名ワンタップ投票で集め、集合知として蓄積するCGMサイト。

ログイン不要。Cookie（voter_token）で匿名識別し、1人1日1店舗1機種1票のルールで投票データを収集します。

## 主な機能

### 投票システム
- **リセット投票**: リセット有無をワンタップで投票
- **設定推測投票**: 設定1〜6を投票、ヒートマップで分布表示
- **確定演出投票**: トロフィー・確定演出の目撃情報を投稿
- **Turbo Frame** による部分更新で即時反映

### 店舗情報
- 全国47都道府県 **5,761店舗** のデータ
- レート（20スロ/5スロ/2スロ/1スロ）、換金率、営業時間、駐車場、朝入場ルール等
- P-WORLDからの自動スクレイピングで定期更新
- ユーザーによる店舗追加リクエスト機能

### 機種情報
- アクティブ **1,343機種**（スマスロ/6号機/5号機を自動分類）
- 号機区分・機械割・導入日・機種画像をP-WORLDから取得
- 機種別の設置店舗逆引き検索
- 攻略リンク自動収集（Google Custom Search API）

### 検索・フィルタリング
- **県ページフィルタ**: 換金率/レート/設備/開店時間/朝入場で絞り込み（クライアントサイド即時フィルタ）
- **全国横断検索** (`/search`): 複合条件サーバーサイド検索、URLパラメータで共有可能
- **統計逆引き**: 県ページ統計をクリック → 該当店舗にフィルタ
- **機種逆引き**: 機種 → 設置店舗を都道府県・レートで絞り込み

### 分析・レコメンド
- 投票トレンドグラフ（7日間推移、CSSのみ）
- AIおすすめ店舗（投票数/高設定率/リセット率/レビュー評価のスコアリング）
- 投票者ランキング・実績バッジ（匿名、Cookie識別）
- 店舗レビュー（星評価 + カテゴリ別）

### SNS情報収集
- RSSフィード自動収集（ちょんぼりすた、スロットジン等）
- Google Custom Search API 連携
- ルールベース構造化パーサー（将来Claude Haiku API対応）

### UI/UX
- モバイルファースト（Tailwind CSS v4）
- ダークモード（3段階トグル: システム/ダーク/ライト）
- PWA対応（ホーム画面追加、オフラインフォールバック）
- SVGイラスト（ヒーロー、空状態、エラーページ）

## 技術スタック

| カテゴリ | 技術 |
|---------|------|
| 言語・フレームワーク | Ruby 4.0.0 / Rails 8.0.4 |
| データベース | PostgreSQL 17 |
| フロントエンド | Hotwire (Turbo + Stimulus) / Tailwind CSS v4 |
| 認証 | Devise（管理者のみ） |
| 管理画面 | ActiveAdmin |
| 検索 | pg_search |
| ページネーション | Kaminari |
| セキュリティ | Rack::Attack / CSP / Security Headers |
| SEO | meta-tags / sitemap_generator / JSON-LD |
| テスト | RSpec + FactoryBot + Faker (339 examples) |
| デプロイ | Render.com（予定） |

## セットアップ

```bash
# PostgreSQL 17 を起動
export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"
brew services start postgresql@17

# 依存関係インストール
bundle install

# データベース作成・マイグレーション・シード
bin/rails db:create db:migrate db:seed

# サーバー起動 (Tailwind watch + Rails)
bin/dev
```

管理画面: http://localhost:3000/admin
- Email: `admin@example.com`
- Password: `password`

## テスト

```bash
bundle exec rspec  # 339 examples, 0 failures
```

## データ取得（Rakeタスク）

```bash
# 店舗インポート（全国）
rake pworld:scrape_shops

# 店舗詳細スクレイプ（営業時間/駐車場/電話等）
rake pworld:scrape_shop_details

# 機種マスタ更新
rake pworld:import_machines

# 機種詳細スクレイプ（号機/機械割/画像等）
rake pworld:fetch_machine_ids
rake pworld:scrape_machine_details

# 設置機種リンク更新
rake pworld:refresh_shop_machines

# 設置台数更新
rake pworld:update_unit_counts

# 定期バッチ
rake pworld:weekly_refresh   # 毎週: 新台+設置機種+クリーンアップ
rake pworld:monthly_refresh  # 毎月: 店舗詳細の全項目再取得
```

## データ規模

| 項目 | 件数 |
|------|------|
| 店舗 | 5,761（全国47都道府県） |
| アクティブ機種 | 1,343（パチスロのみ） |
| 店舗×機種リンク | 403,368 |
| レート情報取得率 | 100% |
| メーカー情報取得率 | 100% |

## ライセンス

Private repository.
