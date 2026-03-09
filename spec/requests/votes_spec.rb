require "rails_helper"

RSpec.describe "Votes", type: :request do
  let(:shop) { create(:shop) }
  let(:machine) { create(:machine_model) }

  describe "POST /votes" do
    it "creates a vote with cookie-based voter_token" do
      cookies[:voter_token] = "test_token_123"
      expect {
        post votes_path, params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: Date.current, reset_vote: 1 } }
      }.to change(Vote, :count).by(1)

      vote = Vote.last
      expect(vote.voter_token).to eq("test_token_123")
    end

    it "assigns a voter_token automatically if none exists" do
      expect {
        post votes_path, params: { vote: { shop_id: shop.id, machine_model_id: machine.id, voted_on: Date.current, reset_vote: 1 } }
      }.to change(Vote, :count).by(1)

      expect(Vote.last.voter_token).to be_present
    end
  end
end
