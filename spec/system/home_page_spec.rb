require "rails_helper"

RSpec.describe "Home page", type: :system do
  let!(:tokyo) { create(:prefecture, name: "東京都", slug: "tokyo") }
  let!(:osaka) { create(:prefecture, name: "大阪府", slug: "osaka") }
  let!(:shop) { create(:shop, name: "テスト店舗X", slug: "test-shop-x", prefecture: tokyo) }

  describe "hero section" do
    it "displays the time-based hero tagline and stats" do
      travel_to Time.zone.local(2026, 5, 20, 12, 0) do
        visit root_path

        expect(page).to have_content("調子はどう？")
        expect(page).to have_content("台の機嫌")
        expect(page).to have_content("累計")
        expect(page).to have_content("今日")
      end
    end
  end

  describe "search bar" do
    it "displays the search input" do
      visit root_path

      expect(page).to have_field(type: "search", placeholder: "店舗名で検索")
    end
  end

  describe "prefecture list" do
    it "displays the prefecture section with region groups" do
      visit root_path

      expect(page).to have_content("都道府県からさがす")
      expect(page).to have_content("北海道・東北")
      expect(page).to have_content("関東")
      expect(page).to have_content("中部")
      expect(page).to have_content("近畿")
      expect(page).to have_content("中国")
      expect(page).to have_content("四国")
      expect(page).to have_content("九州・沖縄")
    end
  end

  describe "prefecture section" do
    it "displays prefecture grid" do
      visit root_path

      expect(page).to have_content("都道府県からさがす")
    end
  end

  describe "search section" do
    it "displays the shop/machine search heading" do
      visit root_path

      expect(page).to have_content("店舗・機種検索")
    end
  end

  describe "voter status link" do
    it "displays a link to voter status" do
      visit root_path

      expect(page).to have_link(href: voter_status_path)
    end
  end
end
