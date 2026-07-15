require "rails_helper"

RSpec.describe "Feedbacks", type: :request do
  def form_token(at = Time.current)
    Rails.application.message_verifier(:feedback_form).generate(at.to_i)
  end

  describe "GET /feedbacks/new" do
    it "renders the feedback form" do
      get new_feedback_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ご意見・ご要望")
    end
  end

  describe "POST /feedbacks" do
    it "creates a feedback with valid params" do
      expect {
        post feedbacks_path, params: {
          feedback: { body: "新機種を追加してほしい", category: "feature_request" },
          form_loaded_at: form_token(10.seconds.ago)
        }
      }.to change(Feedback, :count).by(1)

      expect(response).to redirect_to(new_feedback_path)
    end

    it "rejects feedback without body" do
      expect {
        post feedbacks_path, params: {
          feedback: { body: "", category: "feature_request" },
          form_loaded_at: form_token(10.seconds.ago)
        }
      }.not_to change(Feedback, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "silently drops submissions that fill the honeypot" do
      expect {
        post feedbacks_path, params: {
          feedback: { body: "List your site now https://spam.example", category: "other" },
          website: "http://spam.example.com",
          form_loaded_at: form_token(10.seconds.ago)
        }
      }.not_to change(Feedback, :count)

      # 成功時と同じ挙動（ボットに検知を悟らせない）
      expect(response).to redirect_to(new_feedback_path)
    end

    it "silently drops submissions sent faster than a human could fill" do
      expect {
        post feedbacks_path, params: {
          feedback: { body: "spam", category: "other" },
          form_loaded_at: form_token(Time.current)
        }
      }.not_to change(Feedback, :count)

      expect(response).to redirect_to(new_feedback_path)
    end

    it "silently drops submissions with a missing or tampered token" do
      expect {
        post feedbacks_path, params: {
          feedback: { body: "spam", category: "other" },
          form_loaded_at: "tampered"
        }
      }.not_to change(Feedback, :count)

      expect(response).to redirect_to(new_feedback_path)
    end
  end
end
