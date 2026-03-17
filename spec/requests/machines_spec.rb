require "rails_helper"

RSpec.describe "Machines", type: :request do
  let(:machine) { create(:machine_model) }

  describe "GET /machines/:slug" do
    it "renders the machine page" do
      get machine_path(machine.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(machine.name)
    end

    it "returns 404 for invalid slug" do
      get machine_path("nonexistent-machine-999")
      expect(response).to have_http_status(:not_found)
    end

    it "shows installed shops" do
      shop = create(:shop)
      ShopMachineModel.create!(shop: shop, machine_model: machine)

      get machine_path(machine.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(shop.name)
      expect(response.body).to include("設置店舗を探す")
    end

    it "shows installed shop count" do
      3.times do
        shop = create(:shop)
        ShopMachineModel.create!(shop: shop, machine_model: machine)
      end

      get machine_path(machine.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("3店")
    end

    it "shows unit count when available" do
      shop = create(:shop)
      ShopMachineModel.create!(shop: shop, machine_model: machine, unit_count: 10)

      get machine_path(machine.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("10台")
    end

    it "filters shops by prefecture" do
      pref1 = create(:prefecture, name: "東京都", slug: "tokyo")
      pref2 = create(:prefecture, name: "大阪府", slug: "osaka")
      shop1 = create(:shop, prefecture: pref1, name: "東京店舗")
      shop2 = create(:shop, prefecture: pref2, name: "大阪店舗")
      ShopMachineModel.create!(shop: shop1, machine_model: machine)
      ShopMachineModel.create!(shop: shop2, machine_model: machine)

      get machine_path(machine.slug), params: { prefecture: "tokyo" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("東京店舗")
      expect(response.body).not_to include("大阪店舗")
    end

    it "shows prefecture filter options" do
      pref = create(:prefecture, name: "東京都", slug: "tokyo")
      shop = create(:shop, prefecture: pref)
      ShopMachineModel.create!(shop: shop, machine_model: machine)

      get machine_path(machine.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("東京都")
    end

    it "renders empty state when no shops are installed" do
      get machine_path(machine.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("設置店舗情報がありません")
    end

    it "shows rate badges on shop cards" do
      shop = create(:shop, slot_rates: [ "20スロ", "5スロ" ])
      ShopMachineModel.create!(shop: shop, machine_model: machine)

      get machine_path(machine.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("20スロ")
      expect(response.body).to include("5スロ")
    end

    it "shows exchange rate on shop cards" do
      shop = create(:shop, exchange_rate: :equal_rate)
      ShopMachineModel.create!(shop: shop, machine_model: machine)

      get machine_path(machine.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("等価")
    end

    it "paginates installed shops" do
      35.times do
        shop = create(:shop)
        ShopMachineModel.create!(shop: shop, machine_model: machine)
      end

      get machine_path(machine.slug)
      expect(response).to have_http_status(:ok)

      get machine_path(machine.slug), params: { shops_page: 2 }
      expect(response).to have_http_status(:ok)
    end

    it "shows trend chart when vote data exists" do
      shop = create(:shop)
      ShopMachineModel.create!(shop: shop, machine_model: machine)
      # Create VoteSummary records directly (Vote model only allows today/yesterday)
      [ Date.current, Date.current - 1, Date.current - 2 ].each do |date|
        VoteSummary.create!(shop: shop, machine_model: machine,
                            target_date: date, total_votes: 5,
                            reset_yes_count: 3, reset_no_count: 2,
                            setting_avg: 3.5)
      end

      get machine_path(machine.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("過去7日間の全国記録トレンド")
    end

    it "does not show trend chart when no votes exist" do
      get machine_path(machine.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("過去7日間の全国記録トレンド")
    end

    it "shows generation badge when present" do
      machine.update!(generation: "6.5号機")
      get machine_path(machine.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("6.5号機")
    end

    it "shows payout rate when present" do
      machine.update!(payout_rate_min: 97.9, payout_rate_max: 114.9)
      get machine_path(machine.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("機械割")
      expect(response.body).to include("97.9%")
      expect(response.body).to include("114.9%")
    end

    it "shows type detail when present" do
      machine.update!(type_detail: "AT、天井、純増約5.0枚/G")
      get machine_path(machine.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("AT、天井、純増約5.0枚/G")
    end

    it "shows image when image_url is present" do
      machine.update!(image_url: "https://example.com/machine.jpg")
      get machine_path(machine.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("https://example.com/machine.jpg")
    end

    it "includes JSON-LD structured data" do
      machine.update!(maker: "テストメーカー", payout_rate_min: 97.9, payout_rate_max: 114.9)
      get machine_path(machine.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("application/ld+json")
      expect(response.body).to include("schema.org")
    end

    it "includes payout rate in meta description" do
      machine.update!(payout_rate_min: 97.9, payout_rate_max: 114.9)
      get machine_path(machine.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("機械割")
    end
  end

  describe "GET /machines/search" do
    it "returns matching machines" do
      machine = create(:machine_model, name: "ジャグラー", active: true)
      shop = create(:shop)

      get search_machines_path, params: { q: "ジャグラー", shop_id: shop.id, date: Date.current }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ジャグラー")
    end

    it "returns empty for short query" do
      get search_machines_path, params: { q: "", shop_id: 1, date: Date.current }
      expect(response).to have_http_status(:ok)
    end
  end
end
