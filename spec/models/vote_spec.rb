require "rails_helper"

RSpec.describe Vote, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      vote = build(:vote)
      expect(vote).to be_valid
    end

    it "is valid with no vote type (all nil)" do
      vote = build(:vote, reset_vote: nil, setting_vote: nil, confirmed_setting: [])
      expect(vote).to be_valid
    end

    it "is valid with only confirmed_setting" do
      vote = build(:vote, reset_vote: nil, setting_vote: nil, confirmed_setting: [ "6確" ])
      expect(vote).to be_valid
    end

    it "rejects invalid confirmed_setting tags" do
      vote = build(:vote, confirmed_setting: [ "invalid_tag" ])
      expect(vote).not_to be_valid
      expect(vote.errors[:confirmed_setting]).to be_present
    end

    it "accepts valid confirmed_setting tags" do
      vote = build(:vote, confirmed_setting: [ "偶数確", "4以上" ])
      expect(vote).to be_valid
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

  describe "uniqueness constraint edge cases" do
    it "allows same voter_token on different dates" do
      vote1 = create(:vote, voted_on: Date.current)
      vote2 = build(:vote,
        voter_token: vote1.voter_token,
        shop: vote1.shop,
        machine_model: vote1.machine_model,
        voted_on: Date.yesterday
      )
      expect(vote2).to be_valid
    end

    it "allows same voter_token at different shops on the same date" do
      vote1 = create(:vote)
      vote2 = build(:vote,
        voter_token: vote1.voter_token,
        shop: create(:shop),
        machine_model: vote1.machine_model,
        voted_on: vote1.voted_on
      )
      expect(vote2).to be_valid
    end

    it "allows same voter_token for different machines at the same shop" do
      vote1 = create(:vote)
      vote2 = build(:vote,
        voter_token: vote1.voter_token,
        shop: vote1.shop,
        machine_model: create(:machine_model),
        voted_on: vote1.voted_on
      )
      expect(vote2).to be_valid
    end

    it "raises DB error on duplicate insert bypassing validation" do
      vote1 = create(:vote)
      vote2 = build(:vote,
        voter_token: vote1.voter_token,
        shop: vote1.shop,
        machine_model: vote1.machine_model,
        voted_on: vote1.voted_on
      )
      expect(vote2).not_to be_valid
      expect(vote2.errors[:voter_token]).to be_present
    end
  end

  describe "independent update of setting_vote and reset_vote" do
    it "can update setting_vote without changing reset_vote" do
      vote = create(:vote, reset_vote: 1, setting_vote: 2)
      vote.update!(setting_vote: 5)
      vote.reload
      expect(vote.reset_vote).to eq(1)
      expect(vote.setting_vote).to eq(5)
    end

    it "can update reset_vote without changing setting_vote" do
      vote = create(:vote, reset_vote: 1, setting_vote: 4)
      vote.update!(reset_vote: 0)
      vote.reload
      expect(vote.setting_vote).to eq(4)
      expect(vote.reset_vote).to eq(0)
    end

    it "can set reset_vote to nil while keeping setting_vote" do
      vote = create(:vote, reset_vote: 1, setting_vote: 3)
      vote.update!(reset_vote: nil)
      vote.reload
      expect(vote.reset_vote).to be_nil
      expect(vote.setting_vote).to eq(3)
    end

    it "can set setting_vote to nil while keeping reset_vote" do
      vote = create(:vote, reset_vote: 0, setting_vote: 6)
      vote.update!(setting_vote: nil)
      vote.reload
      expect(vote.setting_vote).to be_nil
      expect(vote.reset_vote).to eq(0)
    end
  end

  describe "confirmed_setting array handling" do
    it "accepts all valid CONFIRMED_SETTING_TAGS" do
      vote = build(:vote, confirmed_setting: Vote::CONFIRMED_SETTING_TAGS.dup)
      expect(vote).to be_valid
    end

    it "accepts empty array" do
      vote = build(:vote, reset_vote: 1, confirmed_setting: [])
      expect(vote).to be_valid
    end

    it "rejects when mixing valid and invalid tags" do
      vote = build(:vote, confirmed_setting: [ "6確", "invalid" ])
      expect(vote).not_to be_valid
    end

    it "persists and reloads confirmed_setting array correctly" do
      vote = create(:vote, reset_vote: nil, setting_vote: nil, confirmed_setting: [ "偶数確", "6確" ])
      vote.reload
      expect(vote.confirmed_setting).to eq([ "偶数確", "6確" ])
    end

    it "can add a tag by updating the array" do
      vote = create(:vote, reset_vote: nil, setting_vote: nil, confirmed_setting: [ "6確" ])
      vote.update!(confirmed_setting: vote.confirmed_setting + [ "偶数確" ])
      vote.reload
      expect(vote.confirmed_setting).to contain_exactly("6確", "偶数確")
    end

    it "can remove a tag by updating the array" do
      vote = create(:vote, reset_vote: nil, setting_vote: nil, confirmed_setting: [ "6確", "偶数確" ])
      vote.update!(confirmed_setting: vote.confirmed_setting - [ "偶数確" ])
      vote.reload
      expect(vote.confirmed_setting).to eq([ "6確" ])
    end
  end

  describe "voted_on date boundary values" do
    it "allows today's date" do
      vote = build(:vote, voted_on: Date.current)
      expect(vote).to be_valid
    end

    it "allows yesterday's date" do
      vote = build(:vote, voted_on: Date.yesterday)
      expect(vote).to be_valid
    end

    it "rejects tomorrow's date" do
      vote = build(:vote, voted_on: Date.current + 1)
      expect(vote).not_to be_valid
      expect(vote.errors[:voted_on]).to include("は未来の日付にできません")
    end

    it "rejects two days ago" do
      vote = build(:vote, voted_on: Date.current - 2)
      expect(vote).not_to be_valid
      expect(vote.errors[:voted_on]).to include("は前日までしか記録できません")
    end

    it "rejects a date far in the past" do
      vote = build(:vote, voted_on: Date.new(2020, 1, 1))
      expect(vote).not_to be_valid
    end

    it "rejects a date far in the future" do
      vote = build(:vote, voted_on: Date.current + 365)
      expect(vote).not_to be_valid
    end
  end

  describe "setting_vote boundary values" do
    it "accepts minimum value 1" do
      vote = build(:vote, setting_vote: 1)
      expect(vote).to be_valid
    end

    it "accepts maximum value 6" do
      vote = build(:vote, setting_vote: 6)
      expect(vote).to be_valid
    end

    it "rejects 0" do
      vote = build(:vote, setting_vote: 0)
      expect(vote).not_to be_valid
    end

    it "rejects 7" do
      vote = build(:vote, setting_vote: 7)
      expect(vote).not_to be_valid
    end

    it "rejects negative values" do
      vote = build(:vote, setting_vote: -1)
      expect(vote).not_to be_valid
    end
  end

  describe "reset_vote boundary values" do
    it "accepts 0 (No)" do
      vote = build(:vote, reset_vote: 0, setting_vote: nil)
      expect(vote).to be_valid
    end

    it "accepts 1 (Yes)" do
      vote = build(:vote, reset_vote: 1, setting_vote: nil)
      expect(vote).to be_valid
    end

    it "accepts nil" do
      vote = build(:vote, reset_vote: nil, setting_vote: 3)
      expect(vote).to be_valid
    end

    it "rejects -1" do
      vote = build(:vote, reset_vote: -1)
      expect(vote).not_to be_valid
    end

    it "rejects 2" do
      vote = build(:vote, reset_vote: 2)
      expect(vote).not_to be_valid
    end
  end

  describe "callbacks" do
    it "creates or updates VoteSummary on save" do
      vote = create(:vote, setting_vote: 3)
      summary = VoteSummary.find_by(shop_id: vote.shop_id, machine_model_id: vote.machine_model_id, target_date: vote.voted_on)
      expect(summary).to be_present
      expect(summary.total_votes).to be >= 1
    end

    it "updates VoteSummary on destroy" do
      vote = create(:vote, setting_vote: 4)
      vote.destroy!
      summary = VoteSummary.find_by(shop_id: vote.shop_id, machine_model_id: vote.machine_model_id, target_date: vote.voted_on)
      expect(summary.total_votes).to eq(0)
    end
  end
end
