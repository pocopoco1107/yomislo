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

    @badges = compute_badges(
      total_votes: @total_votes_count,
      prefectures_count: @prefectures_count,
      machines_count: @machines_count
    )

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

  BADGE_DEFINITIONS = [
    { key: :first_vote,    icon: "\u{1F3B0}", name: "初記録",       description: "1件以上記録",         check: ->(s) { s[:total_votes] >= 1 } },
    { key: :contributor,   icon: "\u{1F4CA}", name: "データ提供者",  description: "10件以上記録",        check: ->(s) { s[:total_votes] >= 10 } },
    { key: :regular,       icon: "\u{1F3C6}", name: "常連記録者",    description: "50件以上記録",        check: ->(s) { s[:total_votes] >= 50 } },
    { key: :expert,        icon: "\u2B50",    name: "エキスパート",  description: "100件以上記録",       check: ->(s) { s[:total_votes] >= 100 } },
    { key: :master,        icon: "\u{1F451}", name: "マスター",      description: "500件以上記録",       check: ->(s) { s[:total_votes] >= 500 } },
    { key: :traveler,      icon: "\u{1F5FA}", name: "旅打ち",       description: "3県以上で記録",       check: ->(s) { s[:prefectures_count] >= 3 } },
    { key: :machine_mania, icon: "\u{1F3AF}", name: "機種マニア",    description: "10機種以上で記録",    check: ->(s) { s[:machines_count] >= 10 } }
  ].freeze

  def compute_badges(stats)
    BADGE_DEFINITIONS.map do |badge|
      badge.merge(earned: badge[:check].call(stats))
    end
  end

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
