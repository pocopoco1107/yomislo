FactoryBot.define do
  factory :shop do
    prefecture
    sequence(:name) { |n| "テスト店舗#{n}" }
    sequence(:slug) { |n| "test-shop-#{n}" }
    address { "東京都新宿区1-1-1" }
  end
end
