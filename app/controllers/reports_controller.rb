class ReportsController < ApplicationController
  def create
    @report = Report.new(report_params)
    @report.voter_token = voter_token
    if @report.save
      # コメント/レビューが複数並ぶページでも id が重複しないよう、
      # 通報対象ごとに一意な report_flash id を対象にする
      flash_id = "report_flash_#{@report.reportable_type}_#{@report.reportable_id}"
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(flash_id) {
            helpers.content_tag(:div, "通報を受け付けました", id: flash_id, class: "text-slot-green text-xs")
          }
        end
        format.html { redirect_back fallback_location: root_path, notice: "通報を受け付けました" }
      end
    else
      redirect_back fallback_location: root_path, alert: "通報に失敗しました"
    end
  end

  private

  ALLOWED_REPORTABLE_TYPES = %w[Comment ShopReview].freeze

  def report_params
    permitted = params.require(:report).permit(:reportable_type, :reportable_id, :reason)
    unless ALLOWED_REPORTABLE_TYPES.include?(permitted[:reportable_type])
      raise ActionController::BadRequest, "Invalid reportable_type"
    end
    permitted
  end
end
