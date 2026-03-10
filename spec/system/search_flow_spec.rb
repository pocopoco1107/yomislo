require "rails_helper"

RSpec.describe "Search flow", type: :system do
  let!(:tokyo) { create(:prefecture, name: "東京都", slug: "tokyo") }
  let!(:osaka) { create(:prefecture, name: "大阪府", slug: "osaka") }
  let!(:shop_tokyo) { create(:shop, name: "新宿パチスロ館", slug: "shinjuku-slot", prefecture: tokyo) }
  let!(:shop_osaka) { create(:shop, name: "梅田スロットセンター", slug: "umeda-slot", prefecture: osaka) }

  describe "search page" do
    it "displays the search form with prefecture select" do
      visit search_path

      expect(page).to have_content("全国店舗検索")
      expect(page).to have_select("prefectures[]")
      expect(page).to have_field(type: "text", name: "q")
    end

    it "filters shops by prefecture" do
      visit search_path(prefectures: [tokyo.slug])

      expect(page).to have_content("新宿パチスロ館")
      expect(page).not_to have_content("梅田スロットセンター")
    end

    it "filters shops by free text query" do
      visit search_path(q: "新宿")

      expect(page).to have_content("新宿パチスロ館")
      expect(page).not_to have_content("梅田スロットセンター")
    end

    it "shows no results message when no shops match" do
      visit search_path(q: "存在しない店舗名XYZ")

      expect(page).to have_content("条件に一致する店舗がありません")
    end

    it "displays exchange rate filter checkboxes" do
      visit search_path

      expect(page).to have_content("換金率")
      expect(page).to have_field("exchange_rates[]", type: "checkbox")
    end

    it "displays rate filter checkboxes" do
      visit search_path

      expect(page).to have_content("レート")
    end
  end
end
