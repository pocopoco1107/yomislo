require "rails_helper"

RSpec.describe "Votes (extended)", type: :request do
  let(:shop) { create(:shop) }
  let(:machine) { create(:machine_model) }
  let(:today) { Date.current }

  describe "POST /votes — merge behavior" do
    it "creates a new vote with reset_vote only" do
      cookies[:voter_token] = "merge_test"
      post votes_path, params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: today, reset_vote: 1 } }
      vote = Vote.find_by(voter_token: "merge_test")
      expect(vote.reset_vote).to eq(1)
      expect(vote.setting_vote).to be_nil
    end

    it "merges setting_vote into existing vote without overwriting reset_vote" do
      cookies[:voter_token] = "merge_test"
      post votes_path, params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: today, reset_vote: 1 } }
      post votes_path, params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: today, setting_vote: 5 } }

      vote = Vote.find_by(voter_token: "merge_test", shop_id: shop.id, machine_model_id: machine.id)
      expect(vote.reset_vote).to eq(1)
      expect(vote.setting_vote).to eq(5)
    end

    it "toggles confirmed_setting tag on" do
      cookies[:voter_token] = "toggle_test"
      post votes_path, params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: today, confirmed_setting: "6確" } }

      vote = Vote.find_by(voter_token: "toggle_test")
      expect(vote.confirmed_setting).to include("6確")
    end

    it "toggles confirmed_setting tag off when already present" do
      cookies[:voter_token] = "toggle_off"
      # First: add tag with reset_vote so vote remains valid after toggle
      post votes_path, params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: today, reset_vote: 1, confirmed_setting: "6確" } }
      # Second: toggle off
      post votes_path, params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: today, confirmed_setting: "6確" } }

      vote = Vote.find_by(voter_token: "toggle_off")
      expect(vote.confirmed_setting).not_to include("6確")
    end
  end

  describe "POST /votes — Turbo Stream response" do
    it "responds with turbo_stream format" do
      cookies[:voter_token] = "turbo_test"
      post votes_path,
           params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: today, reset_vote: 1 } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    end

    it "responds with redirect on HTML format" do
      cookies[:voter_token] = "html_test"
      post votes_path, params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: today, reset_vote: 1 } }
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "POST /votes — VoteSummary auto-update" do
    it "creates VoteSummary automatically after vote" do
      cookies[:voter_token] = "summary_test"
      expect {
        post votes_path, params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: today, reset_vote: 1 } }
      }.to change(VoteSummary, :count).by(1)

      summary = VoteSummary.find_by(shop_id: shop.id, machine_model_id: machine.id, target_date: today)
      expect(summary.total_votes).to eq(1)
      expect(summary.reset_yes_count).to eq(1)
    end

    it "updates VoteSummary when vote is merged" do
      cookies[:voter_token] = "summary_merge"
      post votes_path, params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: today, reset_vote: 1 } }
      post votes_path, params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: today, setting_vote: 4 } }

      summary = VoteSummary.find_by(shop_id: shop.id, machine_model_id: machine.id, target_date: today)
      expect(summary.total_votes).to eq(1)
      expect(summary.setting_avg).to eq(4.0)
    end
  end

  describe "POST /votes — validation errors" do
    it "allows vote with no vote type" do
      cookies[:voter_token] = "error_test"
      post votes_path, params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: today } }
      expect(Vote.count).to eq(1)
    end

    it "rejects future date" do
      cookies[:voter_token] = "future_test"
      post votes_path, params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: Date.tomorrow, reset_vote: 1 } }
      expect(Vote.count).to eq(0)
    end
  end

  describe "PATCH /votes/:id" do
    it "updates an existing vote" do
      cookies[:voter_token] = "update_test"
      post votes_path, params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: today, setting_vote: 3 } }
      vote = Vote.find_by(voter_token: "update_test")

      patch vote_path(vote), params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: today, setting_vote: 6 } }
      vote.reload
      expect(vote.setting_vote).to eq(6)
    end

    it "rejects update from different voter_token" do
      cookies[:voter_token] = "owner_token"
      post votes_path, params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: today, reset_vote: 1 } }
      vote = Vote.find_by(voter_token: "owner_token")

      cookies[:voter_token] = "other_token"
      patch vote_path(vote), params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: today, reset_vote: 0 } }
      expect(response).to have_http_status(:not_found)
    end

    it "confirmed_setting に scalar が来ても配列カラムを空に潰さず正規化する" do
      cookies[:voter_token] = "confirm_update"
      post votes_path, params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: today, confirmed_setting: "6確" } }
      vote = Vote.find_by(voter_token: "confirm_update")
      expect(vote.confirmed_setting).to eq([ "6確" ])

      # update に scalar を渡しても [] に潰れず、配列として保存される
      patch vote_path(vote), params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: today, confirmed_setting: "偶数確" } }
      vote.reload
      expect(vote.confirmed_setting).to eq([ "偶数確" ])
    end
  end
end
