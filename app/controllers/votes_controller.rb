class VotesController < ApplicationController
  def create
    @vote = Vote.find_or_initialize_by(
      voter_token: voter_token,
      shop_id: vote_params[:shop_id],
      machine_model_id: vote_params[:machine_model_id],
      voted_on: vote_params[:voted_on]
    )
    # Only update the vote type that was submitted (don't overwrite the other)
    merge_params = { voter_token: voter_token }
    if vote_params.key?(:reset_vote)
      new_val = vote_params[:reset_vote].to_i
      merge_params[:reset_vote] = (@vote.reset_vote == new_val) ? nil : new_val
    end
    if vote_params.key?(:setting_vote)
      new_val = vote_params[:setting_vote].to_i
      merge_params[:setting_vote] = (@vote.setting_vote == new_val) ? nil : new_val
    end
    if vote_params.key?(:confirmed_setting)
      # Toggle: if tag already exists, remove it; otherwise add it
      tag = vote_params[:confirmed_setting]
      current_tags = @vote.confirmed_setting || []
      if current_tags.include?(tag)
        merge_params[:confirmed_setting] = current_tags - [ tag ]
      else
        merge_params[:confirmed_setting] = current_tags + [ tag ]
      end
    end
    @vote.assign_attributes(vote_params.slice(:shop_id, :machine_model_id, :voted_on).merge(merge_params))

    # If all vote fields are empty, destroy the vote record
    if @vote.persisted? && @vote.reset_vote.nil? && @vote.setting_vote.nil? && @vote.confirmed_setting.blank?
      @vote.destroy
      @shop = Shop.find(@vote.shop_id)
      @machine_model = MachineModel.find(@vote.machine_model_id)
      @vote_summary = VoteSummary.find_by(shop_id: @vote.shop_id, machine_model_id: @vote.machine_model_id, target_date: @vote.voted_on)
      @vote = Vote.new(shop_id: @shop.id, machine_model_id: @machine_model.id, voted_on: vote_params[:voted_on])
      @daily_summary_locals = build_daily_summary_locals(@shop, @vote.voted_on)
      respond_to do |format|
        format.turbo_stream { render :create }
        format.html { redirect_to shop_path(@shop) }
      end
      return
    end

    if @vote.save
      @shop = @vote.shop
      @machine_model = @vote.machine_model
      @vote_summary = @vote.cached_vote_summary
      # 新規記録のときだけペットを成長させる (既存行へのトグル更新では増やさない)
      if @vote.previously_new_record?
        @pet_result = grow_companion(recorded_on: @vote.voted_on)
        @gold_gain = compute_gold_gain(@vote)
        @milestones = detect_milestones(@vote)
      end
      @daily_summary_locals = build_daily_summary_locals(@shop, @vote.voted_on)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to shop_path(@shop) }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("vote_errors", partial: "votes/errors", locals: { vote: @vote }) }
        format.html {
          shop = Shop.find_by(id: vote_params[:shop_id])
          redirect_to(shop ? shop_path(shop) : root_path, alert: @vote.errors.full_messages.join(", "))
        }
      end
    end
  end

  def update
    @vote = Vote.find_by!(id: params[:id], voter_token: voter_token)
    attrs = vote_params.to_h
    # confirmed_setting は配列カラム。scalar が来ても配列に正規化し、既存値を空に潰さない
    if attrs.key?("confirmed_setting")
      attrs["confirmed_setting"] = Array(attrs["confirmed_setting"]).reject(&:blank?)
    end
    if @vote.update(attrs)
      @shop = @vote.shop
      @machine_model = @vote.machine_model
      @vote_summary = @vote.cached_vote_summary
      @daily_summary_locals = build_daily_summary_locals(@shop, @vote.voted_on)
      respond_to do |format|
        format.turbo_stream { render :create }
        format.html { redirect_to shop_path(@shop) }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("vote_errors", partial: "votes/errors", locals: { vote: @vote }) }
        format.html { redirect_to shop_path(@vote.shop), alert: @vote.errors.full_messages.join(", ") }
      end
    end
  end

  private

  def vote_params
    params.require(:vote).permit(:shop_id, :machine_model_id, :voted_on, :reset_vote, :setting_vote, :confirmed_setting)
  end

  # "今日の記録一覧" (daily-summary) を turbo_stream で再描画するための locals を組み立てる。
  # shops_controller#show_date と同じ形（machine_model_id をキーにしたハッシュ群）に揃える。
  def build_daily_summary_locals(shop, date)
    vote_summaries = shop.vote_summaries.where(target_date: date).index_by(&:machine_model_id)
    models_by_id = MachineModel.where(id: vote_summaries.keys).index_by(&:id)
    {
      vote_summaries: vote_summaries,
      machine_names: models_by_id.transform_values(&:name),
      machine_slugs: models_by_id.transform_values(&:slug),
      date: date
    }
  end

  # 新規vote作成時に加算されるゴールド (=VoterProfile.pts の増分)。
  # refresh_for は全件からの再計算なので厳密な差分は取れないが、この1件分の寄与は
  # POINT_RULES[:vote] と confirmed_setting 有無で近似できる。streak/multi_shop 等の
  # 到達ボーナスはトースト目的では省略 (演出は「その記録」に紐づく分だけに絞る)。
  def compute_gold_gain(vote)
    gain = VoterProfile::POINT_RULES[:vote]
    gain += VoterProfile::POINT_RULES[:confirmed_setting] if vote.confirmed_setting.present?
    gain
  end

  MILESTONE_TOTAL_VOTES = [ 10, 100, 1000 ].freeze
  MILESTONE_STREAKS = [ 7, 30 ].freeze
  HIGH_SETTINGS = [ 4, 5, 6 ].freeze

  # 新規vote保存直後にマイルストーン到達を検知する。
  # VoterProfile.refresh_for は after_commit で非同期に走るため、コントローラでは
  # 「保存前のVoterProfile値」と「今回のvoteを含めた実測値」を比較して差分判定する。
  def detect_milestones(vote)
    before = VoterProfile.find_by(voter_token: vote.voter_token)
    before_total = before&.total_votes || 0
    before_streak = before&.max_streak || 0

    scope = Vote.where(voter_token: vote.voter_token)
    after_total = scope.count
    dates = scope.distinct.pluck(:voted_on).sort.reverse
    current_streak = VoterProfile.send(:calculate_streak, dates)
    after_streak = [ current_streak, before_streak ].max

    milestones = []
    MILESTONE_TOTAL_VOTES.each do |t|
      milestones << { type: :total_votes, threshold: t } if before_total < t && after_total >= t
    end
    MILESTONE_STREAKS.each do |t|
      milestones << { type: :streak, threshold: t } if before_streak < t && after_streak >= t
    end
    if HIGH_SETTINGS.include?(vote.setting_vote) &&
       !Vote.where(voter_token: vote.voter_token, setting_vote: HIGH_SETTINGS).where.not(id: vote.id).exists?
      milestones << { type: :first_high_setting, setting: vote.setting_vote }
    end
    milestones
  end
end
