class FeedbacksController < ApplicationController
  def new
    set_meta_tags noindex: true
    @feedback = Feedback.new
  end

  def create
    @feedback = Feedback.new(feedback_params)
    @feedback.voter_token = voter_token

    if @feedback.save
      VoterProfile.refresh_for(voter_token) if VoterProfile.exists?(voter_token: voter_token)
      redirect_to new_feedback_path, notice: "ありがとう！ちゃんと見てます (+#{VoterProfile::POINT_RULES[:feedback]}ゴールド)"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def feedback_params
    params.require(:feedback).permit(:name, :email, :category, :body)
  end
end
