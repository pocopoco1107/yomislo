# ヨミスロ BACKLOG

実装済みの機能改善・調査タスクを積んでおくバックログ。優先度や着手予定は項目ごとに決める。
作業着手時は GitHub Issue 化するか、直接ブランチ切って進める。

> **最終更新: 2026-06-30**（a11y HIGH 4件 + MED 3件消化、DESIGN.md にチェックリスト追記）

## 目次

- [UI / UX](#ui--ux)
- [検索 / 発見性](#検索--発見性)
- [データ品質](#データ品質)
- [機能追加・検討](#機能追加検討)
- [相棒ペット](#相棒ペット)
- [バグ調査](#バグ調査)
- [広告 / 収益化](#広告--収益化)
- [セキュリティ](#セキュリティ)
- [インフラ / 運用](#インフラ--運用)
- [完了済み](#完了済み)

---

## UI / UX

### UI・UX 全体の見直し・改修
DESIGN.md と照合してサーフェス階層・余白・カラートークン使用の一貫性を再点検する。

### 細かいテキストの文章検討
プレースホルダー、空状態、エラーメッセージ、ボタンラベルなどのマイクロコピーを横断レビュー。AIっぽい硬さが残っている箇所を絞る（feedback_copywriting 参照）。

### ロゴ・キャッチコピーの再検討
現ヒーローキャッチ「みんなの記録で設定が見えてくる」等の時間帯切替バリエーションも含めて再評価。

### アクセシビリティ (WCAG 2.1 AA)
2026-06-26 レビューで HIGH 4件・MED 7件検出 → 2026-06-30 HIGH 全消化＋MED 主要3件＋DESIGN.md チェックリスト追記済。
- ~~**[HIGH] ライトモード `--primary` を `#10b981` → `#059669` に下げる**~~ ✅ 済 (2026-06-30) `--primary` / `--accent` / `--ring` を `#059669` に変更、白文字 CTA で AA 通過
- ~~**[HIGH] `bg-setting-4 text-white` / `bg-vote-yes text-white` 等の白文字配色見直し**~~ ✅ 済 (2026-06-30) `_machine_vote_row.html.erb` の selected/confirmed/vote-yes/vote-no を「明るい背景=`text-gray-900`、暗い背景=`text-white`」ルールに統一
- ~~**[HIGH] `--text-tertiary:#9ca3af` を `#6b7280` 相当に**~~ ✅ 済 (2026-06-30) ライトモード token を `#6b7280` に更新
- ~~**[HIGH] お気に入り星ボタンの `aria-pressed`/`aria-label` を Stimulus でトグル**~~ ✅ 済 既に `favorite_controller.js#updateUI` で `connect()` 時に動的トグル済み（BACKLOG が古かっただけ）
- ~~[MED] トースト/エラーへ `aria-live`~~ ✅ 済 (2026-06-30) `_flash` notice=`role=status/aria-live=polite`、alert / `_errors` / `_form_errors` を `role=alert/aria-live=assertive`
- ~~[MED] `prefers-reduced-motion` 対応を `.animate-*` 全般に拡張~~ ✅ 済 (2026-06-30) `application.css` 末尾にグローバル `* { animation-duration: 0.001ms !important }` ブロックを追加
- ~~[MED] モーダルに focus trap + `role="dialog"`~~ ✅ 済 (2026-06-30) `record-modal` を `role="dialog" aria-modal aria-labelledby tabindex=-1` 化、open/close で 前フォーカス保存→復帰の軽量実装
- [MED] 残り: Turbo Frame 更新後のフォーカス管理（vote 投稿後 autofocus）、確定設定トグル群へ `aria-pressed`、ボトムナビ active の `.dq-cursor--blink` 点滅停止条件
- ~~DESIGN.md に a11y チェックリスト 5項目追記~~ ✅ 済 (2026-06-30)

---

## 検索 / 発見性

### SEO 構造化データの網羅性
- 構造化データ (LocalBusiness / WebSite / SearchAction) の追加余地
- ~~店舗・機種ページの title / description テンプレート最適化~~ ✅ 済 (2026-06-26) AIっぽい言い回し排除、打ち手目線に刷新
- Google Search Console でのインデックス状況確認（新ドメイン yomislo.com、明日以降にページ/検索パフォーマンスを確認）
- ~~**サイトマップ取得失敗の解消**~~ ✅ 済 (2026-06-26) `https://yomislo.com/sitemap.xml.gz` 送信成功、6,701ページ検出
- ~~主要URLの個別インデックス登録リクエスト~~ ✅ 済 (2026-06-30) トップ/ランキング/機種5本は既に登録済み、県5本（tokyo/osaka/aichi/hokkaido/kanagawa）はリクエスト送信完了
- **アドレス変更ツールが Render の Cloudflare で失敗する件**: 旧 yomislo.onrender.com への Googlebot アクセスが Cloudflare Bot Challenge でブロック。301は効いているのでGoogleの自然学習に任せる（数週間〜数ヶ月）

### 機種ページの商品スニペット構造化データ修正
2026-06-30 Search Console で確認、全機種ページに「商品スニペット 1件の無効なアイテムを検出しました」警告。インデックスは通っているが Rich Results 対象外になっている。`app/views/machines/show.html.erb` のJSON-LD（Product schema）の必須フィールド（offers/aggregateRating/review のいずれか、name、image等）を点検。

### 県ページのインデックス遅延
2026-06-30 確認、機種ページ・トップ・ランキングは全部登録済みだが、`/prefectures/:slug` 5本は未登録（リクエスト送信済み）。今回は手動投入で対応したが、根本的には県ページへの内部リンク導線が弱い可能性。トップ/ランキング/機種詳細から県ページへの自然な戻り線・関連リンクを増やす検討。

### 検索UIの使い勝手改善
- 設備フィルタの項目数・優先度の見直し
- ユーザーテスト or 分析データに基づく判断

### ~~機種名の旧字体フィルタ問題~~ ✅ 済 (2026-06-24)
autocomplete に `translate()` 旧字体正規化を追加。全検索パスで対応済み。

---

## データ品質

### ~~MachineModel 重複統合の定期化~~ ✅ 済 (2026-06-24)
`MonthlyShopDetailsJob` に `merge_duplicates` ステップを追加。毎月1日の月次バッチで自動実行。

### 設置機種未掲載店舗（約1,002件）
DMMぱちタウン側で `#anc-slot` セクションがないパチンコ専門店・小規模店。「データ未取得」表示が出ているか確認。

### ~~SnsReport 廃止~~ ✅ 済 (2026-06-24)
テーブル・モデル・Admin・View・Service・Rake・Spec を全削除。

---

## 機能追加・検討

### ランキングメニューの露出調整
記録UIが本筋。ランキングを前面に出しすぎると「ゲーミフィケーション目的の投稿」でデータ品質が落ちるリスク。ナビ位置・配色の優先度を下げる検討。

### 機種画像の表示（検討中）
著作権問題あり。代替案のタイプ別バッジは実装済み。

### クリック計測（Promotion v2）
`/r/:promotion_id` リダイレクトエンドポイントで `clicks_count` インクリメント。未実装。

---

## 相棒ペット

### MVP（本番稼働中 2026-06-23〜）
4段階一本道 (egg→baby→child→adult)、Vote/PlayRecord で exp、進化トースト、ドット絵PNG。

### 壮大版（未着手）
仕様書: `docs/companion_spec.md` (v0.6)
- 6段階×4系統分岐 (reader/nushi/dawn/wanderer)
- 色違い（パレット替え半自動）
- ご当地ヨミ（8地方ブロック→47県）
- ドット絵生成パイプライン構築（Nano Banana Pro → Pixel Snapper → Aseprite）
- `VoterProfile` への species/stage/variant カラム追加

---

## バグ調査

### 細かいバグの洗い出し
- ブラウザコンソールのエラー監視
- 投稿フローのエッジケース（同日複数投稿、Cookie削除後の再投票）
- モバイル特有の挙動（タップ範囲、SafariのCookie制限）

---

## 広告 / 収益化

### ASP 本格登録→案件有効化
- A8.net / もしもアフィリエイト / バリューコマース 登録
- 各案件の提携申請→承認→アフィリエイトURL取得
- ActiveAdmin から `target_url` 更新 + `active: true`
- Render env に `PROMOTIONS_ENABLED=true` 設定

### 広告スロットの実測→最適化
7 スロット定義済み。実運用データでクリック率を測り、効果の低い位置は削除、別の自然な位置を追加検討。

### 収益化プラン策定
- 現在のインフラ費用: 月 $28〜35（Render Singapore × 4 services + DB Basic $6/mo）
- 損益分岐 PV の算出
- ASP 案件別の期待 EPC 試算

### 特商法ページの実名化
`/legal/tokushou` は現在「請求があった場合に遅滞なく開示」方式。金融系案件取扱開始時に実名・所在地表記に切り替え必要。

---

## セキュリティ

2026-06-26 レビューで HIGH 4件検出。公開CGM・ASP審査前なので優先度高。

### [HIGH] voter_token Cookie を `cookies.signed` 化
現状 `cookies[:voter_token]` plain text。改ざんで他人の voter_token を名乗ると Vote/PlayRecord を update/destroy 経由で書き換え可能。`cookies.signed[:voter_token]` (or `encrypted`) に切替 + `secure: Rails.env.production?` 明示。既存 token 互換のため 30日のフォールバック層を入れて移行。

### [HIGH] `play_records_controller#create` の `return_to` Open Redirect 修正
`redirect_to params[:return_to]` のチェックが `start_with?("/")` のみで `//evil.com` や `/\evil.com` を通過させる。`\A/[^/\\]` 正規表現で先頭 `//` `/\` を除外、または `URI.parse(...).relative? && !host` で検証。

### [HIGH] Promotion `target_url` を自社ハンドラ経由化 + ASP ドメイン allowlist
現状 `_promotion_banner.html.erb` / `_promotion_card.html.erb` で `target_url` を直接 href。`/p/:id/click` ハンドラ経由でクリック計測も兼ねる構造に変える。`rel="sponsored noopener noreferrer"` に統一（現状 `noreferrer` 欠落）。

### [HIGH] Devise lockable 有効化 + sign_in 専用 throttle
`/admin` への brute force 対策。`User` モデルに `:lockable, :timeoutable` 追加 + `maximum_attempts: 10`。`config/initializers/rack_attack.rb` に `/users/sign_in` 専用 throttle 5/min/ip 追加。

### [MED] その他
- rack_attack に `shop_reviews_create/ip` (10/hour) と `shop_autocomplete/ip` (60/min) 追加
- CSP `script-src` の nonce ジェネレータを session.id ベース → `SecureRandom.base64(16)` に
- Strict-Transport-Security ヘッダを明示 (`max-age=63072000; includeSubDomains; preload`)
- プライバシーポリシーに IP/UA 保持期間明記（個人情報保護法）

---

## インフラ / 運用

### ~~エラー監視の導入~~ ✅ 済 (2026-06-24)
Sentry 導入済み（コミット 1302056）。

### ~~アクセス解析の導入~~ ✅ 済 (2026-06-26)
GA4 (`G-BPNX0BSC9H`) + Cloudflare Web Analytics 両方導入。ENV: `GA4_MEASUREMENT_ID` / `CLOUDFLARE_ANALYTICS_TOKEN`。

### ~~独自ドメイン取得~~ ✅ 済 (2026-06-26)
`yomislo.com` 取得（ムームー）→ Cloudflare DNS → Render Custom Domain + Let's Encrypt SSL。`yomislo.onrender.com` から 301 リダイレクト稼働中。

### Cloudflare Proxy 化（任意）
現在 DNS only モード。Proxied (オレンジ雲) に切替で CDN/WAF/Bot対策が有効化。**前提**: Cloudflare SSL/TLS モードを「Full (strict)」に変更しないとリダイレクトループする。

### アップタイム監視
UptimeRobot 無料枠等でダウン検知。

### Render リージョンの再検討
現在 Singapore。日本ユーザー向けには Tokyo が理想だが Render は未対応。レイテンシ 70-100ms 程度。将来的に Render Tokyo or 安価 VPS (Lightsail Tokyo) への移行検討。

### DB バックアップ運用
Render Basic プランの自動バックアップ有無を確認。なければ `pg_dump` cron 追加。

### テストカバレッジ拡充
現在 610 examples / 48.5% coverage。コア機能（Vote, PlayRecord, スクレイピング）の重点的なカバー拡充。

### E2E テスト導入 (capybara-playwright)
現状 `spec/system/` は `driven_by :rack_test` 一択で JS 動かず（`voting_flow_spec` で2件 pending）。記録UI（最重要・配列カラム JS バグの再発リスク）を JS 実行込みで検証する。
- 導入: `Gemfile` に `capybara-playwright-driver` 追加、`package.json` に `playwright`、`npx playwright install chromium`
- `spec/support/capybara.rb` に `:playwright` ドライバ登録、`js: true` 時のみ駆動
- 最小E2E 2本:
  - `voting_flow_spec.rb` の pending 解除 — `confirmed_setting` が配列で着弾することを assert
  - `play_record_flow_spec.rb` 新規 — タグチップ複数トグル → `PlayRecord.tags` 配列確認
- CI 限定運用（Render Starter 本番に Chromium 載せない）
- `.claude/skills/webapp-test/` 薄いスキル化検討（FactoryBot シード・voter_token Cookie 仕込み・Turbo Frame 待機の3点）

---

## 完了済み

| タスク | 完了時期 |
|--------|---------|
| 独自ドメイン yomislo.com 移行（Cloudflare DNS + Render Custom Domain + SSL + 301リダイレクト） | 2026-06-26 |
| ファビコン・PWAアイコンを相棒ペット(baby)に差し替え、背景透過 | 2026-06-26 |
| SEO 文言を打ち手目線に刷新（AIっぽい言い回し排除） | 2026-06-26 |
| GA4 + Cloudflare Web Analytics 導入 | 2026-06-26 |
| Sentry エラー監視導入 | 2026-06-24 |
| Postgres Free → Basic ($6/mo) 移行 | 2026-06-22 |
| Puma cluster mode 警告解消 | 2026-05-25 |
| geocode 未取得 347件 → 1件に解消 | 2026-05-25 |
| 住所 `...` truncation 修正 (388件) | 2026-05-25 |
| 相棒ペット MVP 本番稼働 | 2026-06-23 |
| 称号・バッジをペットに統合 | 2026-06-23 |
| UI全体改修（記録ファースト店舗ページ等） | 2026-06 |
| Promotion 広告システム実装・デプロイ | 2026-05-20 |
| ASP審査用ポリシー4枚整備 | 2026-05 |
| 交換率ユーザー投稿機能 実装 | 2026-03 |
| DMMぱちタウン完全一本化 | 2026-04 |
| 全国横断検索 `/search` | 済 |
| 機種逆引き・設置店舗フィルタ | 済 |
| 店舗レビュー・イベント投稿 | 済 |
| ユーザー店舗登録申請 | 済 |
| PWA対応・ダークモード | 済 |

---

## メタ

- 作成: 2026-05-21
- 最終更新: 2026-06-26
- 関連: `docs/ROADMAP.md`（フェーズ別計画）、`docs/companion_spec.md`（ペット仕様書）
