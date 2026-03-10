class ReportsController < ApplicationController
  def create
    @report = Report.new(report_params)
    @report.voter_token = voter_token
    if @report.save
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("report_flash", html: '<div id="report_flash" class="text-green-600 text-sm">通報しました</div>') }
        format.html { redirect_back fallback_location: root_path, notice: "通報しました" }
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
