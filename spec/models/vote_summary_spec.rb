require "rails_helper"

RSpec.describe VoteSummary, type: :model do
  describe ".refresh_for" do
    let(:shop) { create(:shop) }
    let(:machine) { create(:machine_model) }
    let(:date) { Date.current }

    it "creates a summary from votes" do
      create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: 1, setting_vote: 6)
      create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: 1, setting_vote: 4)
      create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: 0, setting_vote: 2)

      summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
      expect(summary.total_votes).to eq(3)
      expect(summary.reset_yes_count).to eq(2)
      expect(summary.reset_no_count).to eq(1)
      expect(summary.setting_avg).to eq(4.0)
      expect(summary.setting_distribution).to eq({ "1" => 0, "2" => 1, "3" => 0, "4" => 1, "5" => 0, "6" => 1 })
    end

    it "calculates reset rate" do
      create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: 1, setting_vote: nil)
      create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: 1, setting_vote: nil)
      create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: 0, setting_vote: nil)

      summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
      expect(summary.reset_rate).to eq(67)
    end

    it "reports enough_data? based on total_votes" do
      create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: 1)

      summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
      expect(summary.enough_data?).to be false
    end
  end
end
