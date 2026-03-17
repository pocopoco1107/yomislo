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

    it "aggregates confirmed_setting_counts" do
      create(:vote, shop: shop, machine_model: machine, voted_on: date,
             reset_vote: nil, setting_vote: nil, confirmed_setting: [ "6確", "偶数確" ])
      create(:vote, shop: shop, machine_model: machine, voted_on: date,
             reset_vote: nil, setting_vote: nil, confirmed_setting: [ "6確" ])
      create(:vote, shop: shop, machine_model: machine, voted_on: date,
             reset_vote: 1, setting_vote: nil, confirmed_setting: [ "4以上" ])

      summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
      expect(summary.confirmed_setting_counts["6確"]).to eq(2)
      expect(summary.confirmed_setting_counts["偶数確"]).to eq(1)
      expect(summary.confirmed_setting_counts["4以上"]).to eq(1)
    end
  end

  describe ".refresh_for boundary cases" do
    let(:shop) { create(:shop) }
    let(:machine) { create(:machine_model) }
    let(:date) { Date.current }

    context "with 0 votes" do
      it "creates an empty summary" do
        summary = VoteSummary.refresh_for(shop.id, machine.id, date)

        expect(summary).to be_persisted
        expect(summary.total_votes).to eq(0)
        expect(summary.reset_yes_count).to eq(0)
        expect(summary.reset_no_count).to eq(0)
        expect(summary.setting_avg).to be_nil
        expect(summary.setting_distribution).to eq({})
        expect(summary.confirmed_setting_counts).to eq({})
      end
    end

    context "with exactly 1 vote" do
      it "sets total_votes to 1 and calculates correctly" do
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: 1, setting_vote: 3)

        summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
        expect(summary.total_votes).to eq(1)
        expect(summary.reset_yes_count).to eq(1)
        expect(summary.reset_no_count).to eq(0)
        expect(summary.setting_avg).to eq(3.0)
        expect(summary.enough_data?).to be false
      end
    end

    context "setting_avg with mixed votes (1, 3, 6)" do
      it "calculates correct average as 3.3" do
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: nil, setting_vote: 1)
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: nil, setting_vote: 3)
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: nil, setting_vote: 6)

        summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
        expect(summary.setting_avg).to eq(3.3)
      end
    end

    context "setting_distribution jsonb structure" do
      it "contains all keys 1-6 with correct counts" do
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: nil, setting_vote: 1)
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: nil, setting_vote: 1)
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: nil, setting_vote: 5)

        summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
        expect(summary.setting_distribution.keys).to contain_exactly("1", "2", "3", "4", "5", "6")
        expect(summary.setting_distribution["1"]).to eq(2)
        expect(summary.setting_distribution["5"]).to eq(1)
        expect(summary.setting_distribution.values_at("2", "3", "4", "6")).to all(eq(0))
      end

      it "returns empty hash when no setting votes exist" do
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: 1, setting_vote: nil)

        summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
        expect(summary.setting_distribution).to eq({})
      end
    end

    context "confirmed_setting_counts aggregation" do
      it "returns empty hash when no confirmed settings" do
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: 1, setting_vote: nil)

        summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
        expect(summary.confirmed_setting_counts).to eq({})
      end

      it "handles a single vote with multiple tags" do
        create(:vote, shop: shop, machine_model: machine, voted_on: date,
               reset_vote: nil, setting_vote: nil,
               confirmed_setting: [ "偶数確", "4以上", "6確" ])

        summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
        expect(summary.confirmed_setting_counts).to eq({ "偶数確" => 1, "4以上" => 1, "6確" => 1 })
      end
    end

    context "reset counts boundary" do
      it "handles all Yes votes" do
        3.times { create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: 1, setting_vote: nil) }

        summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
        expect(summary.reset_yes_count).to eq(3)
        expect(summary.reset_no_count).to eq(0)
        expect(summary.reset_rate).to eq(100)
      end

      it "handles all No votes" do
        3.times { create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: 0, setting_vote: nil) }

        summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
        expect(summary.reset_yes_count).to eq(0)
        expect(summary.reset_no_count).to eq(3)
        expect(summary.reset_rate).to eq(0)
      end

      it "handles mixed Yes/No votes" do
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: 1, setting_vote: nil)
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: 0, setting_vote: nil)

        summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
        expect(summary.reset_yes_count).to eq(1)
        expect(summary.reset_no_count).to eq(1)
        expect(summary.reset_rate).to eq(50)
      end

      it "returns nil reset_rate when no reset votes exist" do
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: nil, setting_vote: 3)

        summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
        expect(summary.reset_rate).to be_nil
      end
    end

    context "enough_data? threshold" do
      it "returns false with 2 votes" do
        2.times { create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: 1) }

        summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
        expect(summary.enough_data?).to be false
      end

      it "returns true with exactly 3 votes" do
        3.times { create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: 1) }

        summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
        expect(summary.enough_data?).to be true
      end
    end

    context "multiple votes same day same shop×machine" do
      it "aggregates all votes into a single summary record" do
        5.times do |i|
          create(:vote, shop: shop, machine_model: machine, voted_on: date,
                 reset_vote: i.even? ? 1 : 0, setting_vote: (i % 6) + 1)
        end

        summaries = VoteSummary.where(shop: shop, machine_model: machine, target_date: date)
        expect(summaries.count).to eq(1)

        summary = summaries.first
        expect(summary.total_votes).to eq(5)
        expect(summary.reset_yes_count).to eq(3)
        expect(summary.reset_no_count).to eq(2)
      end
    end

    context "setting_avg decimal precision" do
      it "rounds to 1 decimal place for 1/3 repeating" do
        # (1 + 2) / 2 = 1.5
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: nil, setting_vote: 1)
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: nil, setting_vote: 2)

        summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
        expect(summary.setting_avg).to eq(1.5)
      end

      it "rounds 3.333... to 3.3" do
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: nil, setting_vote: 1)
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: nil, setting_vote: 3)
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: nil, setting_vote: 6)

        summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
        expect(summary.setting_avg).to eq(3.3)
      end

      it "rounds 4.666... to 4.7" do
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: nil, setting_vote: 4)
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: nil, setting_vote: 4)
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: nil, setting_vote: 6)

        summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
        expect(summary.setting_avg).to eq(4.7)
      end
    end

    context "confirmed_setting comprehensive aggregation" do
      it "aggregates same tags from multiple votes" do
        3.times do
          create(:vote, shop: shop, machine_model: machine, voted_on: date,
                 reset_vote: nil, setting_vote: nil, confirmed_setting: [ "6確" ])
        end

        summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
        expect(summary.confirmed_setting_counts["6確"]).to eq(3)
      end

      it "correctly counts overlapping and unique tags across votes" do
        create(:vote, shop: shop, machine_model: machine, voted_on: date,
               reset_vote: nil, setting_vote: nil, confirmed_setting: [ "6確", "偶数確" ])
        create(:vote, shop: shop, machine_model: machine, voted_on: date,
               reset_vote: nil, setting_vote: nil, confirmed_setting: [ "6確", "4以上" ])
        create(:vote, shop: shop, machine_model: machine, voted_on: date,
               reset_vote: nil, setting_vote: nil, confirmed_setting: [ "偶数確" ])

        summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
        expect(summary.confirmed_setting_counts["6確"]).to eq(2)
        expect(summary.confirmed_setting_counts["偶数確"]).to eq(2)
        expect(summary.confirmed_setting_counts["4以上"]).to eq(1)
      end
    end

    context "refresh_for idempotency" do
      it "updates existing summary rather than creating a new one" do
        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: 1, setting_vote: 3)
        expect(VoteSummary.where(shop: shop, machine_model: machine, target_date: date).count).to eq(1)

        create(:vote, shop: shop, machine_model: machine, voted_on: date, reset_vote: 0, setting_vote: 5)
        expect(VoteSummary.where(shop: shop, machine_model: machine, target_date: date).count).to eq(1)

        summary = VoteSummary.find_by(shop: shop, machine_model: machine, target_date: date)
        expect(summary.total_votes).to eq(2)
      end
    end
  end
end
