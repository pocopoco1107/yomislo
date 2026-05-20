require "rails_helper"

RSpec.describe "Search", type: :request do
  describe "GET /search" do
    it "renders the search page" do
      get search_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("全国店舗検索")
    end

    it "returns all shops with no filters" do
      create_list(:shop, 3)
      get search_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(">3</strong>件")
    end

    it "filters by prefecture" do
      pref1 = create(:prefecture, name: "東京都", slug: "tokyo")
      pref2 = create(:prefecture, name: "大阪府", slug: "osaka")
      shop1 = create(:shop, prefecture: pref1, name: "東京店舗")
      create(:shop, prefecture: pref2, name: "大阪店舗")

      get search_path, params: { prefecture: "tokyo" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("東京店舗")
      expect(response.body).not_to include("大阪店舗")
    end

    it "filters by parking" do
      create(:shop, name: "駐車場店", parking_spaces: 100)
      create(:shop, name: "駐車場なし店", parking_spaces: nil)

      get search_path, params: { parking: "yes" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("駐車場店")
      expect(response.body).not_to include("駐車場なし店")
    end

    it "filters by opening hours" do
      create(:shop, name: "9時店", business_hours: "9:00〜23:00")
      create(:shop, name: "10時店", business_hours: "10:00〜23:00")

      get search_path, params: { opening_hours: [ "9" ] }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("9時店")
      expect(response.body).not_to include("10時店")
    end

    it "filters by morning entry" do
      create(:shop, name: "整理券店", morning_entry: "抽選 8:30〜")
      create(:shop, name: "普通店", morning_entry: nil)

      get search_path, params: { morning_entry: "yes" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("整理券店")
      expect(response.body).not_to include("普通店")
    end

    it "filters by free text" do
      create(:shop, name: "マルハン新宿店")
      create(:shop, name: "ガイア池袋店")

      get search_path, params: { q: "マルハン" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("マルハン新宿店")
      expect(response.body).not_to include("ガイア池袋店")
    end

    it "combines multiple filters with AND" do
      pref = create(:prefecture, name: "東京都", slug: "tokyo")
      create(:shop, name: "東京駐車場店", prefecture: pref, parking_spaces: 100)
      create(:shop, name: "東京駐車場なし店", prefecture: pref, parking_spaces: nil)
      create(:shop, name: "大阪駐車場店", parking_spaces: 100)

      get search_path, params: { prefecture: "tokyo", parking: "yes" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("東京駐車場店")
      expect(response.body).not_to include("東京駐車場なし店")
      expect(response.body).not_to include("大阪駐車場店")
    end

    it "shows empty state when no results" do
      get search_path, params: { q: "存在しない店舗名XXXX" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("条件に一致する店舗がありません")
    end

    it "paginates results" do
      create_list(:shop, 35)
      get search_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(">35</strong>件")
      # Page 2 link should be present
      expect(response.body).to include("page=2")
    end

    it "shows page 2" do
      create_list(:shop, 35)
      get search_path, params: { page: 2 }
      expect(response).to have_http_status(:ok)
    end
  end
end
