class ExchangeRateReportsController < ApplicationController
  def create
    @shop = Shop.find(report_params[:shop_id])
    @report = ExchangeRateReport.find_or_initialize_by(
      voter_token: voter_token,
      shop_id: @shop.id,
      denomination: report_params[:denomination]
    )

    new_rate = report_params[:rate_key]

    if @report.persisted? && @report.rate_key == new_rate
      @report.destroy
      @report = ExchangeRateReport.new(shop_id: @shop.id, denomination: report_params[:denomination])
    else
      @report.rate_key = new_rate
      unless @report.save
        # バリデーション失敗時はエラー内容を画面に表示する
        @error_denomination = report_params[:denomination]
        @error_rate_key = new_rate
        @error_message = @report.errors.full_messages.first || "報告できませんでした"
        respond_to do |format|
          format.turbo_stream { render :create, status: :unprocessable_entity }
          format.html { redirect_to shop_path(@shop), alert: @error_message }
        end
        return
      end
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to shop_path(@shop) }
    end
  end

  private

  def report_params
    params.require(:exchange_rate_report).permit(:shop_id, :denomination, :rate_key)
  end
end
