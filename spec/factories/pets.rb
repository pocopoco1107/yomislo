FactoryBot.define do
  factory :pet do
    sequence(:voter_token) { |n| "pet_token_#{n}" }
    stage { :egg }
    exp { 0 }
    streak_days { 0 }
    branch_axis { 0 }
    last_recorded_on { nil }
  end
end
