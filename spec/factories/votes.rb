FactoryBot.define do
  factory :vote do
    shop
    machine_model
    voted_on { Date.current }
    reset_vote { 1 }
    setting_vote { 4 }
    sequence(:voter_token) { |n| "token_#{n}" }
  end
end
