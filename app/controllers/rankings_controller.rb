class RankingsController < ApplicationController
  def index
    set_meta_tags title: "パチスロ設定記録ランキング",
                  description: "パチスロの設定記録数ランキング。週間・月間・累計で全国/都道府県別の記録ランカーをチェック。",
                  keywords: "パチスロ, ランキング, 設定記録, 週間, 月間, 全国"

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
    token = voter_token
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

    # --- オマケ要素: ポイント / 今週の高設定 (ホームから移設) ---
    # ポイントランキング (累計ポイント上位10)
    top_profiles = VoterProfile.where("points > 0")
                               .order(points: :desc)
                               .limit(10)
                               .pluck(:voter_token, :display_name, :points)
    @points_ranking = top_profiles.map.with_index(1) { |(token, name, pts), rank|
      label = name.presence || "ユーザー##{token.last(4)}"
      { rank: rank, label: label, points: pts }
    }

    # 今週の高設定ランキング (設定4-6記録を週内集計)
    week_start = Date.current.beginning_of_week
    high_setting_sql = <<~SQL.squish
      COALESCE(SUM((setting_distribution->>'4')::int), 0) +
      COALESCE(SUM((setting_distribution->>'5')::int), 0) +
      COALESCE(SUM((setting_distribution->>'6')::int), 0)
    SQL
    total_setting_sql = <<~SQL.squish
      COALESCE(SUM((setting_distribution->>'1')::int), 0) +
      COALESCE(SUM((setting_distribution->>'2')::int), 0) +
      COALESCE(SUM((setting_distribution->>'3')::int), 0) +
      COALESCE(SUM((setting_distribution->>'4')::int), 0) +
      COALESCE(SUM((setting_distribution->>'5')::int), 0) +
      COALESCE(SUM((setting_distribution->>'6')::int), 0)
    SQL
    rows = VoteSummary.where(target_date: week_start..Date.current)
                      .group(:machine_model_id)
                      .having("#{total_setting_sql} >= 5")
                      .order(Arel.sql("#{high_setting_sql} DESC"))
                      .limit(5)
                      .pluck(Arel.sql("machine_model_id"), Arel.sql(high_setting_sql), Arel.sql(total_setting_sql))
    @weekly_high_setting_machines =
      if rows.any?
        machines_by_id = MachineModel.where(id: rows.map(&:first)).select(:id, :name, :slug).index_by(&:id)
        rows.filter_map { |mid, high, total|
          machine = machines_by_id[mid]
          next unless machine
          pct = (high.to_f / total * 100).round
          { machine: machine, high_count: high.to_i, total_count: total.to_i, pct: pct }
        }
      else
        []
      end
  end
end
