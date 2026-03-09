class HomeController < ApplicationController
  def index
    set_meta_tags title: "パチスロ設定・リセット投票",
                  description: "パチスロの設定・リセット情報をみんなの投票で集める。店舗×機種×日付で設定予想を共有するサイト。",
                  keywords: "パチスロ, 設定, リセット, 投票, 設定判別, スロット"
    @prefectures = Prefecture.all.order(:id)
    @recent_shops = Shop.includes(:prefecture).order(updated_at: :desc).limit(10)
    if params[:q].present?
      @search_results = Shop.search_by_name(params[:q]).includes(:prefecture).limit(20)
    end
  end
end
