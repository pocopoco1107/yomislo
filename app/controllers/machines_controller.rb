class MachinesController < ApplicationController
  include TrendData

  def show
    @machine_model = MachineModel.find_by!(slug: params[:slug])
    @installed_shop_count = @machine_model.shop_machine_models.count
    # SEO meta tags with spec info
    meta_desc_parts = ["#{@machine_model.name}の全店舗横断設定・リセット投票データ"]
    meta_desc_parts << "機械割#{@machine_model.payout_rate_display}" if @machine_model.payout_rate_display
    meta_desc_parts << @machine_model.type_detail if @machine_model.type_detail.present?
    meta_desc_parts << "設定傾向をチェック"
    meta_desc = meta_desc_parts.join("。") + "。"
    set_meta_tags title: "#{@machine_model.name} - 全店舗の設定傾向",
                  description: meta_desc,
                  keywords: "#{@machine_model.name}, パチスロ, 設定, リセット, #{@machine_model.maker}, #{@machine_model.generation_label}".squish,
                  og: { title: "#{@machine_model.name} - 全店舗の設定傾向 | スロリセnavi",
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
    @sns_reports = @machine_model.sns_reports.approved.recent.limit(10)
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

    # 設置店舗リスト (投票データなしでも表示)
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
    if query.length >= 1
      @machines = MachineModel.active
                              .where("name ILIKE ?", "%#{MachineModel.sanitize_sql_like(query)}%")
                              .order(:name)
                              .limit(10)
    else
      @machines = MachineModel.none
    end
    render partial: "machines/search_results", locals: { machines: @machines, shop_id: params[:shop_id], date: params[:date] }, layout: false
  end
end
