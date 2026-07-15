class FeedbacksController < ApplicationController
  # フォーム描画から送信までがこの秒数未満ならボットとみなす
  MIN_FILL_SECONDS = 3

  def new
    set_meta_tags title: "ご意見・不具合報告", noindex: true
    @feedback = Feedback.new
    @form_token = feedback_form_token
  end

  def create
    if spam_submission?
      Rails.logger.info("[feedback] spam blocked from #{request.remote_ip}")
      # ボットに検知の有無を悟らせないため、成功時と同じ挙動を返しつつ保存しない
      redirect_to new_feedback_path, notice: feedback_success_notice
      return
    end

    @feedback = Feedback.new(feedback_params)
    @feedback.voter_token = voter_token

    if @feedback.save
      VoterProfile.refresh_for(voter_token) if VoterProfile.exists?(voter_token: voter_token)
      redirect_to new_feedback_path, notice: feedback_success_notice
    else
      @form_token = feedback_form_token
      render :new, status: :unprocessable_entity
    end
  end

  private

  def feedback_params
    params.require(:feedback).permit(:name, :email, :category, :body)
  end

  def feedback_success_notice
    "ありがとう！ちゃんと見てます (+#{VoterProfile::POINT_RULES[:feedback]}ゴールド)"
  end

  # --- スパム対策（honeypot + 送信タイミング） ---

  def spam_submission?
    honeypot_tripped? || submitted_too_fast?
  end

  # 人間には見えない website フィールド。ボットが埋めたら弾く
  def honeypot_tripped?
    params[:website].present?
  end

  # フォーム描画から送信までが速すぎる、またはトークンが欠落/改竄されていればボットとみなす
  def submitted_too_fast?
    loaded_at = decode_form_token(params[:form_loaded_at])
    return true if loaded_at.nil?

    Time.current - loaded_at < MIN_FILL_SECONDS
  end

  def feedback_form_token
    feedback_form_verifier.generate(Time.current.to_i)
  end

  def decode_form_token(token)
    return nil if token.blank?

    Time.zone.at(feedback_form_verifier.verify(token))
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def feedback_form_verifier
    Rails.application.message_verifier(:feedback_form)
  end
end
