SitemapGenerator::Sitemap.default_host = "https://slorise-navi.com"

SitemapGenerator::Sitemap.create do
  # Static pages
  add root_path, changefreq: "daily", priority: 1.0

  # Prefectures
  Prefecture.find_each do |prefecture|
    add prefecture_path(prefecture.slug), changefreq: "daily", priority: 0.8
  end

  # Shops
  Shop.find_each do |shop|
    add shop_path(shop.slug), changefreq: "daily", priority: 0.9
  end

  # Machines
  MachineModel.find_each do |machine|
    add machine_path(machine.slug), changefreq: "weekly", priority: 0.7
  end
end
