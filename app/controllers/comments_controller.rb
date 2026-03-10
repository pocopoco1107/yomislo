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

  ALLOWED_COMMENTABLE_TYPES = %w[Shop].freeze

  def comment_params
    permitted = params.require(:comment).permit(:commentable_type, :commentable_id, :body, :target_date, :commenter_name)
    unless ALLOWED_COMMENTABLE_TYPES.include?(permitted[:commentable_type])
      raise ActionController::BadRequest, "Invalid commentable_type"
    end
    permitted
  end
end
