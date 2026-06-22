class ShopEventsController < ApplicationController
  def create
    @shop = Shop.find_by!(slug: params[:shop_slug])
    @event = @shop.shop_events.new(event_params)
    @event.voter_token = voter_token
    @event.status = :pending

    if @event.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to shop_path(@shop), notice: "イベント情報を送ったよ。審査が通れば表示される。" }
      end
    else
      redirect_to shop_path(@shop), alert: @event.errors.full_messages.join(", ")
    end
  end

  private

  def event_params
    params.require(:shop_event).permit(:event_date, :event_type, :title, :description, :source_url)
  end
end
