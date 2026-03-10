class HomeController < ApplicationController
  include TrendData

  def index
    desc = "パチスロの設定・リセット情報をみんなの投票で集める。店舗×機種×日付で設定予想を共有するサイト。"
    set_meta_tags title: "パチスロ設定・リセット投票",
                  description: desc,
                  keywords: "パチスロ, 設定, リセット, 投票, 設定判別, スロット",
                  og: { title: "スロリセnavi - パチスロ設定・リセット投票",
                        description: desc,
                        type: "website",
                        url: root_url },
                  twitter: { card: "summary" }

    @prefectures = Prefecture.left_joins(:shops).group(:id).select("prefectures.*, COUNT(shops.id) as shops_count").order(:id)

    # Stats for hero
    @today_votes_count = Vote.where(voted_on: Date.current).count
    @total_votes_count = Vote.count
    @shops_count = Shop.count
    # 50店舗以上に設置されている全国的な現行機種のみカウント
    @machines_count = MachineModel.active
      .joins(:shop_machine_models)
      .group("machine_models.id")
      .having("COUNT(shop_machine_models.id) >= 50")
      .count.size

    # Today's hot shops — single query with JOIN to avoid N+1
    hot_shop_rows = VoteSummary.where(target_date: Date.current)
                               .group(:shop_id)
                               .select("shop_id, SUM(total_votes) as vote_total")
                               .order("vote_total DESC")
                               .limit(5)
    hot_shop_ids = hot_shop_rows.map(&:shop_id)
    hot_shops_by_id = Shop.where(id: hot_shop_ids).index_by(&:id)
    @hot_shops = hot_shop_rows.filter_map { |vs|
      shop = hot_shops_by_id[vs.shop_id]
      next unless shop
      { shop: shop, votes: vs.vote_total }
    }

    # High reset rate machines — limit candidate rows in SQL, then pick top 5
    reset_rows = VoteSummary.where(target_date: Date.current)
                            .where("reset_yes_count + reset_no_count >= 3")
                            .select("id, machine_model_id, shop_id, reset_yes_count, reset_no_count")
                            .order(Arel.sql("reset_yes_count::float / NULLIF(reset_yes_count + reset_no_count, 0) DESC"))
                            .limit(20)
                            .to_a
    if reset_rows.any?
      machine_ids = reset_rows.map(&:machine_model_id).uniq
      shop_ids = reset_rows.map(&:shop_id).uniq
      machines_by_id = MachineModel.where(id: machine_ids).select(:id, :name, :slug).index_by(&:id)
      shops_by_id = Shop.where(id: shop_ids).select(:id, :name, :slug, :prefecture_id).index_by(&:id)

      @high_reset_machines = reset_rows
        .first(5)
        .filter_map { |vs|
          machine = machines_by_id[vs.machine_model_id]
          shop = shops_by_id[vs.shop_id]
          next unless machine && shop
          { machine: machine, shop: shop, rate: vs.reset_rate }
        }
    else
      @high_reset_machines = []
    end

    # Weekly voter ranking — top 10 by vote count this week
    week_start = Date.current.beginning_of_week
    @weekly_ranking = Vote.where(voted_on: week_start..Date.current)
                          .group(:voter_token)
                          .order(Arel.sql("COUNT(*) DESC"))
                          .limit(10)
                          .pluck(Arel.sql("voter_token, COUNT(*) as vote_count"))
                          .map.with_index(1) { |(token, count), rank|
                            { rank: rank, label: "投票者##{token.last(4)}", count: count }
                          }

    # 7-day nationwide trend (scoped to last 7 days to avoid full table scan)
    @trend_data = build_trend_data(VoteSummary.where(target_date: 6.days.ago.to_date..Date.current))

    # AI おすすめ店舗 (全国TOP5)
    @recommendations = RecommendationService.top_nationwide(limit: 5)

    @recent_shops = Shop.includes(:prefecture).order(updated_at: :desc).limit(10)

    if params[:q].present?
      @search_results = Shop.search_by_name(params[:q]).includes(:prefecture).limit(20)
    end
  end
end
