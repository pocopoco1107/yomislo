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

  def calendar
    @shop = Shop.find_by!(slug: params[:slug])
    @calendar_month = parse_calendar_month(params[:month])
    @calendar_data = build_calendar_data(@shop, @calendar_month)
    @date = Date.current
    render partial: "shops/calendar", layout: false
  end

  def trend_data
    @shop = Shop.find_by!(slug: params[:slug])
    period = %w[7 30 all].include?(params[:period]) ? params[:period] : "7"
    @trend_data = build_trend_data_for_period(@shop.vote_summaries, period)
    @period = period

    render partial: "shops/trend_chart_frame", locals: {
      trend_data: @trend_data,
      period: @period,
      shop: @shop
    }, layout: false
  end

  def favorites
    slugs = (params[:slugs] || "").split(",").first(20)
    @shops = Shop.where(slug: slugs).includes(:prefecture)
    render partial: "shops/favorites_list", locals: { shops: @shops }, layout: false
  end

  def machines_for_shop
    shop = Shop.find_by(id: params[:shop_id])
    unless shop
      render json: []
      return
    end

    machines = shop.machine_models.where(active: true).order(:name)
    render json: machines.map { |m| { id: m.id, name: m.name } }
  end

  def autocomplete
    # Favorites mode: return shops by slugs (for focus dropdown)
    if params[:favorites].present?
      slugs = params[:favorites].split(",").first(20)
      shops = Shop.where(slug: slugs).includes(:prefecture)
      render json: shops.map { |s| { id: s.id, name: s.name, slug: s.slug, prefecture: s.prefecture.name } }
      return
    end

    query = params[:q].to_s.strip
    if query.length < 2
      render json: []
      return
    end

    shops = Shop.where("name LIKE ?", "%#{Shop.sanitize_sql_like(query)}%")
                .includes(:prefecture)
                .order(:name)
                .limit(10)

    render json: shops.map { |s| { id: s.id, name: s.name, slug: s.slug, prefecture: s.prefecture.name } }
  end

  def nearby
    lat = Float(params[:lat]) rescue nil
    lng = Float(params[:lng]) rescue nil

    if lat.nil? || lng.nil? || lat.abs > 90 || lng.abs > 180
      @nearby_shops = []
      @error = "位置情報が無効です"
      render layout: false
      return
    end

    radius_km = 10
    earth_radius_km = 6371.0

    # Haversine formula in PostgreSQL
    haversine_sql = <<~SQL.squish
      (#{earth_radius_km} * acos(
        LEAST(1.0, GREATEST(-1.0,
          cos(radians(:user_lat)) * cos(radians(shops.lat)) *
          cos(radians(shops.lng) - radians(:user_lng)) +
          sin(radians(:user_lat)) * sin(radians(shops.lat))
        ))
      ))
    SQL

    distance_sql = ActiveRecord::Base.sanitize_sql_array(
      [ haversine_sql, { user_lat: lat, user_lng: lng } ]
    )

    @nearby_shops = nearby_query(distance_sql, radius_km, "geocode_precision >= 2", 20)

    # precision=1（市レベル）の店舗は「おおよその位置」として別枠
    @imprecise_shops = nearby_query(distance_sql, radius_km, "geocode_precision <= 1", 10)

    render layout: false
  end

  def report_exchange_rate
    @shop = Shop.find_by!(slug: params[:slug])
    rate = params[:exchange_rate]
    unless Shop.exchange_rates.key?(rate)
      redirect_to shop_path(@shop), alert: "無効な交換率です"
      return
    end

    contribution = ShopContribution.find_or_initialize_by(
      voter_token: voter_token,
      shop: @shop,
      contribution_type: :exchange_rate
    )
    contribution.value = rate
    contribution.save!

    # Recalculate points
    VoterProfile.refresh_for(voter_token)

    redirect_to shop_path(@shop), notice: "交換率を報告しました (+#{VoterProfile::POINT_RULES[:exchange_rate_report]}pt)"
  end

  private

  def load_shop_data
    desc = "#{@shop.name}（#{@shop.prefecture.name}）のパチスロ設定・リセット記録。機種ごとの設定傾向をチェック。"
    set_meta_tags title: "#{@shop.name} - 設定・リセット記録",
                  description: desc,
                  keywords: "#{@shop.name}, #{@shop.prefecture.name}, パチスロ, 設定, リセット",
                  og: { title: "#{@shop.name} - 設定・リセット記録 | ヨミスロ",
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
                        .sort_by { |m| [ m.display_type_sort, m.name ] }

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
    @user_play_records = PlayRecord.where(voter_token: voter_token, shop_id: @shop.id, played_on: @date)
                                    .index_by(&:machine_model_id)

    # Daily summary: machine name/slug lookup — reuse already-loaded @machine_models
    models_by_id = @machine_models.index_by(&:id)
    @machine_names = models_by_id.transform_values(&:name)
    @machine_slugs = models_by_id.transform_values(&:slug)
    @comments = @shop.comments.for_date(@date).includes(:user).recent.limit(50)

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

    # Events (approved only)
    @upcoming_events = @shop.shop_events.visible.upcoming.limit(10)
    @past_events = @shop.shop_events.visible.past.limit(5)

    # Calendar data for the month containing @date
    @calendar_month = @date.beginning_of_month
    @calendar_data = build_calendar_data(@shop, @calendar_month)

    # 7-day trend data + weekly summary
    @trend_data = build_trend_data(@shop.vote_summaries)
    @weekly_summary = build_weekly_summary(@shop)
  end

  def build_calendar_data(shop, month)
    first_day = month.beginning_of_month
    last_day = month.end_of_month

    shop.vote_summaries
      .where(target_date: first_day..last_day)
      .group(:target_date)
      .pluck(Arel.sql("target_date"), Arel.sql("COALESCE(SUM(total_votes), 0)"))
      .each_with_object({}) do |(date, total), h|
        h[date] = { votes: total.to_i }
      end
  end

  def nearby_query(distance_sql, radius_km, precision_condition, limit)
    Shop.where.not(lat: nil).where.not(lng: nil)
        .where(precision_condition)
        .where("#{distance_sql} <= ?", radius_km)
        .select("shops.*, (#{distance_sql}) AS distance_km")
        .eager_load(:prefecture)
        .order(Arel.sql("#{distance_sql} ASC"))
        .limit(limit)
  end

  def parse_calendar_month(param)
    return Date.current.beginning_of_month if param.blank?
    Date.parse("#{param}-01").beginning_of_month
  rescue Date::Error
    Date.current.beginning_of_month
  end
end
