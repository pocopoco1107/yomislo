require "rails_helper"

RSpec.describe "Shops", type: :request do
  let(:shop) { create(:shop) }

  describe "GET /shops/:slug" do
    it "renders the shop page" do
      get shop_path(shop.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(shop.name)
    end

    it "shows linked machines" do
      machine = create(:machine_model)
      ShopMachineModel.create!(shop: shop, machine_model: machine)

      get shop_path(shop.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(machine.name)
    end

    it "returns 404 for invalid slug" do
      get shop_path("nonexistent-slug-999")
      expect(response).to have_http_status(:not_found)
    end

    it "shows vote summaries when votes exist" do
      machine = create(:machine_model)
      ShopMachineModel.create!(shop: shop, machine_model: machine)
      create(:vote, shop: shop, machine_model: machine, voted_on: Date.current, reset_vote: 1, setting_vote: 6)

      get shop_path(shop.slug)
      expect(response).to have_http_status(:ok)
    end

    it "renders correctly with no machines linked" do
      get shop_path(shop.slug)
      expect(response).to have_http_status(:ok)
    end

    it "shows machines that have votes but are not in shop_machine_models" do
      machine = create(:machine_model)
      # No ShopMachineModel record, but vote exists
      create(:vote, shop: shop, machine_model: machine, voted_on: Date.current, reset_vote: 1)

      get shop_path(shop.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(machine.name)
    end

    it "displays multiple machines sorted by display_type" do
      smart = create(:machine_model, name: "スマスロ北斗の拳", slug: "smart-hokuto")
      a_type = create(:machine_model, name: "マイジャグラーＶ", slug: "my-juggler")
      ShopMachineModel.create!(shop: shop, machine_model: smart)
      ShopMachineModel.create!(shop: shop, machine_model: a_type)

      get shop_path(shop.slug)
      expect(response).to have_http_status(:ok)
      body = response.body
      # smart_slot should appear before a_type in the page
      expect(body.index("スマスロ北斗の拳")).to be < body.index("マイジャグラーＶ")
    end

    it "shows trend chart when past vote data exists" do
      machine = create(:machine_model)
      ShopMachineModel.create!(shop: shop, machine_model: machine)
      # Create VoteSummary records directly (Vote model only allows today/yesterday)
      [ Date.current, Date.current - 1, Date.current - 2 ].each do |date|
        VoteSummary.create!(shop: shop, machine_model: machine,
                            target_date: date, total_votes: 5,
                            reset_yes_count: 3, reset_no_count: 2,
                            setting_avg: 3.5)
      end

      get shop_path(shop.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("記録トレンド")
    end

    it "does not show trend chart when no votes exist" do
      get shop_path(shop.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("記録トレンド")
    end
  end

  describe "GET /shops/:slug/dates/:date" do
    it "renders past date data" do
      get date_shop_path(shop.slug, date: Date.yesterday.strftime("%Y-%m-%d"))
      expect(response).to have_http_status(:ok)
    end

    it "renders current date data" do
      get date_shop_path(shop.slug, date: Date.current.strftime("%Y-%m-%d"))
      expect(response).to have_http_status(:ok)
    end

    it "renders a date with votes" do
      machine = create(:machine_model)
      ShopMachineModel.create!(shop: shop, machine_model: machine)
      create(:vote, shop: shop, machine_model: machine, voted_on: Date.current, reset_vote: 1, setting_vote: 4)

      get date_shop_path(shop.slug, date: Date.current.strftime("%Y-%m-%d"))
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(machine.name)
    end

    it "returns 404 for invalid slug with valid date" do
      get date_shop_path("nonexistent-slug", date: Date.current.strftime("%Y-%m-%d"))
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for a date before the site launch (blocks infinite crawl space)" do
      get date_shop_path(shop.slug, date: "1962-12-02")
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for a future date" do
      get date_shop_path(shop.slug, date: Date.tomorrow.strftime("%Y-%m-%d"))
      expect(response).to have_http_status(:not_found)
    end

    it "sets noindex when the past date has no votes" do
      get date_shop_path(shop.slug, date: Date.yesterday.strftime("%Y-%m-%d"))
      expect(response.body).to include('name="robots" content="noindex"')
    end

    it "does not set noindex when the past date has votes" do
      machine = create(:machine_model)
      ShopMachineModel.create!(shop: shop, machine_model: machine)
      VoteSummary.create!(shop: shop, machine_model: machine,
                          target_date: Date.yesterday, total_votes: 2,
                          reset_yes_count: 1, reset_no_count: 1, setting_avg: 3.0)

      get date_shop_path(shop.slug, date: Date.yesterday.strftime("%Y-%m-%d"))
      expect(response.body).not_to include('name="robots" content="noindex"')
    end
  end

  describe "GET /shops/:slug (canonical page)" do
    it "does not set noindex even with zero votes today" do
      get shop_path(shop.slug)
      expect(response.body).not_to include('name="robots" content="noindex"')
    end
  end

  describe "GET /shops/:slug/calendar" do
    it "renders the calendar partial for the current month" do
      get calendar_shop_path(shop.slug, month: Date.current.strftime("%Y-%m"))
      expect(response).to have_http_status(:ok)
    end

    it "renders the calendar partial for an adjacent month" do
      get calendar_shop_path(shop.slug, month: (Date.current - 1.month).strftime("%Y-%m"))
      expect(response).to have_http_status(:ok)
    end

    it "renders vote counts when votes exist in the month" do
      machine = create(:machine_model)
      ShopMachineModel.create!(shop: shop, machine_model: machine)
      create(:vote, shop: shop, machine_model: machine, voted_on: Date.current, reset_vote: 1)

      get calendar_shop_path(shop.slug, month: Date.current.strftime("%Y-%m"))
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for invalid slug" do
      get calendar_shop_path("nonexistent-slug-999", month: Date.current.strftime("%Y-%m"))
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /shops/favorites" do
    it "returns favorite shops" do
      get favorites_shops_path, params: { slugs: shop.slug }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(shop.name)
    end

    it "returns empty response for no slugs" do
      get favorites_shops_path, params: { slugs: "" }
      expect(response).to have_http_status(:ok)
    end

    it "returns empty response for nonexistent slugs" do
      get favorites_shops_path, params: { slugs: "nonexistent-slug" }
      expect(response).to have_http_status(:ok)
    end

    it "limits to 20 slugs" do
      slugs = 25.times.map { create(:shop).slug }.join(",")
      get favorites_shops_path, params: { slugs: slugs }
      expect(response).to have_http_status(:ok)
    end

    it "returns multiple favorite shops" do
      shop2 = create(:shop)
      get favorites_shops_path, params: { slugs: "#{shop.slug},#{shop2.slug}" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(shop.name)
      expect(response.body).to include(shop2.name)
    end
  end

  describe "POST /votes (integration)" do
    let(:machine) { create(:machine_model) }

    before do
      ShopMachineModel.create!(shop: shop, machine_model: machine)
    end

    it "creates a vote with reset_vote" do
      expect {
        post votes_path, params: {
          vote: {
            shop_id: shop.id,
            machine_model_id: machine.id,
            voted_on: Date.current.to_s,
            reset_vote: 1
          }
        }
      }.to change(Vote, :count).by(1)

      expect(response).to have_http_status(:redirect).or have_http_status(:ok)
    end

    it "creates a vote with setting_vote" do
      expect {
        post votes_path, params: {
          vote: {
            shop_id: shop.id,
            machine_model_id: machine.id,
            voted_on: Date.current.to_s,
            setting_vote: 6
          }
        }
      }.to change(Vote, :count).by(1)
    end

    it "creates a vote with confirmed_setting" do
      expect {
        post votes_path, params: {
          vote: {
            shop_id: shop.id,
            machine_model_id: machine.id,
            voted_on: Date.current.to_s,
            confirmed_setting: "6確"
          }
        }
      }.to change(Vote, :count).by(1)
    end

    it "updates existing vote on second submission (merge)" do
      # First vote: reset_vote
      post votes_path, params: {
        vote: {
          shop_id: shop.id,
          machine_model_id: machine.id,
          voted_on: Date.current.to_s,
          reset_vote: 1
        }
      }
      expect(Vote.count).to eq(1)

      # Second submission with setting_vote (same voter_token via cookie)
      post votes_path, params: {
        vote: {
          shop_id: shop.id,
          machine_model_id: machine.id,
          voted_on: Date.current.to_s,
          setting_vote: 4
        }
      }
      # Should merge, not create a new vote
      expect(Vote.count).to eq(1)
      vote = Vote.last
      expect(vote.reset_vote).to eq(1)
      expect(vote.setting_vote).to eq(4)
    end

    it "creates VoteSummary after vote" do
      post votes_path, params: {
        vote: {
          shop_id: shop.id,
          machine_model_id: machine.id,
          voted_on: Date.current.to_s,
          reset_vote: 1,
          setting_vote: 3
        }
      }

      summary = VoteSummary.find_by(shop_id: shop.id, machine_model_id: machine.id, target_date: Date.current)
      expect(summary).to be_present
      expect(summary.total_votes).to eq(1)
    end

    it "allows vote without any vote type (creates empty vote record)" do
      expect {
        post votes_path, params: {
          vote: {
            shop_id: shop.id,
            machine_model_id: machine.id,
            voted_on: Date.current.to_s
          }
        }
      }.to change(Vote, :count).by(1)
    end

    it "rejects vote with invalid setting_vote" do
      expect {
        post votes_path, params: {
          vote: {
            shop_id: shop.id,
            machine_model_id: machine.id,
            voted_on: Date.current.to_s,
            setting_vote: 7
          }
        }
      }.not_to change(Vote, :count)
    end
  end
end
