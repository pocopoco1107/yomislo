class VotesController < ApplicationController
  def create
    @vote = Vote.find_or_initialize_by(
      voter_token: voter_token,
      shop_id: vote_params[:shop_id],
      machine_model_id: vote_params[:machine_model_id],
      voted_on: vote_params[:voted_on]
    )
    # Only update the vote type that was submitted (don't overwrite the other)
    merge_params = { voter_token: voter_token }
    merge_params[:reset_vote] = vote_params[:reset_vote] if vote_params.key?(:reset_vote)
    merge_params[:setting_vote] = vote_params[:setting_vote] if vote_params.key?(:setting_vote)
    if vote_params.key?(:confirmed_setting)
      # Toggle: if tag already exists, remove it; otherwise add it
      tag = vote_params[:confirmed_setting]
      current_tags = @vote.confirmed_setting || []
      if current_tags.include?(tag)
        merge_params[:confirmed_setting] = current_tags - [tag]
      else
        merge_params[:confirmed_setting] = current_tags + [tag]
      end
    end
    @vote.assign_attributes(vote_params.slice(:shop_id, :machine_model_id, :voted_on).merge(merge_params))

    if @vote.save
      @shop = @vote.shop
      @machine_model = @vote.machine_model
      @vote_summary = @vote.cached_vote_summary
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to shop_path(@shop) }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("vote_errors", partial: "votes/errors", locals: { vote: @vote }) }
        format.html {
          shop = Shop.find_by(id: vote_params[:shop_id])
          redirect_to(shop ? shop_path(shop) : root_path, alert: @vote.errors.full_messages.join(", "))
        }
      end
    end
  end

  def update
    @vote = Vote.find_by!(id: params[:id], voter_token: voter_token)
    if @vote.update(vote_params)
      @shop = @vote.shop
      @machine_model = @vote.machine_model
      @vote_summary = @vote.cached_vote_summary
      respond_to do |format|
        format.turbo_stream { render :create }
        format.html { redirect_to shop_path(@shop) }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("vote_errors", partial: "votes/errors", locals: { vote: @vote }) }
        format.html { redirect_to shop_path(@vote.shop), alert: @vote.errors.full_messages.join(", ") }
      end
    end
  end

  private

  def vote_params
    params.require(:vote).permit(:shop_id, :machine_model_id, :voted_on, :reset_vote, :setting_vote, :confirmed_setting)
  end
end
