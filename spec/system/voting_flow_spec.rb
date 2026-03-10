require "rails_helper"

RSpec.describe "Voting flow", type: :system do
  let!(:prefecture) { create(:prefecture, name: "東京都", slug: "tokyo") }
  let!(:shop) { create(:shop, name: "テスト店舗A", slug: "test-shop-a", prefecture: prefecture) }
  let!(:machine_model) { create(:machine_model, name: "テスト機種1", slug: "test-machine-1") }
  let!(:shop_machine_model) { ShopMachineModel.create!(shop: shop, machine_model: machine_model) }

  describe "shop page displays voting UI" do
    it "shows the shop name and machine vote row" do
      visit shop_path(shop.slug)

      expect(page).to have_content("テスト店舗A")
      expect(page).to have_content("テスト機種1")
    end
  end

  describe "reset vote", skip: "Turbo Frame form submission requires JS driver" do
    it "submits a reset Yes vote" do
      visit shop_path(shop.slug)
      within("turbo-frame#machine_vote_#{machine_model.id}") do
        click_button "Yes"
      end
      expect(Vote.count).to eq(1)
    end
  end

  describe "setting vote", skip: "Turbo Frame form submission requires JS driver" do
    it "submits a setting vote" do
      visit shop_path(shop.slug)
      within("turbo-frame#machine_vote_#{machine_model.id}") do
        click_button "4"
      end
      expect(Vote.count).to eq(1)
    end
  end
end
