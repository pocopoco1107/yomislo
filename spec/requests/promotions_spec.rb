require "rails_helper"

RSpec.describe "Promotions", type: :request do
  describe "GET /p/:id (click)" do
    let!(:promo) { create(:promotion, target_url: "https://asp.example.com/track?id=42", clicks_count: 0, active: true) }

    it "アクティブな案件は clicks_count を加算し外部URLへ302する" do
      expect {
        get promotion_click_path(promo)
      }.to change { promo.reload.clicks_count }.by(1)

      expect(response).to redirect_to("https://asp.example.com/track?id=42")
      expect(response.status).to eq(302)
    end

    it "inactive な案件はカウント加算せずルートにリダイレクト" do
      promo.update!(active: false)

      expect {
        get promotion_click_path(promo)
      }.not_to change { promo.reload.clicks_count }

      expect(response).to redirect_to(root_path)
    end

    it "target_url が '#' プレースホルダーならカウント加算せずルートにリダイレクト" do
      promo.update_columns(target_url: "#")

      expect {
        get promotion_click_path(promo)
      }.not_to change { promo.reload.clicks_count }

      expect(response).to redirect_to(root_path)
    end

    it "存在しない id はルートにリダイレクト" do
      get promotion_click_path(id: 999_999)
      expect(response).to redirect_to(root_path)
    end
  end
end
