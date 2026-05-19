require "rails_helper"

RSpec.describe "Pages (Legal / About)", type: :request do
  describe "GET /privacy" do
    it "renders the privacy policy" do
      get "/privacy"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("プライバシーポリシー")
      expect(response.body).to include("voter_token")
    end
  end

  describe "GET /terms" do
    it "renders the terms of service" do
      get "/terms"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("利用規約")
      expect(response.body).to include("禁止事項")
    end
  end

  describe "GET /legal/tokushou" do
    it "renders the tokutei shouhou page" do
      get "/legal/tokushou"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("特定商取引法に基づく表記")
    end
  end

  describe "GET /about" do
    it "renders the about page" do
      get "/about"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ヨミスロについて")
    end
  end

  describe "footer links" do
    it "includes legal links on the home page" do
      get root_path
      expect(response.body).to include("プライバシーポリシー")
      expect(response.body).to include("利用規約")
      expect(response.body).to include("特定商取引法に基づく表記")
      expect(response.body).to include("ヨミスロについて")
    end
  end
end
