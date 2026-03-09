class CommentsController < ApplicationController
  def create
    @comment = Comment.new(comment_params)
    @comment.voter_token = voter_token
    if @comment.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: root_path }
      end
    else
      redirect_back fallback_location: root_path, alert: @comment.errors.full_messages.join(", ")
    end
  end

  private

  def comment_params
    params.require(:comment).permit(:commentable_type, :commentable_id, :body, :target_date, :commenter_name)
  end
end
