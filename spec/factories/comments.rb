FactoryBot.define do
  factory :comment do
    user
    association :commentable, factory: :shop
    body { "テストコメント" }
    target_date { Date.current }
  end
end
