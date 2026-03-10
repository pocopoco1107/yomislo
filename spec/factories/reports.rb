FactoryBot.define do
  factory :report do
    association :reporter, factory: :user
    association :reportable, factory: :comment
    reason { :spam }
    resolved { false }
    voter_token { SecureRandom.hex(16) }
  end
end
