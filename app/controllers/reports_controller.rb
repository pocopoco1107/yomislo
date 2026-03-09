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

  def report_params
    params.require(:report).permit(:reportable_type, :reportable_id, :reason)
  end
end
