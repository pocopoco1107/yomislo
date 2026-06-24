# ヨミスロ ロードマップ

> **最終更新: 2026-06-24**
> 具体的な残タスク・バグは `BACKLOG.md` を参照。本ファイルはフェーズ別の全体像。

## 技術スタック
- Ruby 4.0.0 / Rails 8.1.3 / PostgreSQL 17
- Hotwire (Turbo + Stimulus) / Tailwind CSS v4
- Devise (管理者のみ) / ActiveAdmin
- デプロイ: Render.com (Singapore) — Web + Cron×3 + DB Basic

## 現在のデータ規模

| 項目 | 件数 |
|------|------|
| 店舗 | 6,053 (全国47都道府県、DMMぱちタウン) |
| 機種 (全体/アクティブ) | 3,639 / 593 |
| 店舗×機種リンク | 383,003 |
| 記録 (Vote) | 13 |
| 収支記録 (PlayRecord) | 2 |
| 相棒ペット | 6 |
| 広告案件 (Promotion) | 5 (待機中) |
| テスト | 630 examples, 0 failures, 47.5% coverage |

---

## 完了済み (Phase 1 MVP + Phase 2 + Phase 3 一部)

### 基盤
- [x] Rails 8 + Ruby 4.0.0 + PostgreSQL 17
- [x] 匿名Cookie記録 (Turbo Frame即時反映)
- [x] コメント・通報・店舗レビュー・イベント投稿
- [x] ActiveAdmin管理画面
- [x] Rack::Attack レート制限
- [x] SEO (meta-tags, sitemap, robots.txt, canonical)
- [x] セキュリティ (CSP, security headers, Brakeman 0 warnings)
- [x] RSpec テスト (630 examples)
- [x] Render.com デプロイ・本番運用中
- [x] モバイルファースト + PWA + ダークモード

### データ取得 (DMMぱちタウン一本化)
- [x] 全国6,053店舗インポート
- [x] 設置機種+台数同期 (383,003リンク)
- [x] 店舗詳細 (設備フラグ・営業時間・入場方法・アクセス)
- [x] 機種詳細 (天井・リセット・タイプ・画像URL)
- [x] geocode (GSI + Nominatim fallback)
- [x] Cron 3本体制 (daily-refresh / daily-aggregation / monthly)

### 記録UI
- [x] 設定記録 (推測+確定分離、ヒートマップ配色)
- [x] 機種フィルター・タイプ別セクション区切り
- [x] 記録ファースト店舗ページ (2026-06 UI改修)

### ゲーミフィケーション
- [x] VoterProfile (ストリーク・的中率・ポイント)
- [x] VoterRanking (週間/月間/累計 × 全国/県別)
- [x] PlayRecord (収支カレンダー・タグ付け)
- [x] 相棒ペット MVP (4段階一本道、ドット絵、進化トースト)
- [x] voter_token復元

### 検索・フィルタ
- [x] 県内フィルタパネル (換金率/レート/設備/開店時間)
- [x] 全国横断検索 `/search` (複合条件、URLパラメータ共有)
- [x] 機種逆引き (設置店舗の県/レート/設備フィルタ)
- [x] 統計からの逆引き (県ページ統計クリック→フィルタ)

### その他
- [x] 交換率ユーザー投稿 (ExchangeRateReport)
- [x] ユーザー店舗登録申請 (ShopRequest、管理者承認制)
- [x] Promotion広告システム (7スロット、env ON/OFF制御)
- [x] ASP審査用ポリシーページ (プライバシー/利用規約/特商法/運営方針)

---

## Phase 3: 運用基盤の強化（進行中）

### 3-1. 監視・可観測性 ★最優先
- [ ] エラー監視導入 (Sentry / Honeybadger)
- [ ] アクセス解析導入 (GA4 / Plausible / Umami)
- [ ] アップタイム監視 (UptimeRobot)

### 3-2. インフラ
- [x] Postgres Basic ($6/mo) 移行済
- [x] Puma 警告解消済
- [ ] 独自ドメイン取得 + SSL
- [ ] DB バックアップ運用の確立
- [ ] Render リージョン再検討 (Singapore → Tokyo 将来)

### 3-3. 品質
- [ ] テストカバレッジ拡充 (47.5% → 目標 70%+)
- [ ] 細かいバグの洗い出し (モバイル、エッジケース)

### 3-4. 集客
- [ ] Google Search Console 確認・最適化
- [ ] SNS 発信 (Twitter/X パチスロ垢)
- [ ] プロモ記事執筆 (note 等)

---

## Phase 4: 収益化

### 4-1. 広告有効化
- [ ] ASP 本格登録 (A8.net / もしもアフィリエイト / バリューコマース)
- [ ] Promotion の target_url 設定 + `PROMOTIONS_ENABLED=true`
- [ ] 特商法ページの実名化 (金融系案件取扱時)
- [ ] クリック計測 v2 (`/r/:promotion_id` リダイレクト)

### 4-2. 収益化プラン
- [ ] 損益分岐 PV の算出 (現インフラ月 $28-35)
- [ ] 広告スロットの実測→最適化
- [ ] 必要なら安価 VPS 移行コスト試算

---

## Phase 5: 機能拡充

### 5-1. 相棒ペット壮大版
- [ ] 6段階×4系統分岐 (仕様書: `docs/companion_spec.md`)
- [ ] ドット絵生成パイプライン構築
- [ ] 色違い・ご当地ヨミ

### 5-2. データ品質
- [ ] MachineModel 重複統合の定期化
- [ ] 機種名の旧字体フィルタ対応 (ヱ→エ等)
- [ ] SnsReport の復活 or 廃止判断

### 5-3. AI 機能
- [ ] 機種攻略リンク自動取得 (Google Custom Search API)
- [ ] AI SNS情報収集 (Claude Haiku による構造化)
- [ ] 「今日のおすすめ店舗」AI コメント

### 5-4. 通知・連携
- [ ] お気に入り店舗のメール/LINE 通知
- [ ] イベント・取材情報カレンダー
- [ ] Discord / LINE コミュニティ連携

### 5-5. UI/UX
- [ ] マイクロコピー横断レビュー
- [ ] ロゴ・キャッチコピー再検討
- [ ] ランキング露出の調整
- [ ] 機種画像の表示 (著作権要調査)

---

## コスト現況

| 項目 | 月額 |
|------|------|
| Render Web (Starter) | $7 |
| Render Cron × 3 (Starter) | $3 × 3 = $9 |
| Render Postgres (Basic) | $6 |
| **合計** | **約 $22〜28** (≒ ¥3,300〜4,200) |

独自ドメイン追加時: +¥1,500/年

---

## 優先順位ガイド
1. **監視・可観測性** — エラーに気づけないのが最大のリスク
2. **集客** — ユーザーがいないと記録データが貯まらない
3. **収益化** — インフラ費用の黒字化
4. **品質・バグ修正** — ユーザー定着のための地道な改善
5. **機能拡充** — ペット壮大版・AI 機能はユーザー基盤確立後

## セッション分離ガイド
- **1セッション = 1機能**が原則。コンテキスト肥大によるミスを防ぐ
- CLAUDE.md + MEMORY.md で状態引き継ぎ
- 大きい機能はサブタスクに分割
- スクレイピング等の長時間タスクはバックグラウンド実行
