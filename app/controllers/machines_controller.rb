class MachinesController < ApplicationController
  include TrendData

  def show
    @machine_model = MachineModel.find_by!(slug: params[:slug])
    @installed_shop_count = @machine_model.shop_machine_models.count
    title_parts = [ @machine_model.name ]
    title_parts << "天井" if @machine_model.ceiling_info.present?
    title_parts << "設定判別"
    title_parts << "リセット恩恵" if @machine_model.reset_info.present?
    seo_title = title_parts.join(" | ")

    meta_desc_parts = [ "#{@machine_model.name}の天井・リセット恩恵・設定判別情報" ]
    meta_desc_parts << "機械割#{@machine_model.payout_rate_display}" if @machine_model.payout_rate_display
    meta_desc_parts << @machine_model.type_detail if @machine_model.type_detail.present?
    meta_desc_parts << "全国#{@installed_shop_count}店舗の設定記録データで高設定傾向をチェック" if @installed_shop_count > 0
    meta_desc = meta_desc_parts.join("。") + "。"

    seo_keywords = [ @machine_model.name, "天井", "設定判別", "リセット恩恵", "期待値",
                     "パチスロ", @machine_model.maker, @machine_model.generation_label ].compact_blank.join(", ")
    set_meta_tags title: seo_title,
                  description: meta_desc,
                  keywords: seo_keywords,
                  og: { title: "#{seo_title} | ヨミスロ",
                        description: meta_desc,
                        type: "website",
                        url: request.original_url.split("?").first,
                        image: @machine_model.image_url.presence },
                  twitter: { card: "summary" }
    @vote_summaries = @machine_model.vote_summaries
                                     .where(target_date: Date.current)
                                     .includes(:shop)
                                     .order(total_votes: :desc)
                                     .page(params[:page]).per(20)
    @guide_links = @machine_model.machine_guide_links.approved.recent

    # 全期間の統計 — single aggregate query instead of 5+ separate queries
    all_stats = @machine_model.vote_summaries
                  .pick(
                    Arel.sql("COUNT(DISTINCT target_date)"),
                    Arel.sql("COALESCE(SUM(total_votes), 0)"),
                    Arel.sql("COALESCE(SUM(reset_yes_count), 0)"),
                    Arel.sql("COALESCE(SUM(reset_no_count), 0)"),
                    Arel.sql("COALESCE(SUM(CASE WHEN total_votes > 0 AND setting_avg IS NOT NULL THEN setting_avg * total_votes ELSE 0 END), 0)"),
                    Arel.sql("COALESCE(SUM(CASE WHEN total_votes > 0 AND setting_avg IS NOT NULL THEN total_votes ELSE 0 END), 0)")
                  )
    @total_vote_days      = all_stats[0].to_i
    @all_time_votes       = all_stats[1].to_i
    reset_yes_total       = all_stats[2].to_i
    reset_no_total        = all_stats[3].to_i
    total_reset           = reset_yes_total + reset_no_total
    @all_time_reset_rate  = total_reset > 0 ? (reset_yes_total.to_f / total_reset * 100).round : nil
    weighted_sum          = all_stats[4].to_f
    weighted_total        = all_stats[5].to_i
    @all_time_setting_avg = weighted_total > 0 ? (weighted_sum / weighted_total).round(1) : nil

    # 設置店舗リスト (記録データなしでも表示)
    installed_scope = @machine_model.shops.includes(:prefecture)
    if params[:prefecture].present?
      installed_scope = installed_scope.where(prefectures: { slug: params[:prefecture] })
    end
    @installed_shops = installed_scope
                        .order("prefectures.id, shops.name")
                        .page(params[:shops_page]).per(30)

    # 設置店舗の台数マップ
    shop_ids = @installed_shops.map(&:id)
    @unit_counts = ShopMachineModel.where(shop_id: shop_ids, machine_model_id: @machine_model.id)
                                    .where.not(unit_count: nil)
                                    .pluck(:shop_id, :unit_count)
                                    .to_h

    # 都道府県フィルタ用 (設置がある都道府県のみ) — subquery avoids heavy 3-table JOIN + DISTINCT
    pref_ids = Shop.joins(:shop_machine_models)
                   .where(shop_machine_models: { machine_model_id: @machine_model.id })
                   .select(:prefecture_id).distinct
    @available_prefectures = Prefecture.where(id: pref_ids).order(:id)

    # 7-day trend data
    @trend_data = build_trend_data(@machine_model.vote_summaries)
  end

  def search
    query = params[:q].to_s.strip
    shop = Shop.find_by(id: params[:shop_id])
    date = params[:date].to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/) ? Date.parse(params[:date]) : Date.current
    if query.length >= 1 && shop
      # 旧字体カナ(ヱ/ヲ/ヰ)を新字体に寄せて比較し、「エヴァ」で「ヱヴァンゲリヲン」をヒットさせる
      pattern = "%#{MachineModel.sanitize_sql_like(query)}%"
      @machines = MachineModel.active
                              .where("translate(name, 'ヱヲヰ', 'エオイ') ILIKE translate(?, 'ヱヲヰ', 'エオイ')", pattern)
                              .order(:name)
                              .limit(10)
      # 検索結果も店舗グリッドと同じ machine_vote_row で描画するため、記録状態・集計を読み込む
      ids = @machines.map(&:id)
      summaries = VoteSummary.where(shop_id: shop.id, machine_model_id: ids, target_date: date).index_by(&:machine_model_id)
      votes = Vote.where(voter_token: voter_token, shop_id: shop.id, machine_model_id: ids, voted_on: date).index_by(&:machine_model_id)
      play_records = PlayRecord.where(voter_token: voter_token, shop_id: shop.id, machine_model_id: ids, played_on: date).index_by(&:machine_model_id)
      units = ShopMachineModel.where(shop_id: shop.id, machine_model_id: ids).where.not(unit_count: nil).pluck(:machine_model_id, :unit_count).to_h
    else
      @machines = MachineModel.none
      summaries = {}
      votes = {}
      play_records = {}
      units = {}
    end
    render partial: "machines/search_results",
           locals: { machines: @machines, shop: shop, date: date,
                     vote_summaries: summaries, user_votes: votes,
                     user_play_records: play_records, unit_counts: units },
           layout: false
  end

  def autocomplete
    query = params[:q].to_s.strip
    if query.length < 1
      render json: []
      return
    end

    pattern = "%#{MachineModel.sanitize_sql_like(query)}%"
    machines = MachineModel.active
                           .where("translate(name, 'ヱヲヰ', 'エオイ') ILIKE translate(?, 'ヱヲヰ', 'エオイ')", pattern)
                           .order(:name)
                           .limit(10)

    render json: machines.map { |m|
      {
        id: m.id,
        name: m.name,
        slug: m.slug,
        display_type: m.display_type_label
      }
    }
  end
end
