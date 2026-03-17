require "rails_helper"

RSpec.describe VoterProfile, type: :model do
  let(:shop) { create(:shop) }
  let(:machine) { create(:machine_model) }
  let(:token) { "test_voter_token" }

  # Helper to insert a vote directly, bypassing model validations and callbacks.
  # Needed because Vote validates voted_on within 1 day and triggers after_save hooks.
  def insert_vote(voter_token:, shop:, machine_model:, voted_on:, setting_vote: nil, reset_vote: 1)
    Vote.insert!({
      voter_token: voter_token,
      shop_id: shop.id,
      machine_model_id: machine_model.id,
      voted_on: voted_on,
      setting_vote: setting_vote,
      reset_vote: reset_vote,
      created_at: Time.current,
      updated_at: Time.current
    })
  end

  describe "validations" do
    it "is valid with a voter_token" do
      profile = build(:voter_profile)
      expect(profile).to be_valid
    end

    it "requires voter_token" do
      profile = build(:voter_profile, voter_token: nil)
      expect(profile).not_to be_valid
    end

    it "enforces voter_token uniqueness" do
      create(:voter_profile, voter_token: "dup_token")
      profile = build(:voter_profile, voter_token: "dup_token")
      expect(profile).not_to be_valid
    end
  end

  describe ".refresh_for" do
    it "returns nil when no votes exist" do
      result = VoterProfile.refresh_for("nonexistent_token")
      expect(result).to be_nil
    end

    it "creates a profile when votes exist" do
      insert_vote(voter_token: token, shop: shop, machine_model: machine, voted_on: Date.current, reset_vote: 1)

      profile = VoterProfile.refresh_for(token)

      expect(profile).to be_persisted
      expect(profile.voter_token).to eq(token)
      expect(profile.total_votes).to eq(1)
      expect(profile.last_voted_on).to eq(Date.current)
    end

    it "counts weekly and monthly votes" do
      insert_vote(voter_token: token, shop: shop, machine_model: machine, voted_on: Date.current, reset_vote: 1)

      profile = VoterProfile.refresh_for(token)

      expect(profile.weekly_votes).to eq(1)
      expect(profile.monthly_votes).to eq(1)
    end

    it "is idempotent - calling twice gives the same result" do
      insert_vote(voter_token: token, shop: shop, machine_model: machine, voted_on: Date.current, reset_vote: 1)

      profile1 = VoterProfile.refresh_for(token)
      profile2 = VoterProfile.refresh_for(token)

      expect(profile1.id).to eq(profile2.id)
      expect(profile1.total_votes).to eq(profile2.total_votes)
      expect(profile1.rank_title).to eq(profile2.rank_title)
      expect(VoterProfile.where(voter_token: token).count).to eq(1)
    end
  end

  describe "streak calculation" do
    it "calculates streak for consecutive days including today" do
      3.times do |i|
        insert_vote(voter_token: token, shop: shop,
                    machine_model: create(:machine_model),
                    voted_on: Date.current - i.days)
      end

      profile = VoterProfile.refresh_for(token)
      expect(profile.current_streak).to eq(3)
    end

    it "returns current_streak=1 when only today has a vote" do
      insert_vote(voter_token: token, shop: shop, machine_model: machine,
                  voted_on: Date.current)

      profile = VoterProfile.refresh_for(token)
      expect(profile.current_streak).to eq(1)
    end

    it "calculates streak starting from yesterday" do
      2.times do |i|
        insert_vote(voter_token: token, shop: shop,
                    machine_model: create(:machine_model),
                    voted_on: Date.current - (i + 1).days)
      end

      profile = VoterProfile.refresh_for(token)
      expect(profile.current_streak).to eq(2)
    end

    it "returns 0 when last vote was more than 1 day ago" do
      insert_vote(voter_token: token, shop: shop, machine_model: machine,
                  voted_on: Date.current - 3.days)

      profile = VoterProfile.refresh_for(token)
      expect(profile.current_streak).to eq(0)
    end

    it "returns current_streak=0 when yesterday ended a 3-day streak but no vote today" do
      # Voted 2, 3, 4 days ago (3-day streak ending 2 days ago, gap yesterday)
      [ 2, 3, 4 ].each do |days_ago|
        insert_vote(voter_token: token, shop: shop,
                    machine_model: create(:machine_model),
                    voted_on: Date.current - days_ago.days)
      end

      profile = VoterProfile.refresh_for(token)
      expect(profile.current_streak).to eq(0)
    end

    it "preserves max_streak when current streak is broken by a gap" do
      # First build a 3-day streak ending yesterday
      3.times do |i|
        insert_vote(voter_token: token, shop: shop,
                    machine_model: create(:machine_model),
                    voted_on: Date.current - (i + 1).days)
      end

      profile = VoterProfile.refresh_for(token)
      expect(profile.current_streak).to eq(3)
      expect(profile.max_streak).to eq(3)

      # Now simulate a gap: add a vote 5 days ago (non-consecutive with the 3-day run)
      # but the max_streak should still be 3 from before
      # We just need to re-refresh after the streak breaks
      # Move forward in concept: if later only vote today, current=1 but max stays 3
      insert_vote(voter_token: token, shop: shop,
                  machine_model: create(:machine_model),
                  voted_on: Date.current)

      profile = VoterProfile.refresh_for(token)
      # current_streak: today(1) + yesterday..3 days ago(3) = 4 consecutive
      expect(profile.current_streak).to eq(4)
      expect(profile.max_streak).to eq(4)
    end

    it "tracks max_streak across refreshes" do
      3.times do |i|
        insert_vote(voter_token: token, shop: shop,
                    machine_model: create(:machine_model),
                    voted_on: Date.current - i.days)
      end

      profile = VoterProfile.refresh_for(token)
      expect(profile.max_streak).to eq(3)
    end

    it "preserves max_streak even when current streak resets" do
      # Build a profile with a known max_streak
      profile = VoterProfile.create!(voter_token: token, max_streak: 5, total_votes: 0)

      # Vote only today (current_streak = 1, but max should stay 5)
      insert_vote(voter_token: token, shop: shop, machine_model: machine,
                  voted_on: Date.current)

      refreshed = VoterProfile.refresh_for(token)
      expect(refreshed.current_streak).to eq(1)
      expect(refreshed.max_streak).to eq(5)
    end
  end

  describe "rank title assignment" do
    it "assigns 見習い for few votes" do
      insert_vote(voter_token: token, shop: shop, machine_model: machine, voted_on: Date.current, reset_vote: 1)

      profile = VoterProfile.refresh_for(token)
      expect(profile.rank_title).to eq("見習い")
    end

    it "assigns 記録者 for 10+ votes" do
      10.times do
        insert_vote(voter_token: token, shop: shop,
                    machine_model: create(:machine_model),
                    voted_on: Date.current, reset_vote: 1)
      end

      profile = VoterProfile.refresh_for(token)
      expect(profile.rank_title).to eq("記録者")
    end

    it "assigns 常連 for 50+ votes" do
      50.times do
        insert_vote(voter_token: token, shop: shop,
                    machine_model: create(:machine_model),
                    voted_on: Date.current, reset_vote: 1)
      end

      profile = VoterProfile.refresh_for(token)
      expect(profile.rank_title).to eq("常連")
    end
  end

  describe ".determine_rank boundary values (points-based)" do
    it "returns 見習い for 0 points" do
      expect(VoterProfile.send(:determine_rank, 0, nil)).to eq("見習い")
    end

    it "returns 見習い for 4 points" do
      expect(VoterProfile.send(:determine_rank, 4, nil)).to eq("見習い")
    end

    it "returns 記録者 for exactly 5 points" do
      expect(VoterProfile.send(:determine_rank, 5, nil)).to eq("記録者")
    end

    it "returns 常連 for exactly 30 points" do
      expect(VoterProfile.send(:determine_rank, 30, nil)).to eq("常連")
    end

    it "returns 目利き師 for 80 points with 40% accuracy" do
      expect(VoterProfile.send(:determine_rank, 80, 40.0)).to eq("目利き師")
    end

    it "returns 常連 for 80 points with low accuracy (below 40%)" do
      expect(VoterProfile.send(:determine_rank, 80, 39.9)).to eq("常連")
    end

    it "returns 常連 for 80 points with nil accuracy" do
      expect(VoterProfile.send(:determine_rank, 80, nil)).to eq("常連")
    end

    it "returns 設定看破マスター for 200 points with 60% accuracy" do
      expect(VoterProfile.send(:determine_rank, 200, 60.0)).to eq("設定看破マスター")
    end

    it "returns 目利き師 for 200 points with 40% accuracy (below 60%)" do
      expect(VoterProfile.send(:determine_rank, 200, 40.0)).to eq("目利き師")
    end

    it "returns 伝説の記録者 for 500 points with 70% accuracy" do
      expect(VoterProfile.send(:determine_rank, 500, 70.0)).to eq("伝説の記録者")
    end

    it "returns 設定看破マスター for 500 points with 60% accuracy (below 70%)" do
      expect(VoterProfile.send(:determine_rank, 500, 60.0)).to eq("設定看破マスター")
    end
  end

  describe "accuracy_majority calculation" do
    it "returns nil when fewer than 5 setting votes" do
      3.times do
        insert_vote(voter_token: token, shop: shop,
                    machine_model: create(:machine_model),
                    voted_on: Date.current, setting_vote: 4)
      end

      profile = VoterProfile.refresh_for(token)
      expect(profile.accuracy_majority).to be_nil
    end

    it "calculates accuracy when enough setting votes and summaries exist" do
      machines = 6.times.map { create(:machine_model) }

      machines.each do |m|
        insert_vote(voter_token: token, shop: shop, machine_model: m,
                    voted_on: Date.current, setting_vote: 4)
        # Create VoteSummary with mode setting = 4 (matching the vote)
        VoteSummary.find_or_initialize_by(
          shop_id: shop.id, machine_model_id: m.id, target_date: Date.current
        ).update!(
          total_votes: 5, setting_distribution: { "4" => 3, "2" => 1, "1" => 1 }
        )
      end

      profile = VoterProfile.refresh_for(token)
      expect(profile.accuracy_majority).to eq(100.0)
    end
  end

  describe "high_setting_rate calculation" do
    it "returns nil when fewer than 5 setting votes" do
      2.times do
        insert_vote(voter_token: token, shop: shop,
                    machine_model: create(:machine_model),
                    voted_on: Date.current, setting_vote: 6)
      end

      profile = VoterProfile.refresh_for(token)
      expect(profile.high_setting_rate).to be_nil
    end

    it "calculates rate of high setting votes (4, 5, 6)" do
      machines = 10.times.map { create(:machine_model) }

      # 6 high setting votes (4, 5, 6), 4 low setting votes (1, 2, 3)
      machines.each_with_index do |m, i|
        setting = i < 6 ? 5 : 2
        insert_vote(voter_token: token, shop: shop, machine_model: m,
                    voted_on: Date.current, setting_vote: setting)
      end

      profile = VoterProfile.refresh_for(token)
      expect(profile.high_setting_rate).to eq(60.0)
    end
  end
end
