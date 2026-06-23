require "rails_helper"

RSpec.describe PlayRecordSummary, type: :model do
  let(:shop) { create(:shop) }
  let(:machine) { create(:machine_model) }

  describe "validations" do
    it "is valid with required attributes" do
      summary = build(:play_record_summary, scope_id: shop.id)
      expect(summary).to be_valid
    end

    it "requires scope_type" do
      summary = build(:play_record_summary, scope_type: nil)
      expect(summary).not_to be_valid
    end

    it "requires scope_id" do
      summary = build(:play_record_summary, scope_id: nil)
      expect(summary).not_to be_valid
    end

    it "requires period_key" do
      summary = build(:play_record_summary, period_key: nil)
      expect(summary).not_to be_valid
    end

    it "validates scope_type inclusion" do
      summary = build(:play_record_summary, scope_type: "invalid")
      expect(summary).not_to be_valid
    end

    it "enforces uniqueness of scope_type/scope_id/period_type/period_key" do
      create(:play_record_summary, scope_type: "shop", scope_id: 1,
             period_type: :monthly, period_key: "2026-03")
      dup = build(:play_record_summary, scope_type: "shop", scope_id: 1,
                  period_type: :monthly, period_key: "2026-03")
      expect(dup).not_to be_valid
    end
  end

  describe "enum" do
    it "defines period_type enum" do
      expect(PlayRecordSummary.period_types).to eq("monthly" => 0, "all_time" => 1)
    end
  end

  describe ".refresh_for_shop!" do
    it "creates a summary for a shop with play records" do
      create(:play_record, shop: shop, machine_model: machine,
             result_amount: 10_000, is_public: true, played_on: Date.current)
      create(:play_record, shop: shop, machine_model: create(:machine_model),
             result_amount: -5_000, is_public: true, played_on: Date.current)

      month_key = Date.current.strftime("%Y-%m")
      summary = PlayRecordSummary.refresh_for_shop!(shop.id, period_key: month_key)

      expect(summary).to be_persisted
      expect(summary.total_records).to eq(2)
      expect(summary.total_result).to eq(5_000)
      expect(summary.win_count).to eq(1)
      expect(summary.lose_count).to eq(1)
      expect(summary.win_rate).to eq(50.0)
    end

    it "creates an empty summary when no records exist" do
      month_key = Date.current.strftime("%Y-%m")
      summary = PlayRecordSummary.refresh_for_shop!(shop.id, period_key: month_key)

      expect(summary.total_records).to eq(0)
      expect(summary.total_result).to eq(0)
    end
  end

  describe "aggregation scope" do
    it "excludes private records" do
      create(:play_record, shop: shop, machine_model: machine,
             result_amount: 50_000, is_public: false, played_on: Date.current)
      create(:play_record, shop: shop, machine_model: create(:machine_model),
             result_amount: 10_000, is_public: true, played_on: Date.current)

      month_key = Date.current.strftime("%Y-%m")
      summary = PlayRecordSummary.refresh_for_shop!(shop.id, period_key: month_key)

      expect(summary.total_records).to eq(1)
      expect(summary.total_result).to eq(10_000)
    end

    it "excludes records with |amount| > 500,000" do
      create(:play_record, shop: shop, machine_model: machine,
             result_amount: 600_000, is_public: true, played_on: Date.current)
      create(:play_record, shop: shop, machine_model: create(:machine_model),
             result_amount: 20_000, is_public: true, played_on: Date.current)

      month_key = Date.current.strftime("%Y-%m")
      summary = PlayRecordSummary.refresh_for_shop!(shop.id, period_key: month_key)

      expect(summary.total_records).to eq(1)
      expect(summary.total_result).to eq(20_000)
    end
  end

  describe "win rate calculation" do
    it "calculates win rate correctly" do
      # 3 wins, 1 loss => 75% win rate
      3.times do
        create(:play_record, shop: shop, machine_model: create(:machine_model),
               result_amount: 10_000, is_public: true, played_on: Date.current)
      end
      create(:play_record, shop: shop, machine_model: create(:machine_model),
             result_amount: -5_000, is_public: true, played_on: Date.current)

      month_key = Date.current.strftime("%Y-%m")
      summary = PlayRecordSummary.refresh_for_shop!(shop.id, period_key: month_key)

      expect(summary.win_rate).to eq(75.0)
    end

    it "全件 ±0(勝敗なし)でも win_rate が NaN にならず 0.0 になる" do
      # wins=0, losses=0 のゼロ除算で NaN になるのを防ぐガードの回帰テスト
      create(:play_record, shop: shop, machine_model: machine,
             result_amount: 0, is_public: true, played_on: Date.current)
      create(:play_record, shop: shop, machine_model: create(:machine_model),
             result_amount: 0, is_public: true, played_on: Date.current)

      summary = PlayRecordSummary.refresh_for_shop!(shop.id)

      expect(summary.total_records).to eq(2)
      expect(summary.win_rate).to eq(0.0)
      expect(summary.win_rate.to_f).not_to be_nan
    end

    it "handles all-time period" do
      create(:play_record, shop: shop, machine_model: machine,
             result_amount: 30_000, is_public: true, played_on: Date.current)

      summary = PlayRecordSummary.refresh_for_shop!(shop.id)

      expect(summary.period_type).to eq("all_time")
      expect(summary.period_key).to eq("all")
      expect(summary.total_records).to eq(1)
    end
  end

  describe ".refresh_for_machine_model!" do
    it "aggregates by machine model" do
      create(:play_record, shop: shop, machine_model: machine,
             result_amount: 15_000, is_public: true, played_on: Date.current)
      create(:play_record, shop: create(:shop), machine_model: machine,
             result_amount: -8_000, is_public: true, played_on: Date.current)

      month_key = Date.current.strftime("%Y-%m")
      summary = PlayRecordSummary.refresh_for_machine_model!(machine.id, period_key: month_key)

      expect(summary.scope_type).to eq("machine_model")
      expect(summary.total_records).to eq(2)
      expect(summary.total_result).to eq(7_000)
    end
  end
end
