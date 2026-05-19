# frozen_string_literal: true

# プレースホルダーのおすすめ案件。
# 本番運用時は ActiveAdmin から target_url / image_url を実アフィリエイトリンクに差し替える。

PROMOTIONS = [
  {
    title:       "楽天カード",
    description: "勝った分のポイント還元で還元率アップ。年会費永年無料。",
    image_url:   "https://placehold.co/600x300/166534/ffffff?text=Rakuten+Card",
    target_url:  "#",
    category:    "credit_card",
    slot_keys:   %w[home_hero shop_detail_top],
    priority:    50
  },
  {
    title:       "モッピー",
    description: "スキマ時間でポイ活。月数千円のお小遣いも狙える。",
    image_url:   "https://placehold.co/600x600/0f766e/ffffff?text=Moppy",
    target_url:  "#",
    category:    "point_site",
    slot_keys:   %w[home_zone_split voter_status],
    priority:    40
  },
  {
    title:       "SBI証券",
    description: "余剰資金を増やすなら。手数料無料の投資デビュー。",
    image_url:   "https://placehold.co/600x300/047857/ffffff?text=SBI",
    target_url:  "#",
    category:    "securities",
    slot_keys:   %w[machine_detail rankings_top],
    priority:    30
  },
  {
    title:       "U-NEXT",
    description: "ホール帰りの夜に。アニメ・映画・パチスロ番組見放題。",
    image_url:   "https://placehold.co/600x600/065f46/ffffff?text=U-NEXT",
    target_url:  "#",
    category:    "vod",
    slot_keys:   %w[shop_detail_bottom],
    priority:    20
  },
  {
    title:       "ハピタス",
    description: "買い物前にワンクリックでポイント二重取り。",
    image_url:   "https://placehold.co/600x600/10b981/ffffff?text=Hapitas",
    target_url:  "#",
    category:    "point_site",
    slot_keys:   %w[home_zone_split voter_status],
    priority:    25
  }
].freeze

PROMOTIONS.each do |attrs|
  promo = Promotion.find_or_initialize_by(title: attrs[:title])
  promo.update!(attrs)
end
puts "  Promotions: #{Promotion.count}"
