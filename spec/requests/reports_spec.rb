require "rails_helper"

RSpec.describe "Reports", type: :request do
  describe "POST /reports" do
    let(:comment) { create(:comment) }

    let(:valid_params) do
      {
        report: {
          reportable_type: "Comment",
          reportable_id: comment.id,
          reason: "spam"
        }
      }
    end

    it "creates a report with valid params" do
      expect {
        post reports_path, params: valid_params
      }.to change(Report, :count).by(1)
    end

    it "assigns voter_token from cookie" do
      cookies[:voter_token] = "report_test_token"
      post reports_path, params: valid_params
      expect(Report.last.voter_token).to eq("report_test_token")
    end

    it "rejects invalid reportable_type" do
      params = valid_params.deep_dup
      params[:report][:reportable_type] = "User"
      post reports_path, params: params
      expect(response).to have_http_status(:bad_request)
    end

    it "allows reporting a ShopReview" do
      review = create(:shop_review)
      expect {
        post reports_path, params: {
          report: { reportable_type: "ShopReview", reportable_id: review.id, reason: "spam" }
        }
      }.to change(Report, :count).by(1)
    end

    it "responds with turbo_stream when requested" do
      post reports_path, params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("通報を受け付けました")
    end

    it "turbo_stream の成功メッセージが HTML エスケープされず実要素として出力される" do
      post reports_path, params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      # <template> 内に実際の <div> が入る（&lt;div&gt; ではない）
      expect(response.body).to include(%(<div id="report_flash_Comment_#{comment.id}"))
      expect(response.body).not_to include("&lt;div")
    end

    it "通報対象ごとに一意な report_flash id を対象にする（複数コメントでの id 重複回避）" do
      post reports_path, params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      # 汎用の report_flash ではなく対象固有の id を置換する
      expect(response.body).to include(%(target="report_flash_Comment_#{comment.id}"))
      expect(response.body).not_to include(%(target="report_flash"))
    end
  end
end
