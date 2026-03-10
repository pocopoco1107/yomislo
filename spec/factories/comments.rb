FactoryBot.define do
  factory :comment do
    user
    association :commentable, factory: :shop
    body { "テストコメント" }
    target_date { Date.current }
    voter_token { SecureRandom.hex(16) }
  end
end
