# encoding: utf-8
# /scraping-verify verify — スナップショット差分 + データ品質チェック
require "json"

path = Rails.root.join("tmp/scraping_snapshots/latest.json")
unless File.exist?(path)
  puts "❌ スナップショット未取得: #{path}"
  puts "   先に /scraping-verify snapshot を実行してください"
  exit 1
end

before = JSON.parse(File.read(path), symbolize_names: true)
now = {
  machine_model: {
    total: MachineModel.count,
    active: MachineModel.active.count,
    with_ptown_id: MachineModel.where.not(ptown_id: nil).count,
    smart_slot: MachineModel.where(is_smart_slot: true).count,
    with_image: MachineModel.where.not(image_url: [nil, ""]).count,
    with_ceiling: MachineModel.where("ceiling_info::text <> '{}'").count,
    with_reset: MachineModel.where("reset_info::text <> '{}'").count,
  },
  shop: {
    total: Shop.count,
    with_ptown_id: Shop.where.not(ptown_shop_id: nil).count,
    synced: Shop.where.not(last_synced_at: nil).count,
    with_address: Shop.where.not(address: [nil, ""]).count,
    with_latlng: Shop.where.not(lat: nil).where.not(lng: nil).count,
  },
  shop_machine_model: {
    total: ShopMachineModel.count,
    with_unit_count: ShopMachineModel.where("unit_count > 0").count,
  },
}

# 閾値（%）: 減少時にWARN、急増は閾値の2倍でWARN（重複混入疑い）
thresholds = { machine_model: 10.0, shop: 5.0, shop_machine_model: 15.0 }

warnings = []
issues = []

puts "=== スクレイピング検証: #{before[:taken_at]} → 現在 ==="
puts ""

[:machine_model, :shop, :shop_machine_model].each do |section|
  puts "[#{section}]"
  before[section].each do |key, b|
    a = now[section][key]
    diff = a - b
    pct = b.zero? ? (a.zero? ? 0.0 : 100.0) : (diff.to_f / b * 100)
    arrow = diff > 0 ? "↑" : (diff < 0 ? "↓" : "=")
    line = "  #{key.to_s.ljust(20)} #{b.to_s.rjust(7)} → #{a.to_s.rjust(7)} (#{arrow}#{diff.abs} / #{pct.round(1)}%)"

    th = thresholds[section]
    if pct.abs >= th && diff < 0
      warnings << "#{section}.#{key}: #{pct.round(1)}% 減少 (閾値±#{th}%)"
      line += " ⚠️"
    elsif pct.abs >= th * 2 && diff > 0
      warnings << "#{section}.#{key}: #{pct.round(1)}% 急増 (閾値±#{(th * 2).to_i}%) — 重複混入の可能性"
      line += " ⚠️"
    end
    puts line
  end
  puts ""
end

# パチンコ混入チェック（核心: 接頭辞Ｐ/CR/PA/甘デジ/羽根モノ）
pachinko_clauses = [
  "name LIKE '%ぱちんこ%'",
  "name LIKE '%デジハネ%'",
  "name LIKE '%甘デジ%'",
  "name LIKE '%羽根モノ%'",
  "name ~ '^PA[^a-z]'",
  "name ~ '^P\\s'",
  "name ~ '^PF[^a-z]'",
  "name ~ '^CR'",
  "name ~ '^Ｐ '",
  "name ~ '^ＣＲ'",
]
pachinko = MachineModel.active.where(pachinko_clauses.join(" OR "))
puts "[パチンコ混入]"
if pachinko.count.zero?
  puts "  ✅ OK: 0件"
else
  issues << "パチンコ機種が #{pachinko.count} 件混入"
  puts "  ❌ NG: #{pachinko.count} 件"
  pachinko.limit(5).pluck(:name).each { |n| puts "    - #{n}" }
end
puts ""

# 全角/半角重複チェック (NFKC)
names = MachineModel.active.pluck(:id, :name)
dups = names.group_by { |_, n| n.unicode_normalize(:nfkc).strip }.select { |_, v| v.size > 1 }
puts "[NFKC重複]"
if dups.empty?
  puts "  ✅ OK: 0グループ"
else
  warnings << "全角/半角重複: #{dups.count} グループ"
  puts "  ⚠️ WARN: #{dups.count} グループ"
  dups.first(5).each { |norm, items| puts "    #{norm}: #{items.map(&:last).join(' / ')}" }
end
puts ""

# 設置機種なし店舗の変化（既知 ~1,002店）
no_smm_before = (before[:by_prefecture] || []).sum { |p| p[:shops_with_ptown_id] - p[:shops_with_smm] }
no_smm_now = Prefecture.all.sum { |p|
  p.shops.where.not(ptown_shop_id: nil).count - p.shops.joins(:shop_machine_models).distinct.count
}
puts "[設置機種なし店舗]"
puts "  before: #{no_smm_before} → now: #{no_smm_now} (既知: ~1,002店)"
if no_smm_now > no_smm_before + 50
  warnings << "設置機種なし店舗が #{no_smm_now - no_smm_before} 件増加"
end
puts ""

# 結果サマリ
puts "=== 結果 ==="
if issues.empty? && warnings.empty?
  puts "✅ 異常なし"
else
  unless issues.empty?
    puts "❌ FAIL #{issues.size} 件:"
    issues.each { |i| puts "  - #{i}" }
  end
  unless warnings.empty?
    puts "⚠️  警告 #{warnings.size} 件:"
    warnings.each { |w| puts "  - #{w}" }
  end
  puts ""
  puts "推奨アクション:"
  puts "  - パチンコ混入  → rake ptown:cleanup"
  puts "  - NFKC重複      → rake ptown:merge_duplicates"
  puts "  - 件数大幅減    → スクレイピングログ確認 / 該当県のみ再import"
end
