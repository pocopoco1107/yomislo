class SearchController < ApplicationController
  def index
    @prefectures = Prefecture.order(:id)
    @selected_prefecture = params[:prefecture].presence
    @any_filter_active = filter_active?
    @shops = search_shops

    set_meta_tags title: "全国店舗検索",
                  description: "全国のパチスロ店舗を条件で横断検索。",
                  keywords: "パチスロ, 店舗検索, 店舗"
  end

  private

  def filter_active?
    @selected_prefecture.present? ||
      params[:opening_hours].present? ||
      params[:morning_entry] == "yes" ||
      params[:parking] == "yes"
  end

  def search_shops
    scope = Shop.includes(:prefecture)

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

    if params[:q].present?
      scope = scope.where("shops.name LIKE ?", "%#{Shop.sanitize_sql_like(params[:q])}%")
    end

    scope.order(:prefecture_id, :name).page(params[:page]).per(30)
  end
end
