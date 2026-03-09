FactoryBot.define do
  factory :report do
    association :reporter, factory: :user
    association :reportable, factory: :comment
    reason { :spam }
    resolved { false }
  end
end
