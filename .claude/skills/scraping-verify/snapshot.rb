# encoding: utf-8
# /scraping-verify snapshot — DB状態をスナップショット保存
require "json"
require "fileutils"

dir = Rails.root.join("tmp/scraping_snapshots")
FileUtils.mkdir_p(dir)

snap = {
  taken_at: Time.current.iso8601,
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
  by_prefecture: Prefecture.order(:id).map { |p|
    {
      slug: p.slug,
      name: p.name,
      shops: p.shops.count,
      shops_with_ptown_id: p.shops.where.not(ptown_shop_id: nil).count,
      shops_synced: p.shops.where.not(last_synced_at: nil).count,
      shops_with_smm: p.shops.joins(:shop_machine_models).distinct.count,
    }
  },
}

path = dir.join("latest.json")
File.write(path, JSON.pretty_generate(snap))

stamped = dir.join("snapshot_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json")
File.write(stamped, JSON.pretty_generate(snap))

puts "=== スナップショット保存 ==="
puts "  #{path}"
puts "  #{stamped}"
puts ""
puts "MachineModel:  active=#{snap[:machine_model][:active]}  total=#{snap[:machine_model][:total]}"
puts "Shop:          total=#{snap[:shop][:total]}  with_ptown=#{snap[:shop][:with_ptown_id]}  synced=#{snap[:shop][:synced]}"
puts "SMM:           total=#{snap[:shop_machine_model][:total]}  unit_count>0=#{snap[:shop_machine_model][:with_unit_count]}"
puts ""
puts "次: rake ptown:* を実行 → 完了後に /scraping-verify verify"
