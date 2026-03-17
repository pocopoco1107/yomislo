class VoterProfile < ApplicationRecord
  RANK_TITLES = [
    { title: "伝説の記録者", min_points: 500, min_accuracy: 70.0 },
    { title: "設定看破マスター", min_points: 200, min_accuracy: 60.0 },
    { title: "目利き師", min_points: 80, min_accuracy: 40.0 },
    { title: "常連", min_points: 30 },
    { title: "記録者", min_points: 5 },
    { title: "見習い", min_points: 0 }
  ].freeze

  # ポイント付与ルール
  POINT_RULES = {
    vote: 1,               # 設定/リセット記録
    confirmed_setting: 2,   # 確定情報の記録
    play_record: 1,         # 収支記録
    feedback: 5,            # フィードバック送信
    exchange_rate_report: 3, # 交換率報告
    display_name_set: 3,    # ユーザー名設定(初回)
    streak_3: 2,            # 3日連続ボーナス
    streak_7: 5,            # 7日連続ボーナス
    streak_30: 15,          # 30日連続ボーナス
    multi_shop: 3,          # 3店舗以上で記録
    multi_prefecture: 5     # 3県以上で記録
  }.freeze

  validates :voter_token, presence: true, uniqueness: true
  validates :display_name, length: { maximum: 20 }, allow_blank: true

  # --- Class methods ---

  def self.refresh_for(voter_token)
    votes = Vote.where(voter_token: voter_token)
    return nil if votes.none?

    profile = find_or_initialize_by(voter_token: voter_token)

    # Basic counts
    profile.total_votes = votes.count
    profile.weekly_votes = votes.where(voted_on: Date.current.beginning_of_week..Date.current.end_of_week).count
    profile.monthly_votes = votes.where(voted_on: Date.current.beginning_of_month..Date.current.end_of_month).count

    # Streak calculation
    dates = votes.distinct.pluck(:voted_on).sort.reverse
    profile.last_voted_on = dates.first

    streak = calculate_streak(dates)
    profile.current_streak = streak
    profile.max_streak = [ streak, profile.max_streak || 0 ].max

    # Accuracy rates
    profile.accuracy_confirmed = nil # Will implement in batch later
    profile.accuracy_majority = calculate_accuracy_majority(voter_token, votes)
    profile.high_setting_rate = calculate_high_setting_rate(votes)

    # Points calculation
    profile.points = calculate_points(voter_token, profile)

    # Rank title (now based on points)
    profile.rank_title = determine_rank(profile.points, profile.accuracy_majority)

    profile.save!
    profile
  end

  def self.next_rank_for(profile)
    current_found = false
    RANK_TITLES.reverse_each do |rank|
      if current_found
        points_needed = [ rank[:min_points] - profile.points, 0 ].max
        accuracy_needed = rank[:min_accuracy] && (profile.accuracy_majority.nil? || profile.accuracy_majority < rank[:min_accuracy]) ? rank[:min_accuracy] : nil
        return {
          title: rank[:title],
          points_needed: points_needed,
          accuracy_needed: accuracy_needed
        } if points_needed > 0 || accuracy_needed
      end
      current_found = true if rank[:title] == profile.rank_title
    end
    nil
  end

  private

  def self.calculate_streak(dates)
    return 0 if dates.empty?

    streak = 0
    expected = Date.current

    # Allow starting from yesterday if no vote today
    if dates.first == expected
      streak = 1
      expected = expected - 1.day
      dates = dates.drop(1)
    elsif dates.first == expected - 1.day
      expected = expected - 1.day
    else
      return 0
    end

    dates.each do |d|
      if d == expected
        streak += 1
        expected = d - 1.day
      else
        break
      end
    end

    streak
  end

  def self.calculate_accuracy_majority(voter_token, votes)
    setting_votes = votes.where.not(setting_vote: nil)
    return nil if setting_votes.count < 5

    # Preload only the exact VoteSummaries needed (avoids Cartesian product)
    vote_keys = setting_votes.pluck(:shop_id, :machine_model_id, :voted_on)
    return nil if vote_keys.empty?

    summaries = VoteSummary.where(
      shop_id: vote_keys.map(&:first),
      machine_model_id: vote_keys.map { |k| k[1] },
      target_date: vote_keys.map(&:last)
    ).select { |s| vote_keys.include?([ s.shop_id, s.machine_model_id, s.target_date ]) }
     .index_by { |s| [ s.shop_id, s.machine_model_id, s.target_date ] }

    matches = 0
    total = 0

    setting_votes.find_each do |vote|
      summary = summaries[[ vote.shop_id, vote.machine_model_id, vote.voted_on ]]
      next unless summary&.setting_distribution.present?

      distribution = summary.setting_distribution
      next if distribution.values.sum < 3 # Need enough votes for meaningful majority

      mode_setting = distribution.max_by { |_k, v| v }&.first&.to_i
      next unless mode_setting

      total += 1
      matches += 1 if vote.setting_vote == mode_setting
    end

    return nil if total.zero?
    (matches.to_f / total * 100).round(1)
  end

  def self.calculate_high_setting_rate(votes)
    setting_votes = votes.where.not(setting_vote: nil)
    total = setting_votes.count
    return nil if total < 5

    high_count = setting_votes.where(setting_vote: [ 4, 5, 6 ]).count
    (high_count.to_f / total * 100).round(1)
  end

  def self.calculate_points(voter_token, profile)
    pts = 0

    # 記録ポイント (1pt per vote)
    votes = Vote.where(voter_token: voter_token)
    pts += votes.count * POINT_RULES[:vote]

    # 確定情報ボーナス (2pt per vote with confirmed_setting)
    pts += votes.where.not(confirmed_setting: []).count * POINT_RULES[:confirmed_setting]

    # 収支記録 (1pt per play record)
    pts += PlayRecord.where(voter_token: voter_token).count * POINT_RULES[:play_record]

    # フィードバック (5pt per feedback)
    pts += Feedback.where(voter_token: voter_token).count * POINT_RULES[:feedback]

    # 交換率報告 (3pt per report)
    pts += ShopContribution.where(voter_token: voter_token).count * POINT_RULES[:exchange_rate_report]

    # ユーザー名設定 (3pt, one-time)
    pts += POINT_RULES[:display_name_set] if profile.display_name.present?

    # ストリークボーナス
    max_streak = profile.max_streak || 0
    pts += POINT_RULES[:streak_30] if max_streak >= 30
    pts += POINT_RULES[:streak_7] if max_streak >= 7
    pts += POINT_RULES[:streak_3] if max_streak >= 3

    # 多店舗ボーナス (3店舗以上)
    shop_count = votes.distinct.count(:shop_id)
    pts += POINT_RULES[:multi_shop] if shop_count >= 3

    # 多県ボーナス (3県以上)
    pref_count = votes.joins(:shop).distinct.count("shops.prefecture_id")
    pts += POINT_RULES[:multi_prefecture] if pref_count >= 3

    pts
  end

  def self.determine_rank(points, accuracy)
    RANK_TITLES.each do |rank|
      next if points < rank[:min_points]
      if rank[:min_accuracy]
        next if accuracy.nil? || accuracy < rank[:min_accuracy]
      end
      return rank[:title]
    end
    "見習い"
  end
end
