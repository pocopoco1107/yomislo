FactoryBot.define do
  factory :machine_model do
    sequence(:name) { |n| "テスト機種#{n}" }
    sequence(:slug) { |n| "test-machine-#{n}" }
    maker { "テストメーカー" }
  end
end
