class ShopsController < ApplicationController
  include TrendData

  def show
    @shop = Shop.includes(:prefecture).find_by!(slug: params[:slug])
    @date = Date.current
    load_shop_data
  end

  def show_date
    @date = begin
      Date.parse(params[:date])
    rescue Date::Error
      nil
    end
    # 運用開始前・未来の日付は記録が存在しない。重い load_shop_data を実行せず
    # 404 を返し、無限に増える過去日付URLへのクロール負荷を遮断する。
    if @date.nil? || @date < Shop::EARLIEST_RECORD_DATE || @date > Date.current
      raise ActiveRecord::RecordNotFound
    end
    @shop = Shop.includes(:prefecture).find_by!(slug: params[:slug])
    # 投稿ゼロの過去日は空の重複コンテンツ。load_shop_data(17クエリ・Views 300〜700ms)を
    # 実行せず 404 を返し、ここを大量に叩く分散ボットの負荷を遮断する（当日は記録UIのため対象外）。
    if @date < Date.current && !@shop.vote_summaries.where(target_date: @date).exists?
      raise ActiveRecord::RecordNotFound
    end
    load_shop_data
    render :show
  end

  def calendar
    @calendar_month = parse_calendar_month(params[:month])
    # 運用開始前・未来の月には記録が存在しない。店舗クエリも発行せず 404 を返し、
    # month パラメータで無限に増える月URLへのクロール負荷を遮断する
    # （カレンダーの前月/翌月リンク自体は範囲内でしか生成されない）。
    raise ActiveRecord::RecordNotFound if @calendar_month.nil?
    @shop = Shop.find_by!(slug: params[:slug])
    @calendar_data = build_calendar_data(@shop, @calendar_month)
    @date = params[:date].present? ? (Date.parse(params[:date]) rescue Date.current) : Date.current
    render layout: false
  end

  # 機種行の記録UI。details を開いた時だけ取得され、初期応答には summary だけを載せる。
  # 閉じた行の記録フォーム（1機種16個 × 設置機種数）は誰にも見られないまま描画されており、
  # 大型店では HTML の 9 割超・描画コストの大半をこれが占めていた。
  def machine_row
    @date = parse_row_date(params[:date])
    # 範囲外の日付は show_date と同様に 404。日付ごとに無限に増えるURLを作らない。
    raise ActiveRecord::RecordNotFound if @date.nil?

    @shop = Shop.find_by!(slug: params[:slug])
    @machine_model = MachineModel.find(params[:machine_model_id])
    @vote_summary = VoteSummary.find_by(shop_id: @shop.id, machine_model_id: @machine_model.id, target_date: @date)

    # 副作用なし版を使う。記録UIを見るだけの訪問者に cookie を発行しない
    # （記録が無ければ nil でも描画結果は同じ）。
    if (token = existing_voter_token)
      @user_vote = Vote.find_by(voter_token: token, shop_id: @shop.id,
                                machine_model_id: @machine_model.id, voted_on: @date)
      @user_play_record = PlayRecord.find_by(voter_token: token, shop_id: @shop.id,
                                             machine_model_id: @machine_model.id, played_on: @date)
    end

    render layout: false
  end

  # モーダル本文・トレンドは lazy turbo-frame で遅延ロードし、店舗詳細の初期応答から
  # 重い実体化・描画（events/comments/trend）を切り離す。ボットは lazy frame を追わない。
  # 各アクションのビューは対応する turbo-frame id でラップする（lazy src の置換に必須）。
  def events_body
    @shop = Shop.find_by!(slug: params[:slug])
    @upcoming_events = @shop.shop_events.visible.upcoming.limit(10)
    @past_events = @shop.shop_events.visible.past.limit(5)
    render layout: false
  end

  def comments_body
    @shop = Shop.find_by!(slug: params[:slug])
    @comments = @shop.comments.recent.limit(50)
    @commenter_profiles = VoterProfile.where(voter_token: @comments.map(&:voter_token).compact.uniq)
                                      .index_by(&:voter_token)
    render layout: false
  end

  def trend_section
    @shop = Shop.find_by!(slug: params[:slug])
    @trend_data = build_trend_data(@shop.vote_summaries)
    @weekly_summary = build_weekly_summary(@shop)
    render layout: false
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

    shops = Shop.listed.where("name LIKE ?", "%#{Shop.sanitize_sql_like(query)}%")
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

  private

  def load_shop_data
    # Show machines registered to this shop (join table) + machines with votes today.
    # 台数マップも同じ pluck から作り、shop_machine_models の二重走査を避ける。
    registered = @shop.shop_machine_models.pluck(:machine_model_id, :unit_count)
    registered_ids = registered.map(&:first)
    @unit_counts = registered.to_h.compact
    voted_ids = Vote.where(shop_id: @shop.id, voted_on: @date)
                    .distinct.pluck(:machine_model_id)
    machine_ids = (registered_ids + voted_ids).uniq

    @machine_models = MachineModel.where(id: machine_ids).order(:name).to_a
                        .sort_by { |m| [ m.display_type_sort, m.name ] }

    @vote_summaries = @shop.vote_summaries
                           .where(target_date: @date)
                           .index_by(&:machine_model_id)

    desc = "#{@shop.name}（#{@shop.prefecture.name}）の設定・リセット情報を、打ち手の投稿でチェック。設置#{@machine_models.size}機種。#{@shop.address}"
    seo_title = "#{@shop.name}（#{@shop.prefecture.name}）の設定・リセット情報"
    # 過去日付ページで投稿が1件もない日は空の重複コンテンツになるためnoindex
    date_has_no_votes = action_name == "show_date" && @vote_summaries.values.sum(&:total_votes).zero?
    set_meta_tags title: seo_title,
                  description: desc,
                  keywords: "#{@shop.name}, #{@shop.prefecture.name}, パチスロ, 設定, リセット, 出玉, 高設定",
                  og: { title: "#{seo_title} | ヨミスロ",
                        description: desc,
                        type: "website",
                        url: request.original_url.split("?").first },
                  twitter: { card: "summary" },
                  noindex: date_has_no_votes
    @user_votes = Vote.where(voter_token: voter_token, shop_id: @shop.id, voted_on: @date)
                      .index_by(&:machine_model_id)
    @user_play_records = PlayRecord.where(voter_token: voter_token, shop_id: @shop.id, played_on: @date)
                                    .index_by(&:machine_model_id)

    # Daily summary: machine name/slug lookup — reuse already-loaded @machine_models
    models_by_id = @machine_models.index_by(&:id)
    @machine_names = models_by_id.transform_values(&:name)
    @machine_slugs = models_by_id.transform_values(&:slug)

    # 交換率（店舗情報 details 内・軽量）
    @exchange_rate_summaries = ExchangeRateSummary.where(shop_id: @shop.id).index_by(&:denomination)
    @user_exchange_rate_reports = ExchangeRateReport.where(voter_token: voter_token, shop_id: @shop.id).index_by(&:denomination)

    # モーダルトリガーの件数バッジ（軽量 COUNT / AVG。本文の実体化・描画は lazy turbo-frame へ）
    @event_count = @shop.shop_events.visible.count
    @comment_count = @shop.comments.count
    @average_rating = @shop.comments.where.not(rating: nil).average(:rating)&.round(1)

    # トレンドセクションの出し分け判定（本体は lazy turbo-frame でロード）
    @has_vote_summaries = @shop.vote_summaries.exists?
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
    Shop.listed.where.not(lat: nil).where.not(lng: nil)
        .where(precision_condition)
        .where("#{distance_sql} <= ?", radius_km)
        .select("shops.*, (#{distance_sql}) AS distance_km")
        .eager_load(:prefecture)
        .order(Arel.sql("#{distance_sql} ASC"))
        .limit(limit)
  end

  # 機種行の日付。範囲外（運用開始前・未来）とパース不能な値は nil を返し、呼び出し側で 404 にする。
  def parse_row_date(param)
    return Date.current if param.blank?
    date = Date.parse(param)
    return nil if date < Shop::EARLIEST_RECORD_DATE || date > Date.current
    date
  rescue Date::Error
    nil
  end

  # 範囲外（運用開始前・未来）とパース不能な月は nil を返し、呼び出し側で 404 にする。
  def parse_calendar_month(param)
    return Date.current.beginning_of_month if param.blank?
    month = Date.parse("#{param}-01").beginning_of_month
    return nil if month < Shop::EARLIEST_RECORD_DATE.beginning_of_month
    return nil if month > Date.current.beginning_of_month
    month
  rescue Date::Error
    nil
  end
end
