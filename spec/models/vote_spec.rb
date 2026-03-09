require "rails_helper"

RSpec.describe Vote, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      vote = build(:vote)
      expect(vote).to be_valid
    end

    it "requires at least one vote type" do
      vote = build(:vote, reset_vote: nil, setting_vote: nil)
      expect(vote).not_to be_valid
      expect(vote.errors[:base]).to include("リセット投票か設定投票のどちらかは必須です")
    end

    it "validates reset_vote inclusion" do
      vote = build(:vote, reset_vote: 2)
      expect(vote).not_to be_valid
    end

    it "validates setting_vote range 1-6" do
      vote = build(:vote, setting_vote: 7)
      expect(vote).not_to be_valid
    end

    it "prevents future votes" do
      vote = build(:vote, voted_on: Date.current + 1)
      expect(vote).not_to be_valid
    end

    it "prevents votes older than yesterday" do
      vote = build(:vote, voted_on: Date.current - 2)
      expect(vote).not_to be_valid
    end

    it "enforces one vote per voter_token per shop per machine per day" do
      existing = create(:vote)
      duplicate = build(:vote,
        voter_token: existing.voter_token,
        shop: existing.shop,
        machine_model: existing.machine_model,
        voted_on: existing.voted_on
      )
      expect(duplicate).not_to be_valid
    end
  end
end
