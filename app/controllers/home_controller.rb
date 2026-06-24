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

    # 相棒ペット (cookie がある人だけ。新規訪問者には cookie を作らない)
    token = cookies[:voter_token]
    @pet = Pet.for(token) if token.present?

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

    # AI おすすめ店舗 (全国TOP5)
    @recommendations = RecommendationService.top_nationwide(limit: 5)

    # Play records count for pillar card
    @play_records_count = Rails.cache.fetch("home/play_records_count", expires_in: 10.minutes) { PlayRecord.count }

    # Personal data (voter label + play summary)
    token = voter_token
    if token.present?
      profile = VoterProfile.find_by(voter_token: token)
      @voter_label = profile&.display_name.presence || "ユーザー##{token.last(4)}"
      @voter_points = profile&.points || 0
      @voter_streak = profile&.current_streak || 0

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
