---
name: daily-health-check
description: >
  Search Console / GA4 / Render Dashboard / DB / BACKLOG を毎朝一括で健康診断し、
  異常や改善余地を Cowork チップとして発行する。ローカル Markdown ファイルには保存せず、
  翌朝のセッションでチップとして直接確認できる状態を作る。
  Use proactively when:
  - launchd から毎朝8:00に自動起動された (claude -p "/daily-health-check")
  - ユーザーが「毎朝チェック」「ヘルスチェック」「アクセス状況」「集客状況」の確認を依頼した
  - ユーザーが「daily-health-check」「デイリーチェック」「今日の状況」を依頼した
  - GSC / GA4 / Render の状況を横断確認したい時
---

# Daily Health Check

Search Console / GA4 / Render Dashboard / DB の状況を毎朝横断チェックし、
異常・改善余地を **Cowork チップ** として発行するスキル。
ファイルには保存せず、次回セッションで自動表示されるタスクチップとして届ける。

## 前提

- Chrome (Browser 1, deviceId `95cc73c0-de4c-4f2d-be8f-62b8ecc0dc2e`) が起動し、`pocopoco79@gmail.com` で GSC / GA4 / Render にログイン済み
- postgres MCP (`mcp__postgres__query`) 接続可能 (localhost/yomislo_development)
- Cowork Directory (`mcp__ccd_session__spawn_task`) が使える

Chrome MCP のツールが deferred の場合、実行冒頭で ToolSearch を叩いて一括ロード:
```
select:mcp__Claude_Browser__tabs_context,mcp__Claude_Browser__navigate,mcp__Claude_Browser__read_page,mcp__Claude_Browser__get_page_text,mcp__claude-in-chrome__select_browser
```

## 実行手順

### Step 0: 準備
1. `Bash date "+%Y-%m-%d"` で今日の日付を取得 (以下 `TODAY`)
2. Chrome MCPツールを ToolSearch でロード
3. 必要なら `mcp__claude-in-chrome__select_browser` で Browser 1 (deviceId `95cc73c0-de4c-4f2d-be8f-62b8ecc0dc2e`) を選択
4. Chromeが起動していない場合は `Bash open -a "Google Chrome"` を実行し、10秒 sleep

### Step 1: Search Console

URL: `https://search.google.com/search-console?resource_id=sc-domain%3Ayomislo.com`

取得項目:
- **インデックス登録**: 登録済み件数 / 未登録件数 (`/search-console/index?...`)
- **検索パフォーマンス3日集計**: 合計クリック / 表示回数 / 平均CTR / 平均掲載順位 (`/search-console/performance/search-analytics?num_of_days=3`)
- **クロールエラー**: エラー件数
- **拡張レポート「商品スニペット(Product)」**: 無効件数 (2026-07-14修正後は0に向かうはず。要監視)
- **新規検出クエリ**: 表示回数トップ5

操作:
1. `navigate` で `https://search.google.com/search-console/index?resource_id=sc-domain%3Ayomislo.com` を開く
2. `get_page_text` で数値を抽出。「ログイン」「Sign in」等が含まれる場合はセッション切れ扱い
3. `navigate` で performance URL、product-snippets URL を順に開き同様に抽出
4. 前日の値との差分計算 (次項 [Step 6] を参照)

### Step 2: GA4

URL: `https://analytics.google.com/analytics/web/`

取得項目:
- 過去24時間: 新規/継続ユーザー数
- 平均エンゲージメント時間
- 流入経路比率 (直接/オーガニック/SNS/参照)
- **キーイベント設定状況** (未設定なら要注目リストに追加)

操作:
1. `navigate` で GA4 レポート概要ページを開く
2. `read_page` でウィジェットの数値を抽出
3. キーイベント: `https://analytics.google.com/analytics/web/#/pXXXXX/admin/events/key-events` を開き、設定件数0なら未設定判定

### Step 3: Render Dashboard

URL: `https://dashboard.render.com/`

取得項目:
- Web Service `yomislo` 直近 Deploy: Success / Failure / 時刻
- 3 cron の直近24h実行結果: `daily-refresh` / `daily-aggregation` / `monthly`
- **Web Service 再起動回数(24h)**: Metrics タブの Event timeline から `Instance failed:` の件数を数える。4件以上でOOM再発の異常チップを発行
- メモリ使用率スパイク (Metrics タブ、直近24h)

対象URL:
- Deploys: `https://dashboard.render.com/web/srv-d863tqlckfvc73ec34fg/deploys`
- Metrics: `https://dashboard.render.com/web/srv-d863tqlckfvc73ec34fg/metrics`
- Cron 1: `https://dashboard.render.com/cron/crn-d863tqlckfvc73ec34d0` (daily-refresh)
- Cron 2: `https://dashboard.render.com/cron/crn-d863tqlckfvc73ec34e0` (daily-aggregation)
- Cron 3: `https://dashboard.render.com/cron/crn-d863tqlckfvc73ec34eg` (monthly)

操作:
1. `navigate` → `read_page` (または `get_page_text`) の順で各URLを巡回
2. Deploy一覧の「Live」「Failed」ステータスと時刻を抽出
3. cron の Events タブから直近実行の Exit Code を抽出
4. Metrics ページの `Event timeline` セクションを `get_page_text` で取得し、`Instance failed:` の出現回数を過去24hで数える (4件以上で異常チップ発行)

### Step 4: DB (postgres MCP)

`mcp__postgres__query` で以下を実行:

```sql
-- Feedback 未対応件数 (unread + read、resolved は除外)
SELECT COUNT(*) AS feedback_pending FROM feedbacks WHERE status < 2;

-- 昨日の投稿件数
SELECT COUNT(*) AS vote_yesterday FROM votes WHERE voted_on = CURRENT_DATE - 1;
SELECT COUNT(*) AS play_record_yesterday FROM play_records WHERE played_on = CURRENT_DATE - 1;

-- 昨日のユニーク voter_token 数 (Vote + PlayRecord 合算)
SELECT COUNT(DISTINCT voter_token) AS active_voters_yesterday FROM (
  SELECT voter_token FROM votes WHERE voted_on = CURRENT_DATE - 1
  UNION
  SELECT voter_token FROM play_records WHERE played_on = CURRENT_DATE - 1
) t;

-- 累計投稿件数(週次比較用)
SELECT COUNT(*) AS votes_total FROM votes;
SELECT COUNT(*) AS play_records_total FROM play_records;

-- 過去7日の投稿数推移
SELECT voted_on, COUNT(*) FROM votes
  WHERE voted_on >= CURRENT_DATE - 7 GROUP BY voted_on ORDER BY voted_on DESC;
```

### Step 5: 今日の発見コーナー

1. `Read /Users/kasedashouta/develop/yomislo/BACKLOG.md` の先頭50行を取得し、上位3項目を抽出
2. `Read /Users/kasedashouta/.claude/projects/-Users-kasedashouta-develop-yomislo/memory/project_search_console_seo.md` を Read
3. 当日データと突き合わせ、AIから1件だけ改善提案を生成 (例: 「GA4新規ユーザーが7日連続0のため、キーイベント未設定の可能性。設定を提案する」)

### Step 6: 前日比較・異常判定

- 前日チップの取得を試みる: `mcp__ccd_session_mgmt__list_sessions` で過去のセッションから昨日日付の "ヘルスチェック" タイトルのものを探し、その prompt を parse
- 前日データが取れない場合は「初回」扱いで比較スキップ
- 判定基準表(下記)に基づき、正常 / 要注意 / 異常 を仕分け

## 判定基準

| 項目 | 正常 | 要注意(チップ内で強調) | 異常(追加チップ発行) |
|------|------|--------------------|--------------------|
| GA4 新規ユーザー | 前日比 ±30% | ±30〜50% | ±50%超 |
| GSC 表示回数(3日集計) | 前週比 -20%以内 | -20〜-40% | -40%超減 |
| GSC 未登録件数 | 前日比 ±50 | ±50〜100 | ±100超 |
| Render Deploy(24h) | 失敗0件 | - | 1件以上 |
| Render Web 再起動(24h) | 0件 | 1〜3件 | 4件以上（OOM再発シグナル） |
| Render cron(24h) | 3本すべて成功 | - | 1本でも失敗 |
| DB Feedback未対応 | 5件以下 | 6〜10件 | 10件超 |

## Cowork チップ発行

### メインチップ (常に1枚)

```
mcp__ccd_session__spawn_task({
  title: `ヘルスチェック ${TODAY}`,
  tldr: "新規X人 / GSCクリックY件 / 異常Z件",  // 1〜2文
  prompt: `# ヘルスチェック ${TODAY}\n\n## 1. Search Console\n- インデックス: 登録済み{N}/未登録{M} (前日比 {±X})\n- パフォーマンス3日: クリック{C}/表示{I}/CTR{R}%/順位{P} (前週比 {±X}%)\n- 商品スニペット無効: {N}件\n- 新規検出クエリTop5: {list}\n\n## 2. GA4\n- 新規/継続: {N}/{M}人 (前日比 {±X}%)\n- 平均エンゲージメント: {T}秒\n- 流入経路: 直接{P}%/オーガニック{P}%/SNS{P}%/参照{P}%\n- キーイベント設定: {設定済み/未設定}\n\n## 3. Render\n- Web直近Deploy: {Success/Failed} at {timestamp}\n- Web再起動(24h): {N}回 (4件以上でOOM再発シグナル、異常チップ発行)\n- Cron結果24h: daily-refresh={status} / daily-aggregation={status} / monthly={status}\n- メモリピーク: {N}MB\n\n## 4. DB\n- Feedback未対応: {N}件\n- 昨日のVote: {V}件 / PlayRecord: {P}件 / ユニーク投稿者: {U}人\n- 累計 Vote: {N}件 / PlayRecord: {N}件\n- 過去7日推移: {list}\n\n## 5. 今日の発見\n- BACKLOG上位3件: {list}\n- 改善提案: {AI proposal}\n\n---\n\n気になる観点があれば深掘りしましょう。異常項目は別チップで届いています。`
})
```

### 異常チップ (最大3枚、超過分はメインの prompt に列挙のみ)

```
mcp__ccd_session__spawn_task({
  title: `[異常] Render cron 'daily-refresh' 失敗`,
  tldr: "2026-07-15 18:00 UTC 実行が exit 1 で終了。ログ確認と再実行が必要。",
  prompt: `Render cron 'daily-refresh' (crn-d863tqlckfvc73ec34d0) が失敗しました。\n\n## 状況\n- 失敗時刻: ...\n- Exit code: ...\n\n## 推奨対応\n1. https://dashboard.render.com/cron/crn-d863tqlckfvc73ec34d0/logs でログ確認\n2. 手動再実行 (Manual Deploy)\n3. 原因調査 (このセッションで対応可)\n`
})
```

## トラブルシュート

### Chrome ログイン切れ検出
- `get_page_text` の結果に「ログイン」「Sign in」「アカウントを選択」等が含まれる場合はセッション切れ
- 該当セクションのデータは "取得不可(要ログイン)" として記録
- メインチップの tldr に「認証切れ X件あり」と明記し、異常チップも別途発行

### Postgres MCP 未接続
- `mcp__postgres__query` がエラーを返した場合はDB統計をスキップし、その旨をチップに記載

### spawn_task が呼べない (headless モードで問題発生時の代替)
- (A) `mcp__ccd_session_mgmt__send_message` で既存セッション宛に本文送信を試す
- (B) `mkdir -p ~/.claude/inbox && echo "$REPORT" > ~/.claude/inbox/daily-health-check-${TODAY}.md` で一時保存
- (C) それも失敗なら手動フォールバック: stdout にレポート全文を出し、tmp/daily-health-check.log から目視確認

### Chrome が起動していない
- スキル冒頭で `open -a "Google Chrome"` → 10秒 sleep → tabs_context で確認

## ログ

launchd 起動時のstdout/stderrは以下に流れる:
- `/Users/kasedashouta/develop/yomislo/tmp/daily-health-check.log`
- `/Users/kasedashouta/develop/yomislo/tmp/daily-health-check.err`

スキルの最後に以下を出力すること:
```
[YYYY-MM-DD HH:MM] spawn_task main=<task_id> anomalies=<N> chip_ids=[<id1>,<id2>...]
```
