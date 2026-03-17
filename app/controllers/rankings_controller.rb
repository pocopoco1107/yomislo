class RankingsController < ApplicationController
  def index
    set_meta_tags title: "記録ランキング"

    @period = params[:period].presence || "weekly"
    @period = "weekly" unless %w[weekly monthly all_time].include?(@period)

    @scope = params[:scope].presence || "national"
    @prefecture_id = params[:prefecture_id]

    scope_type = case @scope
    when "prefecture" then "prefecture"
    else "national"
    end
    scope_id = @scope == "prefecture" ? @prefecture_id : nil

    period_key = case @period
    when "weekly" then Date.current.strftime("%G-W%V")
    when "monthly" then Date.current.strftime("%Y-%m")
    else "all"
    end

    @rankings = VoterRanking.where(
      period_type: @period,
      period_key: period_key,
      scope_type: scope_type,
      scope_id: scope_id
    ).order(:rank_position).limit(50)

    # Current user's rank
    token = cookies[:voter_token]
    if token.present?
      @my_rank = VoterRanking.find_by(
        voter_token: token,
        period_type: @period,
        period_key: period_key,
        scope_type: scope_type,
        scope_id: scope_id
      )
    end

    @prefectures = Prefecture.order(:id) if @scope == "prefecture"
  end
end
