# data-check

Run a comprehensive data quality check for the ヨミスロ database. This skill checks for pachinko contamination, duplicate machines, and reports key metrics including data coverage rates.

## Steps

1. Run the following rails runner commands sequentially and report results:

### パチンコ混入チェック
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

### 重複チェック
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

### 件数サマリ
```bash
bin/rails runner '
puts "=== データ件数サマリ ==="
shops = Shop.count
active = MachineModel.active.count
popular = MachineModel.active.joins(:shop_machine_models).group("machine_models.id").having("COUNT(*) >= 3").count.size
links = ShopMachineModel.count
rate_count = Shop.where.not(slot_rates: [nil, ""]).count
facility_count = Shop.where.not(notes: [nil, ""]).count
puts "店舗: #{shops}"
puts "アクティブ機種: #{active}"
puts "3店舗以上設置: #{popular}"
puts "店舗×機種リンク: #{links}"
puts "レート情報: #{rate_count}/#{shops} (#{(rate_count.to_f/shops*100).round(1)}%)"
puts "設備情報: #{facility_count}/#{shops} (#{(facility_count.to_f/shops*100).round(1)}%)"
puts "今日の記録数: #{Vote.where(voted_on: Date.current).count}"
puts "累計記録数: #{Vote.count}"
'
```

### データ充足率
```bash
bin/rails runner '
puts "=== Shop データ充足率 (#{Shop.count}件) ==="
total = Shop.count.to_f
{
  "address" => Shop.where.not(address: [nil, ""]).count,
  "lat/lng" => Shop.where.not(latitude: nil).where.not(longitude: nil).count,
  "pworld_url" => Shop.where.not(pworld_url: [nil, ""]).count,
  "total_machines" => Shop.where.not(total_machines: [nil, 0]).count,
  "notes (設備)" => Shop.where.not(notes: [nil, ""]).count,
  "business_hours" => Shop.where.not(business_hours: [nil, ""]).count,
  "slot_rates" => Shop.where.not(slot_rates: [nil, ""]).count,
  "phone_number" => Shop.where.not(phone_number: [nil, ""]).count,
  "exchange_rate" => Shop.where.not(exchange_rate: ["unknown_rate", nil]).count,
  "parking_spaces" => Shop.where.not(parking_spaces: [nil, 0]).count,
  "access_info" => Shop.where.not(access_info: [nil, ""]).count,
  "features" => Shop.where.not(features: [nil, ""]).count,
  "morning_entry" => Shop.where.not(morning_entry: [nil, ""]).count,
}.each do |field, count|
  pct = (count / total * 100).round(1)
  status = pct >= 75 ? "OK" : pct >= 50 ? "WARN" : "LOW"
  puts "  #{field}: #{count}/#{total.to_i} (#{pct}%) [#{status}]"
end

puts ""
puts "=== MachineModel データ充足率 (Active: #{MachineModel.active.count}件) ==="
atotal = MachineModel.active.count.to_f
{
  "pworld_machine_id" => MachineModel.active.where.not(pworld_machine_id: nil).count,
  "generation" => MachineModel.active.where.not(generation: [nil, ""]).count,
  "type_detail" => MachineModel.active.where.not(type_detail: [nil, ""]).count,
  "payout_rate_min" => MachineModel.active.where.not(payout_rate_min: nil).count,
  "image_url" => MachineModel.active.where.not(image_url: [nil, ""]).count,
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
puts "  SnsReports: #{SnsReport.count}"
puts "  Votes: #{Vote.count}"
puts "  PlayRecords: #{PlayRecord.count}"
puts "  Comments: #{Comment.count}"
'
```

2. Present results in a clear summary table
3. Flag any issues found and suggest fixes
