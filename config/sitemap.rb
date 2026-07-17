SitemapGenerator::Sitemap.default_host = ENV.fetch("SITE_URL", "https://yomislo.com")

SitemapGenerator::Sitemap.create do
  add root_path, changefreq: "daily", priority: 1.0

  Prefecture.find_each do |prefecture|
    add prefecture_path(prefecture.slug), changefreq: "daily", priority: 0.8
  end

  # 掲載終了(delisted)店舗と設置機種0の店舗を除外。薄いページをクロールバジェットから外し、
  # 記録がある/設置機種がある店舗にクロールを集中させる。
  Shop.listed
      .joins(:shop_machine_models)
      .distinct
      .find_each do |shop|
    add shop_path(shop.slug), changefreq: "daily", priority: 0.9
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
