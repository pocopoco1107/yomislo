require "rails_helper"

RSpec.describe ShopsHelper, type: :helper do
  describe "#shop_facility_badges" do
    it "returns badges only for true flags" do
      shop = build(:shop, wifi_available: true, charging_available: true,
                          heated_tobacco_ok: false, slot_smoking_ok: nil,
                          low_rate_slot: true)
      badges = helper.shop_facility_badges(shop)
      expect(badges).to contain_exactly("Wi-Fi", "充電OK", "低貸しあり")
    end

    it "returns empty array when no flags are true" do
      shop = build(:shop)
      expect(helper.shop_facility_badges(shop)).to eq([])
    end
  end
end
