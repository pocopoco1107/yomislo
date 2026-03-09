class PrefecturesController < ApplicationController
  def show
    @prefecture = Prefecture.find_by!(slug: params[:slug])
    @shops = @prefecture.shops.order(:name).page(params[:page]).per(20)
    set_meta_tags title: "#{@prefecture.name}のパチスロ店舗一覧",
                  description: "#{@prefecture.name}のパチスロ店舗の設定・リセット投票情報一覧。",
                  keywords: "#{@prefecture.name}, パチスロ, 設定, リセット, 店舗"
  end
end
