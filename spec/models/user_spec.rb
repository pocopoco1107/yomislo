require "rails_helper"

RSpec.describe User, type: :model do
  it "is valid with valid attributes" do
    user = build(:user)
    expect(user).to be_valid
  end

  it "requires a nickname" do
    user = build(:user, nickname: nil)
    expect(user).not_to be_valid
  end

  it "requires unique nickname" do
    create(:user, nickname: "taken")
    user = build(:user, nickname: "taken")
    expect(user).not_to be_valid
  end

  it "validates trust_score range" do
    user = build(:user, trust_score: 1.5)
    expect(user).not_to be_valid
  end
end
