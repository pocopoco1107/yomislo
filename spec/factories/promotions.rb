FactoryBot.define do
  factory :promotion do
    sequence(:title) { |n| "おすすめ案件 #{n}" }
    description { "テスト用紹介文" }
    image_url { "https://placehold.co/600x300" }
    target_url { "https://example.com" }
    category { :point_site }
    slot_keys { %w[home_hero] }
    priority { 0 }
    active { true }
  end
end
