require "rails_helper"

RSpec.describe Promotion, type: :model do
  describe "validations" do
    it "is valid with required attributes" do
      expect(build(:promotion)).to be_valid
    end

    it "requires title" do
      expect(build(:promotion, title: nil)).not_to be_valid
    end

    it "requires target_url" do
      expect(build(:promotion, target_url: nil)).not_to be_valid
    end

    it "accepts # as placeholder target_url" do
      expect(build(:promotion, target_url: "#")).to be_valid
    end

    it "rejects malformed target_url" do
      expect(build(:promotion, target_url: "not-a-url")).not_to be_valid
    end

    it "rejects unknown slot_keys" do
      expect(build(:promotion, slot_keys: %w[unknown_slot])).not_to be_valid
    end

    it "rejects empty slot_keys" do
      expect(build(:promotion, slot_keys: [])).not_to be_valid
    end

    it "accepts all defined slot keys" do
      expect(build(:promotion, slot_keys: Promotion::SLOT_KEYS)).to be_valid
    end
  end

  describe "scopes" do
    let!(:active_promo)   { create(:promotion, active: true,  slot_keys: %w[home_hero], priority: 10) }
    let!(:inactive_promo) { create(:promotion, active: false, slot_keys: %w[home_hero], priority: 99) }
    let!(:other_slot)     { create(:promotion, active: true,  slot_keys: %w[voter_status], priority: 5) }

    it ".active filters by active flag" do
      expect(Promotion.active).to include(active_promo, other_slot)
      expect(Promotion.active).not_to include(inactive_promo)
    end

    it ".for_slot matches promotions whose slot_keys array contains the key" do
      expect(Promotion.for_slot("home_hero")).to contain_exactly(active_promo, inactive_promo)
      expect(Promotion.for_slot(:voter_status)).to contain_exactly(other_slot)
    end

    it ".prioritized orders by priority desc" do
      expect(Promotion.prioritized.first.priority).to be >= Promotion.prioritized.last.priority
    end
  end

  describe "#category_label" do
    it "returns Japanese label" do
      expect(build(:promotion, category: :point_site).category_label).to eq("ポイ活")
      expect(build(:promotion, category: :credit_card).category_label).to eq("クレジットカード")
    end
  end

  describe "#increment_clicks!" do
    it "increments clicks_count" do
      promo = create(:promotion)
      expect { promo.increment_clicks! }.to change { promo.reload.clicks_count }.by(1)
    end
  end
end
