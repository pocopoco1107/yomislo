class PlayRecordsController < ApplicationController
  before_action :require_voter_token
  before_action :set_play_record, only: [ :update, :destroy ]

  def index
    set_meta_tags title: "収支カレンダー", noindex: true
    token = voter_token

    @current_month = if params[:month].present? && params[:month].match?(/\A\d{4}-\d{2}\z/)
                       Date.parse("#{params[:month]}-01")
    else
                       Date.current.beginning_of_month
    end

    @records = PlayRecord.where(voter_token: token)
                         .by_month(@current_month)
                         .includes(:shop, :machine_model)
                         .order(played_on: :desc)

    # Calendar data
    @calendar_data = @records.group_by(&:played_on).transform_values do |recs|
      recs.sum(&:result_amount)
    end

    # Monthly summary
    @monthly_total = @records.sum(&:result_amount)
    @monthly_count = @records.select(:played_on).distinct.count
    @monthly_wins = @records.count { |r| r.win? }
    @monthly_losses = @records.count { |r| r.lose? }
    @monthly_win_rate = @monthly_count > 0 ? (@monthly_wins.to_f / (@monthly_wins + @monthly_losses) * 100).round(0) : 0

    # All-time
    all_records = PlayRecord.where(voter_token: token)
    @total_result = all_records.sum(:result_amount)

    # Grouped records for display (date+shop grouping)
    @grouped_records = @records.group_by { |r| [ r.played_on, r.shop_id ] }

    # Load user votes and vote summaries for records that have a machine_model
    record_keys = @records.select(&:machine_model_id).map { |r| [ r.shop_id, r.machine_model_id, r.played_on ] }.uniq
    if record_keys.any?
      vote_scope = Vote.where(voter_token: token).none
      summary_scope = VoteSummary.none
      record_keys.each do |sid, mid, d|
        vote_scope = vote_scope.or(Vote.where(voter_token: token, shop_id: sid, machine_model_id: mid, voted_on: d))
        summary_scope = summary_scope.or(VoteSummary.where(shop_id: sid, machine_model_id: mid, target_date: d))
      end
      @user_votes_by_key = vote_scope.index_by { |v| [ v.shop_id, v.machine_model_id, v.voted_on ] }
      @vote_summaries_by_key = summary_scope.index_by { |vs| [ vs.shop_id, vs.machine_model_id, vs.target_date ] }
    else
      @user_votes_by_key = {}
      @vote_summaries_by_key = {}
    end
  end

  def create
    token = voter_token

    if params[:entries].present?
      create_multiple(token)
    elsif params[:play_record].present?
      create_single(token)
    else
      redirect_to play_records_path, alert: "不正なパラメータです"
    end
  end

  def update
    if @record.update(play_record_params)
      redirect_to play_records_path(month: @record.played_on.strftime("%Y-%m")),
                  notice: "収支を更新しました"
    else
      redirect_to play_records_path, alert: @record.errors.full_messages.join(", ")
    end
  end

  def destroy
    month = @record.played_on.strftime("%Y-%m")
    machine_model_id = @record.machine_model_id
    shop = @record.shop
    played_on = @record.played_on
    @record.destroy

    respond_to do |format|
      format.turbo_stream do
        @record = nil # cleared
        render_shop_machine_update(shop: shop, machine_model_id: machine_model_id, played_on: played_on)
      end
      format.html do
        redirect_back fallback_location: play_records_path(month: month), notice: "記録を削除しました"
      end
    end
  end

  private

  def create_single(token)
    @record = PlayRecord.new(play_record_params)
    @record.voter_token = token

    if @record.save
      @pet_result = grow_companion(recorded_on: @record.played_on)
      respond_to do |format|
        format.turbo_stream { render_shop_machine_update }
        format.html do
          if params[:return_to].present? && params[:return_to].start_with?("/")
            redirect_to params[:return_to], notice: pet_notice("収支を記録しました")
          else
            redirect_to play_records_path(month: @record.played_on.strftime("%Y-%m")),
                        notice: pet_notice("収支を記録しました")
          end
        end
      end
    else
      respond_to do |format|
        format.turbo_stream do
          error_html = helpers.content_tag(:div, @record.errors.full_messages.join(", "),
            id: "vote_errors", class: "bg-destructive/10 text-destructive text-xs p-2 rounded mb-2")
          render turbo_stream: turbo_stream.replace("vote_errors", error_html)
        end
        format.html do
          if params[:return_to].present? && params[:return_to].start_with?("/")
            redirect_to params[:return_to], alert: @record.errors.full_messages.join(", ")
          else
            redirect_to play_records_path, alert: @record.errors.full_messages.join(", ")
          end
        end
      end
    end
  end

  def create_multiple(token)
    entries = params[:entries].values
    if entries.size > 50
      redirect_to play_records_path, alert: "一度に記録できるのは50件までです"
      return
    end
    shop_id = params[:shop_id]
    played_on = params[:played_on]
    is_public = params[:is_public] != "0"

    records = []
    vote_data = []
    errors = []

    entries.each do |entry|
      record = PlayRecord.new(
        voter_token: token,
        shop_id: shop_id,
        machine_model_id: entry[:machine_model_id].presence,
        played_on: played_on,
        result_amount: entry[:result_amount].to_i,
        is_public: is_public
      )
      if record.valid?
        records << record
      else
        errors.concat(record.errors.full_messages)
      end

      # Collect vote data if machine and any vote field is present
      mid = entry[:machine_model_id].presence
      has_vote = entry[:reset_vote].present? || entry[:setting_vote].present? ||
                 entry[:confirmed_setting]&.reject(&:blank?)&.any?
      if mid && has_vote
        vote_data << {
          machine_model_id: mid.to_i,
          reset_vote: entry[:reset_vote].present? ? entry[:reset_vote].to_i : nil,
          setting_vote: entry[:setting_vote].present? ? entry[:setting_vote].to_i : nil,
          confirmed_setting: entry[:confirmed_setting]&.reject(&:blank?) || []
        }
      end
    end

    if errors.empty? && records.any?
      created_votes = 0
      PlayRecord.transaction do
        records.each(&:save!)
        # Save votes alongside play records
        vote_data.each do |vd|
          vote = Vote.find_or_initialize_by(
            voter_token: token,
            shop_id: shop_id,
            machine_model_id: vd[:machine_model_id],
            voted_on: played_on
          )
          vote.reset_vote = vd[:reset_vote] if vd[:reset_vote]
          vote.setting_vote = vd[:setting_vote] if vd[:setting_vote]
          if vd[:confirmed_setting].any?
            vote.confirmed_setting = ((vote.confirmed_setting || []) + vd[:confirmed_setting]).uniq
          end
          vote.save!
          created_votes += 1 if vote.previously_new_record?
        end
      end
      # 新規に作られた収支記録 + Vote の合計件数だけペットを成長させる (同日なので1回呼び出し)
      @pet_result = grow_companion(recorded_on: played_on, count: records.size + created_votes)
      month = played_on.to_s[0..6]
      redirect_to play_records_path(month: month),
                  notice: pet_notice("#{records.size}件の収支を記録しました")
    else
      redirect_to play_records_path, alert: errors.uniq.join(", ").presence || "記録する内容がありません"
    end
  end

  def require_voter_token
    voter_token # ensure token exists
  end

  # 進化したときだけ通知文の頭にお祝いを付ける
  def pet_notice(base)
    return base unless @pet_result&.evolved?

    "🎉 相棒が#{@pet_result.pet.stage_label}に進化！ #{base}"
  end

  def set_play_record
    @record = PlayRecord.find_by!(id: params[:id], voter_token: voter_token)
  end

  def render_shop_machine_update(shop: nil, machine_model_id: nil, played_on: nil)
    shop ||= @record.shop
    machine_model_id ||= @record.machine_model_id
    played_on ||= @record.played_on
    token = voter_token

    machine_model = MachineModel.find(machine_model_id)
    vote_summary = VoteSummary.find_by(shop_id: shop.id, machine_model_id: machine_model_id, target_date: played_on)
    user_vote = Vote.find_by(voter_token: token, shop_id: shop.id, machine_model_id: machine_model_id, voted_on: played_on)
    user_play_record = PlayRecord.find_by(voter_token: token, shop_id: shop.id, machine_model_id: machine_model_id, played_on: played_on)
    unit_count = ShopMachineModel.find_by(shop_id: shop.id, machine_model_id: machine_model_id)&.unit_count

    render turbo_stream: turbo_stream.replace("machine_vote_#{machine_model_id}",
      partial: "shops/machine_vote_row",
      locals: {
        machine_model: machine_model,
        vote_summary: vote_summary,
        user_vote: user_vote,
        user_play_record: user_play_record,
        shop: shop,
        date: played_on,
        unit_count: unit_count
      })
  end

  def play_record_params
    params.require(:play_record).permit(:shop_id, :machine_model_id, :played_on,
                                         :result_amount, :investment, :payout,
                                         :memo, :is_public, tags: [])
  end
end
