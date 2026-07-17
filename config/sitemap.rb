SitemapGenerator::Sitemap.default_host = ENV.fetch("SITE_URL", "https://yomislo.com")

SitemapGenerator::Sitemap.create do
  add root_path, changefreq: "daily", priority: 1.0

  Prefecture.find_each do |prefecture|
    add prefecture_path(prefecture.slug), changefreq: "daily", priority: 0.8
  end

  # 掲載終了(delisted)店舗は listed スコープで除外。
  # DMMぱちタウン側で機種情報が非掲載の店舗（パチンコ専門店・小規模店 ~1,000件）は
  # 完全除外せず priority を下げる。住所・地図等の店舗情報は存在するため。
  shop_machine_counts = ShopMachineModel.group(:shop_id).count
  Shop.listed.find_each do |shop|
    priority = shop_machine_counts[shop.id].to_i.zero? ? 0.3 : 0.9
    add shop_path(shop.slug), changefreq: "daily", priority: priority
  end

  # 機種は設置店舗数でpriorityを差別化。Googleに「重要な機種はどれか」を明示する。
  machine_counts = ShopMachineModel.group(:machine_model_id).count
  MachineModel.active.find_each do |machine|
    installed = machine_counts[machine.id].to_i
    next if installed.zero?

    priority = case installed
    when 1..2 then 0.3
    when 3..9 then 0.5
    when 10..49 then 0.7
    else 0.9
    end
    add machine_path(machine.slug), changefreq: "weekly", priority: priority
  end

  add "/search", changefreq: "weekly", priority: 0.6
end
