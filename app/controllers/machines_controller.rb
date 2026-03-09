class MachinesController < ApplicationController
  def show
    @machine_model = MachineModel.find_by!(slug: params[:slug])
    set_meta_tags title: "#{@machine_model.name} - 全店舗の設定傾向",
                  description: "#{@machine_model.name}の全店舗横断設定・リセット投票データ。設定傾向をチェック。",
                  keywords: "#{@machine_model.name}, パチスロ, 設定, リセット"
    @vote_summaries = @machine_model.vote_summaries
                                     .where(target_date: Date.current)
                                     .includes(:shop)
                                     .order(total_votes: :desc)
                                     .page(params[:page]).per(20)
  end
end
