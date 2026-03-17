require "rails_helper"

RSpec.describe VoterRanking, type: :model do
  # Helper to insert votes bypassing model validations and callbacks
  def insert_vote(voter_token:, shop:, machine_model:, voted_on:, reset_vote: 1)
    Vote.insert!({
      voter_token: voter_token,
      shop_id: shop.id,
      machine_model_id: machine_model.id,
      voted_on: voted_on,
      reset_vote: reset_vote,
      created_at: Time.current,
      updated_at: Time.current
    })
  end

  describe "enum" do
    it "defines period_type enum" do
      expect(VoterRanking.period_types).to eq("weekly" => 0, "monthly" => 1, "all_time" => 2)
    end
  end

  describe "validations" do
    it "is valid with all required attributes" do
      ranking = build(:voter_ranking)
      expect(ranking).to be_valid
    end

    it "requires voter_token" do
      ranking = build(:voter_ranking, voter_token: nil)
      expect(ranking).not_to be_valid
    end

    it "requires period_key" do
      ranking = build(:voter_ranking, period_key: nil)
      expect(ranking).not_to be_valid
    end

    it "requires rank_position" do
      ranking = build(:voter_ranking, rank_position: nil)
      expect(ranking).not_to be_valid
    end

    it "requires rank_position to be positive" do
      ranking = build(:voter_ranking, rank_position: 0)
      expect(ranking).not_to be_valid
    end

    it "enforces uniqueness of voter_token per period/scope" do
      create(:voter_ranking, voter_token: "token_a", period_type: :weekly,
             period_key: "2026-W11", scope_type: "national", scope_id: nil)
      dup = build(:voter_ranking, voter_token: "token_a", period_type: :weekly,
                  period_key: "2026-W11", scope_type: "national", scope_id: nil)
      expect(dup).not_to be_valid
    end
  end

  describe "#voter_label" do
    it "returns a label with last 4 chars of token" do
      ranking = build(:voter_ranking, voter_token: "abcdef1234")
      expect(ranking.voter_label).to eq("ユーザー#1234")
    end
  end

  describe ".refresh_weekly!" do
    let(:shop) { create(:shop) }

    it "creates national rankings from votes this week" do
      token = "weekly_voter"
      6.times do
        insert_vote(voter_token: token, shop: shop,
                    machine_model: create(:machine_model),
                    voted_on: Date.current)
      end

      VoterRanking.refresh_weekly!

      week_key = Date.current.strftime("%G-W%V")
      rankings = VoterRanking.where(period_type: :weekly, period_key: week_key, scope_type: "national")
      expect(rankings.count).to eq(1)
      expect(rankings.first.voter_token).to eq(token)
      expect(rankings.first.vote_count).to eq(6)
      expect(rankings.first.rank_position).to eq(1)
    end

    it "filters out voters below minimum threshold of 5" do
      3.times do
        insert_vote(voter_token: "low_voter", shop: shop,
                    machine_model: create(:machine_model),
                    voted_on: Date.current)
      end

      VoterRanking.refresh_weekly!

      week_key = Date.current.strftime("%G-W%V")
      rankings = VoterRanking.where(period_type: :weekly, period_key: week_key, scope_type: "national")
      expect(rankings.count).to eq(0)
    end

    it "creates prefecture rankings" do
      token = "pref_voter"
      6.times do
        insert_vote(voter_token: token, shop: shop,
                    machine_model: create(:machine_model),
                    voted_on: Date.current)
      end

      VoterRanking.refresh_weekly!

      week_key = Date.current.strftime("%G-W%V")
      pref_rankings = VoterRanking.where(period_type: :weekly, period_key: week_key, scope_type: "prefecture")
      expect(pref_rankings.count).to eq(1)
      expect(pref_rankings.first.scope_id).to eq(shop.prefecture_id)
    end

    it "ranks multiple voters in correct order" do
      token_a = "voter_a"
      token_b = "voter_b"

      10.times do
        insert_vote(voter_token: token_a, shop: shop,
                    machine_model: create(:machine_model),
                    voted_on: Date.current)
      end
      6.times do
        insert_vote(voter_token: token_b, shop: shop,
                    machine_model: create(:machine_model),
                    voted_on: Date.current)
      end

      VoterRanking.refresh_weekly!

      week_key = Date.current.strftime("%G-W%V")
      rankings = VoterRanking.where(period_type: :weekly, period_key: week_key, scope_type: "national").order(:rank_position)
      expect(rankings.first.voter_token).to eq(token_a)
      expect(rankings.first.rank_position).to eq(1)
      expect(rankings.second.voter_token).to eq(token_b)
      expect(rankings.second.rank_position).to eq(2)
    end
  end

  describe "scopes" do
    it ".national returns only national-scoped rankings" do
      national = create(:voter_ranking, scope_type: "national", scope_id: nil)
      pref = create(:voter_ranking, voter_token: "other", scope_type: "prefecture", scope_id: 1)
      expect(VoterRanking.national).to include(national)
      expect(VoterRanking.national).not_to include(pref)
    end

    it ".top(n) returns top n ranked entries" do
      3.times do |i|
        create(:voter_ranking, voter_token: "top_#{i}", rank_position: i + 1)
      end
      expect(VoterRanking.top(2).count).to eq(2)
      expect(VoterRanking.top(2).pluck(:rank_position)).to eq([ 1, 2 ])
    end
  end
end
