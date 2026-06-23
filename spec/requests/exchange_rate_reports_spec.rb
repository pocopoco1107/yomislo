require "rails_helper"

RSpec.describe "ExchangeRateReports", type: :request do
  let(:shop) { create(:shop) }

  describe "POST /exchange_rate_reports" do
    it "等価報告を作成できる(フォームの scope と controller の require が一致)" do
      expect {
        post exchange_rate_reports_path, params: {
          exchange_rate_report: {
            shop_id: shop.id,
            denomination: "twenty_yen",
            rate_key: "touka"
          }
        }
      }.to change(ExchangeRateReport, :count).by(1)

      report = ExchangeRateReport.last
      expect(report.shop_id).to eq(shop.id)
      expect(report.rate_key).to eq("touka")
    end

    it "自由入力(数値)の交換率を作成できる" do
      expect {
        post exchange_rate_reports_path, params: {
          exchange_rate_report: {
            shop_id: shop.id,
            denomination: "twenty_yen",
            rate_key: "18.0"
          }
        }
      }.to change(ExchangeRateReport, :count).by(1)

      expect(ExchangeRateReport.last.rate_key).to eq("18.0")
    end

    it "同じ内容を再送すると報告が取り消される(トグル)" do
      cookies[:voter_token] = "toggle_token"
      post exchange_rate_reports_path, params: {
        exchange_rate_report: { shop_id: shop.id, denomination: "twenty_yen", rate_key: "touka" }
      }
      expect(ExchangeRateReport.count).to eq(1)

      expect {
        post exchange_rate_reports_path, params: {
          exchange_rate_report: { shop_id: shop.id, denomination: "twenty_yen", rate_key: "touka" }
        }
      }.to change(ExchangeRateReport, :count).by(-1)
    end
  end
end
