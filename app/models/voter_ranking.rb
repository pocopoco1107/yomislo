class VoterRanking < ApplicationRecord
  enum :period_type, { weekly: 0, monthly: 1, all_time: 2 }

  validates :voter_token, presence: true
  validates :period_key, presence: true
  validates :rank_position, presence: true, numericality: { greater_than: 0 }
  validates :voter_token, uniqueness: { scope: [ :period_type, :period_key, :scope_type, :scope_id ] }

  scope :national, -> { where(scope_type: "national") }
  scope :top, ->(n = 10) { where("rank_position <= ?", n).order(:rank_position) }

  def voter_label
    "ユーザー##{voter_token.last(4)}"
  end

  # Batch refresh for a given period
  def self.refresh_weekly!
    week_key = Date.current.strftime("%G-W%V")
    week_start = Date.current.beginning_of_week
    refresh_period!(:weekly, week_key, voted_on: week_start..Date.current)
  end

  def self.refresh_monthly!
    month_key = Date.current.strftime("%Y-%m")
    month_start = Date.current.beginning_of_month
    refresh_period!(:monthly, month_key, voted_on: month_start..Date.current)
  end

  def self.refresh_all_time!
    refresh_period!(:all_time, "all", {})
  end

  private

  def self.refresh_period!(period, key, conditions)
    vote_scope = Vote.all
    vote_scope = vote_scope.where(conditions) if conditions.present?

    # National rankings
    national_counts = vote_scope.group(:voter_token).count
    save_rankings!(period, key, "national", nil, national_counts)

    # Prefecture rankings
    pref_counts = vote_scope.joins(:shop).group("shops.prefecture_id", :voter_token).count
    pref_counts.group_by { |(pref_id, _token), _count| pref_id }.each do |pref_id, entries|
      counts = entries.to_h { |(_, token), count| [ token, count ] }
      save_rankings!(period, key, "prefecture", pref_id, counts)
    end
  end

  def self.save_rankings!(period, key, scope_type, scope_id, token_counts)
    # Sort by count desc, assign rank
    sorted = token_counts.sort_by { |_token, count| -count }

    # Delete old rankings for this period/scope
    where(period_type: period, period_key: key, scope_type: scope_type, scope_id: scope_id).delete_all

    # Minimum threshold: weekly 5 votes, monthly 10, all_time 1
    min_votes = case period.to_s
    when "weekly" then 5
    when "monthly" then 10
    else 1
    end

    records = sorted.filter_map.with_index(1) do |(token, count), rank|
      next if count < min_votes
      {
        voter_token: token,
        period_type: period,
        period_key: key,
        scope_type: scope_type,
        scope_id: scope_id,
        vote_count: count,
        rank_position: rank,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    insert_all(records) if records.any?
  end
end
