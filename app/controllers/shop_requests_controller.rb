class ShopRequestsController < ApplicationController
  def new
    set_meta_tags noindex: true
    @shop_request = ShopRequest.new
    @prefectures = Prefecture.order(:id)
  end

  def create
    @shop_request = ShopRequest.new(shop_request_params)
    @shop_request.voter_token = voter_token

    if @shop_request.save
      redirect_to new_shop_request_path, notice: "店舗追加リクエストを受け付けました。審査までしばらくお待ちください。"
    else
      @prefectures = Prefecture.order(:id)
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @shop_request = ShopRequest.find(params[:id])
  end

  private

  def shop_request_params
    params.require(:shop_request).permit(:name, :prefecture_id, :address, :url, :note)
  end
end
