# ヨミスロ BACKLOG

実装済みの機能改善・調査タスクを積んでおくバックログ。優先度や着手予定は項目ごとに決める。
作業着手時は GitHub Issue 化するか、直接ブランチ切って進める。

> **最終更新: 2026-07-01**
> セキュリティ HIGH 4件 + MED 4件 全消化 / SEO Product schema・県ページ内部リンク導線 / a11y aria-pressed / レトロ化 Phase 1-4 + ドラクエ脱色。ASP審査前チェック完了。

## 目次

- [🎯 次の優先候補](#-次の優先候補)
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

## 🎯 次の優先候補

セクション別リストの中から、次に着手すべきものを抜粋。

### 🟡 中優先 (私が単独で進められる)
- **マイクロコピー横断レビュー** — プレースホルダー/空状態/エラーメッセージのAIっぽい硬さ排除 (`copy-reviewer` エージェント活用)
- **Turbo Frame 更新後のフォーカス管理** — vote 投稿後の autofocus 復元 (a11y MED残)
- **ランキングメニュー露出調整** — ゲーミフィケーション目的の投稿でデータ品質が落ちるリスク対策
- **検索UI の設備フィルタ項目数見直し**
- **設置機種未掲載店舗（約1,002件）の「データ未取得」表示確認**
- **収支記録の「タグ」入力UI実装** — バックエンド(モデル/params/Stimulusコントローラ)は実装済みだが入力UIが未接続の状態を解消。SNSシェア導線と組み合わせれば新規流入チャネルになり得る（詳細は「機能追加・検討」参照）
- **相棒ペットの初見説明ツールチップ追加** — 初回訪問時に「記録するたび育つ」ことが伝わらずリテンション機会を逃している（詳細は「機能追加・検討」参照）

### 🔵 ユーザー行動が必要
- **ASP 本格登録→有効化** — A8/もしも/バリューコマース アカウント作成→提携申請→承認→`target_url` 更新 → Render env `PROMOTIONS_ENABLED=true` セット
- **特商法ページの実名化** — 金融系案件開始時に必要 (時期次第)
- **Cloudflare Proxy 化** — SSL/TLS を "Full (strict)" に切替後、Proxied モードに (CDN/WAF/Bot対策)
- **UptimeRobot 等アップタイム監視** — アカウント作成 → yomislo.com/up 監視設定
- **公式X(Twitter)アカウント運用** — 2026-07-08時点でGA4上のSNS流入が0件。「今日の朝イチリセット情報まとめ」等の定期発信でSNS経由の新規流入チャネルを作る（アカウント作成が必要なため対応不可）
  - **2026-07-10 運用方針ドラフト作成済み**: 投稿数がまだ少なくデータ駆動型投稿（朝イチリセット情報まとめ等）は時期尚早と判断し、投稿数に依存しないコンテンツ（機能紹介・参加呼びかけ・豆知識・ランキング紹介）から開始する方針に整理。初期投稿サンプル4件をcopy-reviewerでトーンチェック済み（AIっぽい硬語なし、修正不要）。アカウント作成後に運用開始可能
- **GA4のキーイベント設定** — 「投稿する」「収支を記録する」等のコンバージョンをGA4管理画面でキーイベントとして登録し、流入経路別の投稿転換率を追跡できるようにする
  - **2026-07-09 判明**: GA4管理画面確認の結果、カスタムイベント自体が未実装だった（`click`/`page_view`等の自動収集イベントのみで「投稿する」「収支を記録する」は存在せず、キーイベント登録の前段階が未着手）
  - ✅ コード対応済み: `vote_controller.js`・`play_record_form_controller.js` に `turbo:submit-end` を監視して成功時に `gtag('event', 'vote_submit')` / `gtag('event', 'play_record_submit')` を送信する処理を追加
  - 残: 本番デプロイ後、実際にイベントが発生してGA4の「イベント」一覧に表示されてから、管理画面でスターを押してキーイベントとしてマークする操作が必要（イベントが1件も発生していない状態ではマークする対象が存在しない）
- **UGCブートストラップ戦略の検討** — 全国5,999店を薄く広くではなく主要エリアに絞ってデータ密度を上げる方針の要否判断（累計投稿9件と少なく、コンテンツの薄さが未インデックス問題の一因）
  - **2026-07-09 方針決定**: 起点は熊本県（店舗103件、うち設置機種データあり83件）。理由は運営者自身が実際に打つ現実的な行動範囲であること。県ページ自体の検索表示回数は3か月間ゼロで東京/大阪/埼玉/神奈川のような既存SEO追い風は無いが、機能している唯一の経路（店舗名の指名検索）は県の知名度と無関係のため不利にはならない。103店舗に薄く投稿するのではなく、実際に打つ数店舗に絞って複数回投稿し、各店舗ページを「情報が載っているページ」にすることを優先する

### 🟣 大タスク (工数大・要計画)
- **相棒ペット壮大版** — 6段階×4系統分岐、ご当地ヨミ、ドット絵生成パイプライン (docs/companion_spec.md v0.6)
- **E2E テスト導入 (capybara-playwright)** — 記録UI・配列カラムJSバグ再発防止、CI 限定運用
- **テストカバレッジ拡充** — 現在 615 examples / 49% coverage → コア機能を70%程度に

---

## UI / UX

### ~~レトロ化 Phase 1-4 + ドラクエ脱色~~ ✅ 済 (2026-07-01)
レトロ案 (`ヨミスロ レトロ案.html`) を参考に、UXを損なわない範囲でファミコン／ドラクエ調の世界観を強化。過去教訓「フルドラクエ化やりすぎ」に基づき、フォント/▶/配色/四角ばりでレトロ感を出す原則を全面適用。
- **Phase 1** (見た目・トークン): ワールドマップ地域タイル (地域固有色▶) / pt→ゴールド統一 / ヒーロー打ち手口調 4種ローテ / dark=ダンジョン(scanlines)+light=そうげん(world-meadow) / `dot_bar` ヘルパー追加
- **Phase 2A** (記録フィードバック小): `_gold_toast` 丸ピル (1.4s dismissable) — 新規vote時のみ
- **Phase 2B** (マイルストーン): `_milestone_toast` .rpg-window--glow (5s dismissable) — 記録10/100/1000件、連続7/30日、初高設定4-6
- **Phase 3** (マイステータス強化): 相棒＆称号カード (.rpg-window) + 「▶ スコア」窓 (dot_bar 3本: 記録/連続/ゴールド)
- **Phase 3+** (ヘッダー統一): 店舗ヘッダーを .rpg-window 主役化、機種ヘッダーに▶+font-heading
- **Phase 4** (フォント微調整): score-num統一 / ランキング1/2/3を色付き大数字 / 収支カレンダー装飾
- **ドラクエ脱色**: ぼうけんのしょ→マイステータス、つよさ→スコア、なまえを→ユーザー名を、深夜ヒーローの「ぼうけんのしょへ」削除。RPG一般用語(Lv./ゴールド/称号)は残す
- DESIGN.md / feedback_design_system.md 反映済み

### レトロ化 残候補 (低優先)
- 記録行 (`_machine_vote_row`) の色味最終調整 (記録動線を絶対に触らない範囲で)
- ホーム/店舗詳細でまだ Inter のままの「大きめ数字」を随時 `.score-num` に (点検要)

### UI・UX 全体の見直し・改修
DESIGN.md と照合してサーフェス階層・余白・カラートークン使用の一貫性を再点検する。

### 細かいテキストの文章検討
プレースホルダー、空状態、エラーメッセージ、ボタンラベルなどのマイクロコピーを横断レビュー。AIっぽい硬さが残っている箇所を絞る（feedback_copywriting 参照）。

### ~~ロゴ・キャッチコピーの再検討~~ ✅ 済 (2026-07-01)
ヒーロータグラインを打ち手口調に刷新：「今日のリセットを 読み解け！」「みんなの記録で 設定を 暴け！」「今日の勝負の1台を 記録しよう」「今日の結果を 振り返ろう」の時間帯4種ローテ (ドラクエ寄りワードは除去済)。

### アクセシビリティ (WCAG 2.1 AA)
2026-06-26 レビューで HIGH 4件・MED 7件検出 → 2026-06-30 HIGH 全消化＋MED 主要3件＋DESIGN.md チェックリスト追記済。
- ~~**[HIGH] ライトモード `--primary` を `#10b981` → `#059669` に下げる**~~ ✅ 済 (2026-06-30) `--primary` / `--accent` / `--ring` を `#059669` に変更、白文字 CTA で AA 通過
- ~~**[HIGH] `bg-setting-4 text-white` / `bg-vote-yes text-white` 等の白文字配色見直し**~~ ✅ 済 (2026-06-30) `_machine_vote_row.html.erb` の selected/confirmed/vote-yes/vote-no を「明るい背景=`text-gray-900`、暗い背景=`text-white`」ルールに統一
- ~~**[HIGH] `--text-tertiary:#9ca3af` を `#6b7280` 相当に**~~ ✅ 済 (2026-06-30) ライトモード token を `#6b7280` に更新
- ~~**[HIGH] お気に入り星ボタンの `aria-pressed`/`aria-label` を Stimulus でトグル**~~ ✅ 済 既に `favorite_controller.js#updateUI` で `connect()` 時に動的トグル済み（BACKLOG が古かっただけ）
- ~~[MED] トースト/エラーへ `aria-live`~~ ✅ 済 (2026-06-30) `_flash` notice=`role=status/aria-live=polite`、alert / `_errors` / `_form_errors` を `role=alert/aria-live=assertive`
- ~~[MED] `prefers-reduced-motion` 対応を `.animate-*` 全般に拡張~~ ✅ 済 (2026-06-30) `application.css` 末尾にグローバル `* { animation-duration: 0.001ms !important }` ブロックを追加
- ~~[MED] モーダルに focus trap + `role="dialog"`~~ ✅ 済 (2026-06-30) `record-modal` を `role="dialog" aria-modal aria-labelledby tabindex=-1` 化、open/close で 前フォーカス保存→復帰の軽量実装
- [MED] 残り: Turbo Frame 更新後のフォーカス管理（vote 投稿後 autofocus）、ボトムナビ active の `.dq-cursor--blink` 点滅停止条件（reduced-motion 対応は既にCSSで実装済）
- ~~DESIGN.md に a11y チェックリスト 5項目追記~~ ✅ 済 (2026-06-30)
- ~~[MED] 確定設定トグル群へ `aria-pressed`~~ ✅ 済 (2026-07-01) `_machine_vote_row.html.erb` の 設定1-6 / 確定情報タグ / リセットあり・据置 の全ボタンに `aria-pressed` + `aria-label` (「記録済み/未記録」を明示)

---

## 検索 / 発見性

### SEO 構造化データの網羅性
- 構造化データ (LocalBusiness / WebSite / SearchAction) の追加余地
- ~~店舗・機種ページの title / description テンプレート最適化~~ ✅ 済 (2026-06-26) AIっぽい言い回し排除、打ち手目線に刷新
- Google Search Console でのインデックス状況確認（新ドメイン yomislo.com、明日以降にページ/検索パフォーマンスを確認）
- ~~**サイトマップ取得失敗の解消**~~ ✅ 済 (2026-06-26) `https://yomislo.com/sitemap.xml.gz` 送信成功、6,701ページ検出
- ~~主要URLの個別インデックス登録リクエスト~~ ✅ 済 (2026-06-30) トップ/ランキング/機種5本は既に登録済み、県5本（tokyo/osaka/aichi/hokkaido/kanagawa）はリクエスト送信完了
- **アドレス変更ツールが Render の Cloudflare で失敗する件**: 旧 yomislo.onrender.com への Googlebot アクセスが Cloudflare Bot Challenge でブロック。301は効いているのでGoogleの自然学習に任せる（数週間〜数ヶ月）

### ~~未インデックスページ6,020件（うち検出-未登録5,717件）への対処~~ ✅ 一部対応 (2026-07-08)
Search Console 確認で判明: 登録済み1,500件に対し未登録6,020件、大半が「検出-インデックス未登録」。投稿(Vote)が一件もない過去日付ページ（`/shops/:slug/dates/:date`）が空の重複コンテンツとしてクロール評価を下げていると推定。
- ✅ `ShopsController#load_shop_data` で、過去日付ページかつ該当日の `VoteSummary.total_votes` 合計が0の場合のみ `noindex: true` を設定（当日ページ・投稿ありページは対象外、店舗の基本情報自体に価値があるため canonical な `/shops/:slug` は常にindex維持）
- ✅ ホームページに `<h1>` が存在しなかった問題を修正（`app/views/home/index.html.erb` のヒーロータグライン `<p>` → `<h1>`）
- 残: 主要エリア（東京23区/大阪/名古屋等）に絞ったUGC密度向上策の検討（下記「UGCブートストラップ戦略の検討」参照）

**2026-07-09 追加調査**（未登録件数は7/8時点から変化なし＝6,020件、うち検出-未登録5,717件・クロール済み-未登録291件）:
- 「ヨミスロ」「yomislo」で個別にクエリフィルタをかけた結果、直近3か月間で表示回数0件を確認。ブランド名検索は機能していない
- 実際にクリックが発生している検索経路は「店舗名の指名検索」（店舗詳細ページ）と「県名+スロット/パチスロ」（県ページ、表示のみでクリックはほぼ0）の2系統のみ
- 都道府県ページ同士の相互リンク追加は検討したが見送り。ホームの地域タイルが既に全47都道府県ページへ1ホップでリンクしており、クロール発見性への追加効果が薄い一方、実際のユーザーが他県情報を求める頻度は低く UX コストに見合わない
- 結論: 技術的SEO（構造化データ・サイトマップ・robots.txt・内部リンク）は打ち手が尽きた状態。残るレバーは UGC 密度向上のみ

### ~~記録後のSNSシェア導線がなかった件~~ ✅ 一部対応 (2026-07-08)
GA4確認でSNS経由の流入が0件だったため、マイルストーン達成（記録10/100/1000件・7/30日連続・高設定初記録）時のトーストに X (Twitter) シェアボタンを追加 (`app/helpers/ui_helper.rb#milestone_share_url`, `app/views/votes/_milestone_toast.html.erb`)。Web Intent URL方式のため追加のAPI連携・認証は不要。個人特定情報（店舗名・機種名等）は文言に含めない設計。
- 残: 収支記録（PlayRecord）側の「勝ち報告」シェア、投稿結果を画像カード化する案は未着手

### ~~機種ページの商品スニペット構造化データ修正~~ ✅ 済 (2026-07-01)
`app/views/machines/show.html.erb` の JSON-LD を `Product` 単体 → `Article + about: Thing (additionalType: Product)` に変更。ページ全体は Article として author/publisher/mainEntityOfPage を明示し、機種情報は about 配下の Thing で表現。Search Console の「offers 必須」警告を回避しつつ SEO 効果を維持。数週間後の Search Console 再クロールで警告消失を確認。

### ~~県ページのインデックス遅延~~ ✅ 済 (2026-07-01) の一部対応
- 手動投入で既に登録は完了済 (2026-06-30)
- 内部リンク導線強化 ✅ 済 (2026-07-01):
  - **フッターに主要8県ダイレクトリンク**追加 (東京/大阪/愛知/北海道/神奈川/埼玉/千葉/福岡) — 全ページから県ページへの常時アクセス
  - **機種詳細の県フィルタ選択時に「◯◯県の店舗一覧をすべて見る」リンク**追加 — 機種→県の自然な導線
- 数週間後の Search Console クロールでインデックス浸透を確認

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

### ~~クリック計測（Promotion v2）~~ ✅ 済 (実装済み)
`/p/:id` (promotion_click_path) ハンドラで `Promotion#increment_clicks!` 実装済み。ドメイン allowlist (a8.net等6ドメイン) も 2026-07-01 に追加。

### 収支記録のタグ入力UI実装（2026-07-09 動作確認で発見）
`PlayRecord#tags`（ロングフリーズ/天井/朝一/万枚等）はモデルのバリデーション・`play_records_controller.rb#play_record_params`のパラメータ許可(`tags: []`)・`tag_select_controller.js`まで揃っているが、収支記録モーダル(`/play_records`)にも店舗詳細のクイック記録フォームにも入力UI（タグチップ）が一切renderされておらず、実質どこからも設定不可能なデッドコード。
- 実装対象: `app/views/play_records/_entry_fields.html.erb`（または該当フォームパーシャル）にタグチップUIを追加し、既存の`tag_select_controller.js`と`tags[]`パラメータに接続する
- 効果: タグ付き収支をSNSシェアできる導線と組み合わせれば、既存のマイルストーンXシェア（2026-07-08追加）と並ぶ新規流入チャネルになり得る。現状GA4でSocial/Referral流入が0件なので優先度は高め
- 前提修正: `spec/`のE2Eテスト導入計画にある「タグチップ複数トグル → `PlayRecord.tags`配列確認」は、このUI実装が前提になる（現状は書けない）

### 相棒ペットの初見説明ツールチップ追加（2026-07-09 動作確認で発見）
マイステータス(`/voter/status`)の相棒ペット表示が「ぽこぽこ Lv.2」「次の姿まで83%」等の数値のみで、初見ユーザー向けに「記録するたびに育つ相棒」という説明が`_pet.html.erb`・`voter/status.html.erb`のどこにも存在しない。初回訪問時の軽いツールチップ追加でリテンション動線として機能させたい。

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

### ~~収支記録フォームで店舗未選択のまま送信すると Translation missing になる~~ ✅ 済 (2026-07-08)
`/play_records` の収支記録モーダルで、店舗名を入力しただけで候補を選択せずに送信すると `belongs_to :shop` の必須バリデーションに引っかかり、`Shop Translation missing...` が表示される不具合。
- **根本原因1**: `app/views/play_records/index.html.erb` の `shop_id` hidden input に `required` 属性を付けていたが、HTML5仕様上 `type="hidden"` には required 検証が効かず、店舗未選択のまま送信できてしまっていた
- **根本原因2**: `config/locales/ja.yml` に `errors.messages.required` および `activerecord.attributes.play_record.shop` の翻訳が無く、Railsのデフォルトフォールバックで英語混じりの未翻訳文言が出ていた
- 対応: `play_record_form_controller.js#validateSubmit` に店舗未選択チェックを追加（送信前にJSでブロック+アラート表示）、ja.ymlに両翻訳キーを追加（サーバー側バリデーションが露出した場合のフォールバックとしても機能）

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

2026-06-26 レビューで HIGH 4件検出 → 2026-07-01 全消化。ASP審査前チェック完了。

### ~~[HIGH] voter_token Cookie を `cookies.signed` 化~~ ✅ 済 (2026-07-01)
`application_controller.rb` で signed + legacy plain の自動移行フォールバック完備。restore アクションも `cookies.signed[:voter_token]` に変更 (voter_controller.rb:52)。1年有効・httponly・secure(本番のみ) を `voter_token_cookie_options` に集約。

### ~~[HIGH] `play_records_controller#create` の `return_to` Open Redirect 修正~~ ✅ 済 (2026-07-01 発見時には既に対応済み)
`safe_return_to` で `\A/[^/\\]` パターンにより先頭 `//` `/\` を除外済み (play_records_controller.rb:261-266)。

### ~~[HIGH] Promotion `target_url` を自社ハンドラ経由化 + ASP ドメイン allowlist~~ ✅ 済 (2026-07-01)
- `/p/:id` (promotion_click_path) ハンドラ経由 + `clicks_count` インクリメント (以前から実装)
- `rel="sponsored noopener noreferrer"` 統一 (以前から実装)
- ASP ドメイン allowlist `ALLOWED_HOSTS` を promotions_controller.rb に追加 (a8.net / moshimo.com / valuecommerce.ne.jp / linksynergy.com / afl.rakuten.co.jp / accesstrade.net)。サブドメインは末尾一致で許可。未知ホストは root_path へ 302

### ~~[HIGH] Devise lockable 有効化 + sign_in 専用 throttle~~ ✅ 済 (2026-07-01)
- `User` モデルに `:lockable, :timeoutable` (`db/migrate/20260630084356_add_lockable_to_users.rb` で failed_attempts/unlock_token/locked_at 追加、schema.rb 反映済)
- `config/initializers/devise.rb`: `maximum_attempts: 10`, `unlock_in: 30.minutes`, `timeout_in: 12.hours`, `last_attempt_warning: true`
- `config/initializers/rack_attack.rb`: `admin_sign_in/ip` throttle (5/min/ip)

### ~~[MED] その他~~ ✅ 済 (2026-07-01)
- ~~rack_attack に `shop_reviews_create/ip` (10/hour) と `shop_autocomplete/ip` (60/min) 追加~~ ✅ 済
- ~~CSP `script-src` の nonce ジェネレータを session.id ベース → `SecureRandom.base64(16)` に~~ ✅ 済
- ~~Strict-Transport-Security ヘッダを明示 (`max-age=63072000; includeSubDomains; preload`)~~ ✅ 済 `config.ssl_options = { hsts: { expires: 2.years.to_i, subdomains: true, preload: true } }` を production.rb に明示
- ~~プライバシーポリシーに IP/UA 保持期間明記（個人情報保護法）~~ ✅ 済 privacy.html.erb に「1-2. 情報の保持期間」セクションを追加 (IP/UA: 最大90日、Cookie: 1年、投稿データ: サービス継続中、お問い合わせ: 1年)

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
| レトロ化 Phase 1-4 + ドラクエ脱色（世界観強化、UX無影響） | 2026-07-01 |
| セキュリティ HIGH 4件 全消化（voter_token signed / Open Redirect / Promotion allowlist / Devise lockable） | 2026-07-01 |
| セキュリティ MED 4件 消化（rack_attack 追加 / CSP nonce / HSTS / プライバシー保持期間） | 2026-07-01 |
| SEO 機種 Product schema 修正（Article + about:Thing、Rich Results 警告回避） | 2026-07-01 |
| SEO 県ページ内部リンク導線強化（フッター主要8県 + 機種詳細の県別リンク） | 2026-07-01 |
| a11y 記録行トグルに aria-pressed + aria-label 追加 | 2026-07-01 |
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
| Promotion 広告システム実装・デプロイ (クリック計測ハンドラ + rel=sponsored 統一含む) | 2026-05-20 |
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
- 最終更新: 2026-07-01
- 関連: `docs/ROADMAP.md`（フェーズ別計画）、`docs/companion_spec.md`（ペット仕様書）、[DESIGN.md](DESIGN.md)（UI規約）
