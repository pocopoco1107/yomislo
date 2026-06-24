class SearchController < ApplicationController
  # 検索フィルタに使う boolean カラム
  FACILITY_FILTER_COLUMNS = %w[
    wifi_available charging_available low_rate_slot data_publishing
    okislot ticket_distribution heated_tobacco_ok slot_smoking_ok
  ].freeze

  def index
    @prefectures = Prefecture.order(:id)
    @selected_prefecture = params[:prefecture].presence
    @any_filter_active = filter_active?
    @shops = search_shops

    set_meta_tags title: "全国パチスロ店舗検索 - 設備・営業時間で絞り込み",
                  description: "全国のパチスロ店舗を設備・営業時間・入場方法で横断検索。Wi-Fi・充電・低貸・データ公開など条件で絞り込み。",
                  keywords: "パチスロ, 店舗検索, 優良店, Wi-Fi, 低貸, データ公開"
  end

  private

  def filter_active?
    @selected_prefecture.present? ||
      params[:opening_hours].present? ||
      params[:morning_entry] == "yes" ||
      params[:parking] == "yes" ||
      params[:entry_method].present? ||
      FACILITY_FILTER_COLUMNS.any? { |c| params[c] == "yes" }
  end

  def search_shops
    scope = Shop.listed.includes(:prefecture)

    if @selected_prefecture
      pref_id = Prefecture.where(slug: @selected_prefecture).pick(:id)
      scope = scope.where(prefecture_id: pref_id) if pref_id
    end

    if params[:parking] == "yes"
      scope = scope.where("parking_spaces IS NOT NULL AND parking_spaces > 0")
    end

    if params[:opening_hours].present?
      hours = Array(params[:opening_hours]).map(&:to_i).uniq
      conditions = hours.map { |_| "business_hours LIKE ?" }
      binds = hours.map { |h| "#{h}:%" }
      scope = scope.where(conditions.join(" OR "), *binds)
    end

    if params[:morning_entry] == "yes"
      scope = scope.where.not(morning_entry: [ nil, "" ])
    end

    if params[:entry_method].present? && %w[lottery queue other].include?(params[:entry_method])
      scope = scope.where(entry_method: params[:entry_method])
    end

    FACILITY_FILTER_COLUMNS.each do |col|
      scope = scope.where(col => true) if params[col] == "yes"
    end

    if params[:q].present?
      scope = scope.where("shops.name LIKE ?", "%#{Shop.sanitize_sql_like(params[:q])}%")
    end

    scope.order(:prefecture_id, :name).page(params[:page]).per(30)
  end
end
