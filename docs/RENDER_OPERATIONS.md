# Render Dashboard 運用手順

ヨミスロを Render.com で運用するうえで、コードからは触れず Dashboard 経由で実施する作業の手順書。

- 本番URL: https://dashboard.render.com/
- サービス: `yomislo` (web) / `yomislo-daily-refresh` / `yomislo-daily-aggregation` / `yomislo-monthly` (cron) / `yomislo-db` (PostgreSQL)
- 構成詳細は [render.yaml](../render.yaml) を参照

---

## 1. 設備データ初回 backfill (新カラム導入後)

新しい設備カラムを追加した直後の運用。`facility_parsed_at` 取得率を 95% 以上に持っていくのが完了条件。

### 前提

- 新カラム追加マイグレーションが含まれる commit が main にマージ・deploy 完了している
- `yomislo` web service が **Live** 状態であること

### Step 1 — 全店強制再 sync を実行

`yomislo-daily-refresh` cron は通常モードで 24h 以内同期済み店舗をスキップしてしまう。初回 backfill では `FORCE=1` を付けて全店再 sync が必要。

1. Render Dashboard → `yomislo` (web service) → **Shell** タブ
2. 以下を実行 (約10時間かかるので Shell タブを開いたまま放置するか、 `&` 付きで background 実行):

```bash
FORCE=1 bundle exec rake ptown:sync_shop_machines 2>&1 | tee tmp/backfill_$(date +%Y%m%d_%H%M).log
```

進捗ログは `tmp/backfill_*.log` に残る (Shell セッション終了時に消えるので必要に応じて DL)。

#### 代替案: 都道府県ごとに分割実行

Shell の安定性を優先するなら、47 都道府県を 5-10 個ずつに分けて並行で。

```bash
for slug in hokkaido aomori iwate miyagi akita yamagata fukushima; do
  FORCE=1 bundle exec rake "ptown:sync_shop_machines[$slug]"
done
```

別の選択肢として、急がないなら **毎月1日の `yomislo-monthly` cron (`MonthlyShopDetailsJob`) がフル sync を回す** ので待つだけでも自然と埋まる。

### Step 2 — 進捗確認

ActiveAdmin の店舗一覧 ([/admin/shops](https://your-host.onrender.com/admin/shops)) を開く:
- **Filter** > `Facility parsed at` で「存在する」を選び、件数を確認
- 全店舗数に対する割合が **95% 以上** で完了とみなす

または Rails console (`Shell` タブで):

```ruby
total = Shop.where.not(ptown_shop_id: nil).count
parsed = Shop.where.not(facility_parsed_at: nil).count
puts "#{parsed}/#{total} (#{(parsed * 100.0 / total).round(1)}%)"
```

`Shop.where(wifi_available: true).count` などで各フラグの分布も併せて確認。0 や全店になっていないことをチェック。

---

## 2. 既知の制約・トラブルシュート

- **Shell タブの session timeout**: Shell タブを開きっぱなしにしてもブラウザを閉じると session が切れる。長時間バッチは tmux 相当が使えないので、都道府県分割を推奨
- **24h スキップ**: `FORCE=1` をつけ忘れると `last_synced_at` が 1.day.ago より新しい店舗はスキップされる
- **rate limit (429)**: `PtownScraper.fetch_page` は 429 を自動リトライする (`rate_limit_waits = [30, 120, 300]`)。連続で 429 が出る場合は時間をおく
- **DB 接続切れ**: `yomislo-db` の plan を free (90日制限) のままにしていると expire する。expire 前に starter ($7/mo) に upgrade
- **メモリ不足**: web service は starter (512MB)。bulk update を 1 トランザクションにまとめると OOM kill されるので `update_columns` で 1 件ずつが安全 (現在の実装通り)

---

## 3. クロスリファレンス

- 設備データの設計 → [memory: project_shop_facility_data](../../../.claude/projects/-Users-kasedashouta-Desktop-develop-yomislo/memory/project_shop_facility_data.md)
- Render 構成の経緯 → [memory: project_render_deploy](../../../.claude/projects/-Users-kasedashouta-Desktop-develop-yomislo/memory/project_render_deploy.md)
- スクレイピング全体 → [memory: project_scraping_architecture](../../../.claude/projects/-Users-kasedashouta-Desktop-develop-yomislo/memory/project_scraping_architecture.md)
- 広告枠の本番有効化フロー → [memory: project_promotions_runtime](../../../.claude/projects/-Users-kasedashouta-Desktop-develop-yomislo/memory/project_promotions_runtime.md)
