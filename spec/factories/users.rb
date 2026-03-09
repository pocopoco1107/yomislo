FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:nickname) { |n| "user#{n}" }
    password { "password123" }
    password_confirmation { "password123" }
    role { :general }
    trust_score { 0.5 }

    trait :admin do
      role { :admin }
    end
  end
end
