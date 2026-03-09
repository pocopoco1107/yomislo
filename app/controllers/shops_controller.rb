class ShopsController < ApplicationController
  def show
    @shop = Shop.find_by!(slug: params[:slug])
    @date = Date.current
    load_shop_data
  end

  def show_date
    @shop = Shop.find_by!(slug: params[:slug])
    @date = Date.parse(params[:date])
    load_shop_data
    render :show
  end

  private

  def load_shop_data
    set_meta_tags title: "#{@shop.name} - 設定・リセット投票",
                  description: "#{@shop.name}（#{@shop.prefecture.name}）のパチスロ設定・リセット投票。機種ごとの設定予想をチェック。",
                  keywords: "#{@shop.name}, #{@shop.prefecture.name}, パチスロ, 設定, リセット"
    @machine_models = MachineModel.order(:name)
    @vote_summaries = @shop.vote_summaries
                           .where(target_date: @date)
                           .includes(:machine_model)
                           .index_by(&:machine_model_id)
    @user_votes = Vote.where(voter_token: voter_token, shop_id: @shop.id, voted_on: @date)
                      .index_by(&:machine_model_id)
    @comments = @shop.comments.for_date(@date).includes(:user).recent
  end
end
