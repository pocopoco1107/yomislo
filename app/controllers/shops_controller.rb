class ShopsController < ApplicationController
  include TrendData

  def show
    @shop = Shop.includes(:prefecture).find_by!(slug: params[:slug])
    @date = Date.current
    load_shop_data
  end

  def show_date
    @shop = Shop.includes(:prefecture).find_by!(slug: params[:slug])
    begin
      @date = Date.parse(params[:date])
    rescue Date::Error
      redirect_to shop_path(@shop), alert: "無効な日付です" and return
    end
    load_shop_data
    render :show
  end

  def favorites
    slugs = (params[:slugs] || "").split(",").first(20)
    @shops = Shop.where(slug: slugs).includes(:prefecture)
    render partial: "shops/favorites_list", locals: { shops: @shops }, layout: false
  end

  private

  def load_shop_data
    desc = "#{@shop.name}（#{@shop.prefecture.name}）のパチスロ設定・リセット投票。機種ごとの設定予想をチェック。"
    set_meta_tags title: "#{@shop.name} - 設定・リセット投票",
                  description: desc,
                  keywords: "#{@shop.name}, #{@shop.prefecture.name}, パチスロ, 設定, リセット",
                  og: { title: "#{@shop.name} - 設定・リセット投票 | スロリセnavi",
                        description: desc,
                        type: "website",
                        url: request.original_url.split("?").first },
                  twitter: { card: "summary" }

    # Show machines registered to this shop (join table) + machines with votes today
    registered_ids = @shop.shop_machine_models.pluck(:machine_model_id)
    voted_ids = Vote.where(shop_id: @shop.id, voted_on: @date)
                    .distinct.pluck(:machine_model_id)
    machine_ids = (registered_ids + voted_ids).uniq

    @machine_models = MachineModel.where(id: machine_ids).order(:name).to_a
                        .sort_by { |m| [m.display_type_sort, m.name] }

    # ShopMachineModel台数マップ (machine_model_id => unit_count)
    @unit_counts = ShopMachineModel.where(shop_id: @shop.id, machine_model_id: machine_ids)
                                    .where.not(unit_count: nil)
                                    .pluck(:machine_model_id, :unit_count)
                                    .to_h

    @vote_summaries = @shop.vote_summaries
                           .where(target_date: @date)
                           .index_by(&:machine_model_id)
    @user_votes = Vote.where(voter_token: voter_token, shop_id: @shop.id, voted_on: @date)
                      .index_by(&:machine_model_id)
    @comments = @shop.comments.for_date(@date).includes(:user).recent.limit(50)

    # Reviews (limit to recent 20 for display, average across all)
    @reviews = @shop.shop_reviews.recent.limit(20)
    @average_rating = ShopReview.average_rating_for(@shop.id)
    @existing_review = @shop.shop_reviews.find_by(voter_token: voter_token)

    # 同じ県・同レートの店舗（最大5件）
    if @shop.slot_rates.present?
      @same_rate_shops = Shop.where(prefecture_id: @shop.prefecture_id)
                              .where.not(id: @shop.id)
                              .where("slot_rates && ARRAY[?]::varchar[]", @shop.slot_rates)
                              .order(:name)
                              .limit(5)
    else
      @same_rate_shops = []
    end

    # 7-day trend data
    @trend_data = build_trend_data(@shop.vote_summaries)
  end
end
