---
name: data-check
description: >
  ヨミスロDBの総合データ品質チェック。パチンコ混入・全角半角重複・件数サマリ・
  Shop/MachineModel/ShopMachineModel の充足率を一括出力する。
  Use proactively when:
  - ユーザーが「データチェック」「データ品質」「件数確認」「DB状況」「充足率」と発言した
  - ユーザーが「機種は何件？」「店舗は何件？」「3店舗以上に置かれてる機種は？」と尋ねた
  - rake ptown:* の実行直後でデータ整合性を確認したい
  - ローカル DB と本番のデータ乖離を疑う場面
  - 注意: scraping-verify の verify モードと役割が異なる（こちらは絶対値、向こうは前後差分）
---

# Data Check

ヨミスロDBの**現在の充足状況**を一覧する総合チェック。
scraping-verify は「前後の差分」、data-check は「いまの絶対値」が役割。

## 実行方法

ユーザーが `/data-check` または「データチェック」と言ったら、以下4ブロックを順に実行して結果を要約する。

### 1. パチンコ混入チェック

```bash
cd /Users/kasedashouta/Desktop/develop/yomislo && export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH" && bin/rails runner '
pachinko_patterns = MachineModel.active.where(
  "name ~ E'"'"'^\u{FF30}'"'"' OR name ~ E'"'"'^\u{FF23}\u{FF32}'"'"' OR name ~ E'"'"'^\u{FF45}'"'"' OR name LIKE '"'"'%ぱちんこ%'"'"' OR name LIKE '"'"'%デジハネ%'"'"' OR name LIKE '"'"'%甘デジ%'"'"' OR name LIKE '"'"'%羽根モノ%'"'"'"
)
half_width = MachineModel.active.where("name ~ E'"'"'^PA[^a-z]'"'"' OR name ~ E'"'"'^P\\s'"'"' OR name ~ E'"'"'^PF[^a-z]'"'"' OR name ~ E'"'"'^CR'"'"'")
count = pachinko_patterns.count + half_width.count
puts "=== パチンコ混入チェック ==="
if count == 0
  puts "OK: パチンコ機種の混入なし"
else
  puts "NG: #{count}件のパチンコ機種が混入"
  (pachinko_patterns.limit(5).pluck(:name) + half_width.limit(5).pluck(:name)).each { |n| puts "  - #{n}" }
end
'
```

### 2. NFKC重複チェック

```bash
bin/rails runner '
names = MachineModel.active.pluck(:id, :name)
normalized = names.group_by { |_, n| n.unicode_normalize(:nfkc).strip }
dups = normalized.select { |_, v| v.size > 1 }
puts "=== 全角/半角重複チェック ==="
if dups.empty?
  puts "OK: 重複なし"
else
  puts "NG: #{dups.count}件の重複"
  dups.first(5).each { |norm, items| puts "  #{norm}: #{items.map(&:last).join('"'"' / '"'"')}" }
end
'
```

### 3. 件数サマリ

```bash
bin/rails runner '
puts "=== データ件数サマリ ==="
shops = Shop.count
active = MachineModel.active.count
popular = MachineModel.active.joins(:shop_machine_models).group("machine_models.id").having("COUNT(*) >= 3").count.size
links = ShopMachineModel.count
rate_count = ExchangeRateSummary.where("total_reports > 0").select(:shop_id).distinct.count
facility_count = Shop.where.not(features: [nil, ""]).count
puts "店舗: #{shops}"
puts "アクティブ機種: #{active}"
puts "3店舗以上設置: #{popular}"
puts "店舗×機種リンク: #{links}"
puts "交換率情報: #{rate_count}/#{shops} (#{(rate_count.to_f/shops*100).round(1)}%)"
puts "設備情報: #{facility_count}/#{shops} (#{(facility_count.to_f/shops*100).round(1)}%)"
puts "今日の記録数: #{Vote.where(voted_on: Date.current).count}"
puts "累計記録数: #{Vote.count}"
'
```

### 4. データ充足率

```bash
bin/rails runner '
puts "=== Shop データ充足率 (#{Shop.count}件) ==="
total = Shop.count.to_f
{
  "address" => Shop.where.not(address: [nil, ""]).count,
  "lat/lng" => Shop.where.not(lat: nil).where.not(lng: nil).count,
  "ptown_shop_id" => Shop.where.not(ptown_shop_id: nil).count,
  "last_synced_at" => Shop.where.not(last_synced_at: nil).count,
  "total_machines" => Shop.where.not(total_machines: [nil, 0]).count,
  "slot_machines" => Shop.where.not(slot_machines: [nil, 0]).count,
  "business_hours" => Shop.where.not(business_hours: [nil, ""]).count,
  "phone_number" => Shop.where.not(phone_number: [nil, ""]).count,
  "parking_spaces" => Shop.where.not(parking_spaces: [nil, 0]).count,
  "access_info" => Shop.where.not(access_info: [nil, ""]).count,
  "features (設備)" => Shop.where.not(features: [nil, ""]).count,
  "morning_entry" => Shop.where.not(morning_entry: [nil, ""]).count,
  "regular_holiday" => Shop.where.not(regular_holiday: [nil, ""]).count,
}.each do |field, count|
  pct = (count / total * 100).round(1)
  status = pct >= 75 ? "OK" : pct >= 50 ? "WARN" : "LOW"
  puts "  #{field}: #{count}/#{total.to_i} (#{pct}%) [#{status}]"
end

puts ""
puts "=== MachineModel データ充足率 (Active: #{MachineModel.active.count}件) ==="
atotal = MachineModel.active.count.to_f
{
  "ptown_id" => MachineModel.active.where.not(ptown_id: nil).count,
  "generation" => MachineModel.active.where.not(generation: [nil, ""]).count,
  "type_detail" => MachineModel.active.where.not(type_detail: [nil, ""]).count,
  "payout_rate_min" => MachineModel.active.where.not(payout_rate_min: nil).count,
  "image_url" => MachineModel.active.where.not(image_url: [nil, ""]).count,
  "ceiling_info" => MachineModel.active.where("ceiling_info::text <> '"'"'{}'"'"'").count,
  "reset_info" => MachineModel.active.where("reset_info::text <> '"'"'{}'"'"'").count,
  "is_smart_slot (true)" => MachineModel.active.where(is_smart_slot: true).count,
}.each do |field, count|
  pct = (count / atotal * 100).round(1)
  puts "  #{field}: #{count}/#{atotal.to_i} (#{pct}%)"
end

puts ""
puts "=== ShopMachineModel 充足率 ==="
smm_total = ShopMachineModel.count.to_f
smm_with = ShopMachineModel.where("unit_count > 0").count
puts "  unit_count > 0: #{smm_with}/#{smm_total.to_i} (#{(smm_with / smm_total * 100).round(1)}%)"

puts ""
puts "=== SNS/その他 ==="
puts "  Votes: #{Vote.count}"
puts "  PlayRecords: #{PlayRecord.count}"
puts "  Comments: #{Comment.count}"
'
```

## 報告フォーマット

実行後、結果をマークダウンの表で要約してユーザーに報告:

```
## データチェック結果

**現在の規模**: 店舗 6,053 / 機種 594 / リンク 382,867

**品質**:
- ✅ パチンコ混入なし
- ✅ NFKC重複なし

**充足率の主な指標**:
| カテゴリ | 値 | 状態 |
|---------|-----|------|
| lat/lng | 94.3% | OK |
| ceiling_info | 93.6% | OK |
| reset_info | 51.3% | LOW |
```

問題があれば「推奨アクション」を提案。

## 関連スキル

- `scraping-verify` — 前後差分を取りたい場合（rake実行を挟む時）
- `before-deploy-render` — デプロイ前の本番健全性チェック
