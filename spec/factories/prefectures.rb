FactoryBot.define do
  factory :prefecture do
    sequence(:name) { |n| "県#{n}" }
    sequence(:slug) { |n| "pref-#{n}" }
  end
end
