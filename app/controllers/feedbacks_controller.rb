class FeedbacksController < ApplicationController
  def new
    set_meta_tags noindex: true
    @feedback = Feedback.new
  end

  def create
    @feedback = Feedback.new(feedback_params)
    @feedback.voter_token = voter_token

    if @feedback.save
      redirect_to new_feedback_path, notice: "ご意見ありがとうございます！確認次第対応いたします。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def feedback_params
    params.require(:feedback).permit(:name, :email, :category, :body)
  end
end
