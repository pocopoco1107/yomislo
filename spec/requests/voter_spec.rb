require "rails_helper"

RSpec.describe "Voter", type: :request do
  describe "GET /voter/status" do
    it "renders without voter_token cookie" do
      get voter_status_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("まずは1件、記録してみよう")
    end

    it "renders with voter_token but no votes" do
      get voter_status_path, headers: { "Cookie" => "voter_token=abc123def456" }
      # Token exists but no votes — still shows the status page
      expect(response).to have_http_status(:ok)
    end

    context "with votes" do
      let(:shop) { create(:shop) }
      let(:machine) { create(:machine_model) }
      let(:token) { "test_voter_token_1234" }

      before do
        ShopMachineModel.create!(shop: shop, machine_model: machine)
        create(:vote, shop: shop, machine_model: machine, voter_token: token, voted_on: Date.current, reset_vote: 1)
      end

      it "displays vote statistics" do
        get voter_status_path, headers: { "Cookie" => "voter_token=#{token}" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("ユーザー#1234")
        expect(response.body).to include("スコア") # 「▶ スコア」窓
        expect(response.body).to include("収支記録")
      end

      it "displays recent vote history with shop name" do
        get voter_status_path, headers: { "Cookie" => "voter_token=#{token}" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(shop.name)
        expect(response.body).to include(machine.name)
      end

      it "renders the companion pet card" do
        get voter_status_path, headers: { "Cookie" => "voter_token=#{token}" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("companions/")
      end
    end
  end

  describe "POST /voter/restore" do
    it "sets cookie with valid token" do
      shop = create(:shop)
      machine = create(:machine_model)
      create(:vote, voter_token: "valid_restore_token", shop: shop, machine_model: machine)

      post restore_voter_token_path, params: { token: "valid_restore_token" }
      expect(response).to redirect_to(voter_status_path)
      expect(flash[:notice]).to include("復元")
    end

    it "shows error with invalid token" do
      post restore_voter_token_path, params: { token: "nonexistent_token" }
      expect(response).to redirect_to(voter_status_path)
      expect(flash[:alert]).to be_present
    end

    it "shows error with blank token" do
      post restore_voter_token_path, params: { token: "" }
      expect(response).to redirect_to(voter_status_path)
      expect(flash[:alert]).to be_present
    end

    it "shows error when token param is missing" do
      post restore_voter_token_path
      expect(response).to redirect_to(voter_status_path)
      expect(flash[:alert]).to be_present
    end

    it "overwrites existing voter_token cookie when restoring a valid token" do
      shop = create(:shop)
      machine = create(:machine_model)
      create(:vote, voter_token: "new_restore_token", shop: shop, machine_model: machine)

      # Set an existing cookie first
      cookies[:voter_token] = "old_existing_token"

      post restore_voter_token_path, params: { token: "new_restore_token" }
      expect(response).to redirect_to(voter_status_path)
      expect(flash[:notice]).to include("復元")
      # restore は cookies.signed で書き込む。Rack::Test の cookie jar には signed アクセサが
      # 無いため、後続リクエストで voter_status ページが「new_restore_token」の投票主とみなすかで検証。
      get voter_status_path
      expect(response.body).to include("ユーザー#" + "new_restore_token".last(4))
    end

    it "trims whitespace from token before lookup" do
      shop = create(:shop)
      machine = create(:machine_model)
      create(:vote, voter_token: "token_with_spaces", shop: shop, machine_model: machine)

      post restore_voter_token_path, params: { token: "  token_with_spaces  " }
      expect(response).to redirect_to(voter_status_path)
      expect(flash[:notice]).to include("復元")
    end
  end
end
