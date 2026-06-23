class VoterController < ApplicationController
  def status
    set_meta_tags title: "マイステータス", noindex: true

    token = voter_token

    @profile = VoterProfile.find_by(voter_token: token)
    @has_votes = @profile.present? && @profile.total_votes > 0
    @pet = Pet.for(token)

    return unless @has_votes

    votes = Vote.where(voter_token: token)
    @total_votes_count = @profile.total_votes
    @shops_count = votes.distinct.count(:shop_id)
    @machines_count = votes.distinct.count(:machine_model_id)
    @prefectures_count = votes.joins(:shop).distinct.count("shops.prefecture_id")

    @recent_votes = votes.includes(:shop, :machine_model)
                         .order(voted_on: :desc, updated_at: :desc)
                         .limit(10)

    # Streak data for view (last 7 days)
    @streak_days = build_streak_calendar(token)

    @voter_label = @profile.display_name.presence || "ユーザー##{token.last(4)}"

    # Points breakdown for display
    @play_records_count = PlayRecord.where(voter_token: token).count
    @feedbacks_count = Feedback.where(voter_token: token).count
    @contributions_count = ShopContribution.where(voter_token: token).count
  end

  def update_display_name
    token = voter_token
    profile = VoterProfile.find_or_initialize_by(voter_token: token)
    name = params[:display_name].to_s.strip
    if name.length > 20
      redirect_to voter_status_path, alert: "ユーザー名は20文字までです"
      return
    end

    profile.display_name = name.presence
    profile.save! if profile.persisted?

    # Recalculate points (display_name_set bonus)
    VoterProfile.refresh_for(token) if profile.persisted?

    redirect_to voter_status_path, notice: name.present? ? "ユーザー名を設定しました" : "ユーザー名をリセットしました"
  end

  def restore
    token = params[:token]&.strip
    if token.present? && Vote.exists?(voter_token: token)
      cookies.permanent[:voter_token] = token
      redirect_to voter_status_path, notice: "トークンを復元しました"
    else
      redirect_to voter_status_path, alert: "トークンが見つかりません"
    end
  end

  private

  def build_streak_calendar(token)
    today = Date.current
    dates_range = (today - 6.days)..today
    voted_dates = Vote.where(voter_token: token, voted_on: dates_range)
                      .distinct.pluck(:voted_on).to_set

    (0..6).map do |i|
      day = today - (6 - i).days
      {
        label: ApplicationHelper::DAY_LABELS[day.wday],
        date: day,
        voted: voted_dates.include?(day)
      }
    end
  end
end
