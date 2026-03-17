require "rails_helper"

RSpec.describe "Rack::Attack", type: :request do
  # Rack::Attack needs a real cache store to track throttle counts.
  # Rails test env uses :null_store by default, so we swap in memory_store.
  let(:memory_store) { ActiveSupport::Cache::MemoryStore.new }

  before do
    Rack::Attack.cache.store = memory_store
  end

  after do
    Rack::Attack.cache.store = Rails.cache
  end

  describe "req/ip throttle (60/min)" do
    it "allows requests under the limit" do
      get root_path
      expect(response).to have_http_status(:ok)
    end

    it "throttles after 60 requests per minute" do
      61.times { get root_path }
      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("リクエスト制限")
    end
  end

  describe "votes/ip throttle (50/day)" do
    let(:shop) { create(:shop) }
    let(:machine) { create(:machine_model) }

    it "allows vote POST requests under the limit" do
      post votes_path, params: {
        vote: {
          shop_id: shop.id,
          machine_model_id: machine.id,
          voted_on: Date.current.to_s,
          reset_vote: 1
        }
      }
      expect(response.status).not_to eq(429)
    end

    it "throttles vote POST requests after 50 per day" do
      51.times do
        post votes_path, params: {
          vote: {
            shop_id: shop.id,
            machine_model_id: machine.id,
            voted_on: Date.current.to_s,
            reset_vote: 1
          }
        }
      end
      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("リクエスト制限")
    end
  end

  describe "throttled response format" do
    it "includes Retry-After header" do
      61.times { get root_path }
      expect(response.headers["Retry-After"]).to be_present
    end

    it "returns expected content type" do
      61.times { get root_path }
      expect(response.content_type).to be_present
    end

    it "returns Japanese error message" do
      61.times { get root_path }
      expect(response.body).to include("リクエスト制限に達しました")
    end
  end
end
