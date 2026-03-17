class HomeController < ApplicationController
  include TrendData

  def index
    desc = "パチスロの設定・リセット情報をみんなで記録して傾向をチェック。ログイン不要、匿名OK。"
    set_meta_tags title: "みんなの記録でパチスロの設定が見える",
                  description: desc,
                  keywords: "パチスロ, 設定, リセット, 記録, 設定判別, スロット",
                  og: { title: "ヨミスロ - みんなの記録でパチスロの設定が見える",
                        description: desc,
                        type: "website",
                        url: root_url },
                  twitter: { card: "summary" }

    @prefectures = Prefecture.left_joins(:shops).group(:id).select("prefectures.*, COUNT(shops.id) as shops_count").order(:id)

    # Stats for hero (cached to avoid full table scans on every request)
    @today_votes_count = Rails.cache.fetch("home/today_votes", expires_in: 5.minutes) { Vote.where(voted_on: Date.current).count }
    @total_votes_count = Rails.cache.fetch("home/total_votes", expires_in: 10.minutes) { Vote.count }
    @shops_count = Rails.cache.fetch("home/shops_count", expires_in: 1.hour) { Shop.count }
    @machines_count = Rails.cache.fetch("home/machines_count", expires_in: 1.hour) {
      MachineModel.active
        .joins(:shop_machine_models)
        .group("machine_models.id")
        .having("COUNT(shop_machine_models.id) >= 50")
        .count.size
    }

    # Weekly high-setting machines — setting 4-6 reports aggregated over the week
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
    if rows.any?
      machines_by_id = MachineModel.where(id: rows.map(&:first)).select(:id, :name, :slug).index_by(&:id)
      @weekly_high_setting_machines = rows.filter_map { |mid, high, total|
        machine = machines_by_id[mid]
        next unless machine
        pct = (high.to_f / total * 100).round
        { machine: machine, high_count: high.to_i, total_count: total.to_i, pct: pct }
      }
    else
      @weekly_high_setting_machines = []
    end

    # Weekly voter ranking — top 10 by vote count this week
    ranking_rows = Vote.where(voted_on: week_start..Date.current)
                       .group(:voter_token)
                       .order(Arel.sql("COUNT(*) DESC"))
                       .limit(10)
                       .pluck(Arel.sql("voter_token, COUNT(*) as vote_count"))
    if ranking_rows.any?
      profiles = VoterProfile.where(voter_token: ranking_rows.map(&:first))
                              .pluck(:voter_token, :display_name).to_h
      @weekly_ranking = ranking_rows.map.with_index(1) { |(token, count), rank|
        label = profiles[token].presence || "ユーザー##{token.last(4)}"
        { rank: rank, label: label, count: count }
      }
    else
      @weekly_ranking = []
    end

    # AI おすすめ店舗 (全国TOP5)
    @recommendations = RecommendationService.top_nationwide(limit: 5)

    # Play records count for pillar card
    @play_records_count = Rails.cache.fetch("home/play_records_count", expires_in: 10.minutes) { PlayRecord.count }

    # Personal play summary for mini card
    token = cookies[:voter_token]
    if token.present?
      agg = PlayRecord.where(voter_token: token, played_on: Date.current.beginning_of_month..Date.current)
                      .pick(
                        Arel.sql("SUM(result_amount)"),
                        Arel.sql("COUNT(DISTINCT played_on)"),
                        Arel.sql("COUNT(*) FILTER (WHERE result_amount > 0)"),
                        Arel.sql("COUNT(*) FILTER (WHERE result_amount < 0)")
                      )
      if agg&.first
        total, days, wins, losses = agg
        win_rate = (wins + losses) > 0 ? (wins.to_f / (wins + losses) * 100).round(0) : 0
        @my_play_summary = { total: total.to_i, days: days.to_i, win_rate: win_rate }
      end
    end
  end
end
