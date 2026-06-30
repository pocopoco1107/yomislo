require "rails_helper"

RSpec.describe PromotionsHelper, type: :helper do
  describe "#promotions_enabled?" do
    it "is false when ENV is unset" do
      ENV.delete("PROMOTIONS_ENABLED")
      expect(helper.promotions_enabled?).to be(false)
    end

    it "is true only when ENV is exactly 'true'" do
      ENV["PROMOTIONS_ENABLED"] = "true"
      expect(helper.promotions_enabled?).to be(true)
    ensure
      ENV.delete("PROMOTIONS_ENABLED")
    end

    it "is false for other truthy-ish strings" do
      ENV["PROMOTIONS_ENABLED"] = "1"
      expect(helper.promotions_enabled?).to be(false)
    ensure
      ENV.delete("PROMOTIONS_ENABLED")
    end
  end

  describe "#render_promotion" do
    context "when disabled" do
      before { ENV.delete("PROMOTIONS_ENABLED") }

      it "renders nothing even with promotions present" do
        create(:promotion, slot_keys: %w[home_hero])
        expect(helper.render_promotion(:home_hero)).to be_nil
      end
    end

    context "when enabled" do
      before { ENV["PROMOTIONS_ENABLED"] = "true" }
      after  { ENV.delete("PROMOTIONS_ENABLED") }

      it "renders nothing if no promotion matches the slot" do
        create(:promotion, slot_keys: %w[voter_status])
        expect(helper.render_promotion(:home_hero)).to be_nil
      end

      it "renders nothing if all matching promotions are inactive" do
        create(:promotion, slot_keys: %w[home_hero], active: false)
        expect(helper.render_promotion(:home_hero)).to be_nil
      end

      it "renders banner partial markup when slot has an active promotion" do
        create(:promotion, title: "テスト案件", slot_keys: %w[home_hero])
        output = helper.render_promotion(:home_hero, variant: :banner)
        expect(output).to include("テスト案件")
        expect(output).to include("data-promotion-slot=\"home_hero\"")
        expect(output).to include("PR")
        expect(output).to include('rel="sponsored noopener noreferrer"')
      end

      it "renders card partial markup by default" do
        create(:promotion, title: "カード案件", slot_keys: %w[voter_status])
        output = helper.render_promotion(:voter_status)
        expect(output).to include("カード案件")
        expect(output).to include("data-promotion-slot=\"voter_status\"")
      end
    end
  end
end
