module TrendData
  extend ActiveSupport::Concern

  private

  # Build trend data for a given VoteSummary scope.
  # period: :week (7 days), :month (30 days), :all (全期間)
  # Returns an array of hashes: [{ date:, votes:, reset_rate:, setting_avg: }, ...]
  # Days with no data are filled with zeros/nils.
  def build_trend_data(scope, days: 7)
    end_date = Date.current
    start_date = end_date - (days - 1)
    date_range = (start_date..end_date).to_a

    aggregate_trend_rows(scope, start_date, end_date, date_range)
  end

  # Build trend data for a specific period
  # period: "7", "30", "all"
  def build_trend_data_for_period(scope, period)
    end_date = Date.current

    case period
    when "30"
      start_date = end_date - 29
    when "all"
      # Find earliest data date, fallback to 90 days ago
      earliest = scope.minimum(:target_date)
      start_date = earliest || (end_date - 89)
    else
      start_date = end_date - 6
    end

    date_range = (start_date..end_date).to_a
    aggregate_trend_rows(scope, start_date, end_date, date_range)
  end

  # Build weekly summary for a shop
  # Returns: { total_votes:, top_reset_machines:, top_setting_machines:, prev_week_votes:, vote_change: }
  def build_weekly_summary(shop)
    today = Date.current
    week_start = today.beginning_of_week(:monday)
    week_end = today
    prev_week_start = week_start - 7
    prev_week_end = week_start - 1

    # This week's total votes
    this_week_votes = shop.vote_summaries
                          .where(target_date: week_start..week_end)
                          .sum(:total_votes)

    # Previous week's total votes
    prev_week_votes = shop.vote_summaries
                          .where(target_date: prev_week_start..prev_week_end)
                          .sum(:total_votes)

    # Top 3 machines by reset rate this week
    top_reset = shop.vote_summaries
                    .where(target_date: week_start..week_end)
                    .where("reset_yes_count + reset_no_count >= 1")
                    .select(
                      "machine_model_id",
                      "SUM(reset_yes_count) as total_yes",
                      "SUM(reset_yes_count + reset_no_count) as total_reset"
                    )
                    .group(:machine_model_id)
                    .having("SUM(reset_yes_count + reset_no_count) >= 1")
                    .order(Arel.sql("SUM(reset_yes_count)::float / NULLIF(SUM(reset_yes_count + reset_no_count), 0) DESC"))
                    .limit(3)

    # Top 3 machines by setting average this week
    top_setting = shop.vote_summaries
                      .where(target_date: week_start..week_end)
                      .where("setting_avg IS NOT NULL AND total_votes >= 1")
                      .select(
                        "machine_model_id",
                        "SUM(setting_avg * total_votes) / NULLIF(SUM(total_votes), 0) as weighted_avg",
                        "SUM(total_votes) as total_v"
                      )
                      .group(:machine_model_id)
                      .having("SUM(total_votes) >= 1")
                      .order(Arel.sql("SUM(setting_avg * total_votes) / NULLIF(SUM(total_votes), 0) DESC"))
                      .limit(3)

    # Preload machines for both top_reset and top_setting in a single query
    all_machine_ids = (top_reset.map(&:machine_model_id) + top_setting.map(&:machine_model_id)).uniq
    machines_by_id = MachineModel.where(id: all_machine_ids).select(:id, :name).index_by(&:id)

    top_reset_machines = top_reset.filter_map do |row|
      machine = machines_by_id[row.machine_model_id]
      next unless machine
      rate = (row.total_yes.to_f / row.total_reset * 100).round(0)
      { name: machine.name, rate: rate }
    end

    top_setting_machines = top_setting.filter_map do |row|
      machine = machines_by_id[row.machine_model_id]
      next unless machine
      { name: machine.name, avg: row.weighted_avg.to_f.round(1) }
    end

    vote_change = this_week_votes - prev_week_votes

    {
      total_votes: this_week_votes,
      prev_week_votes: prev_week_votes,
      vote_change: vote_change,
      top_reset_machines: top_reset_machines,
      top_setting_machines: top_setting_machines
    }
  end

  def aggregate_trend_rows(scope, start_date, end_date, date_range)
    rows = scope
      .where(target_date: start_date..end_date)
      .group(:target_date)
      .pluck(
        Arel.sql("target_date"),
        Arel.sql("COALESCE(SUM(total_votes), 0)"),
        Arel.sql("COALESCE(SUM(reset_yes_count), 0)"),
        Arel.sql("COALESCE(SUM(reset_no_count), 0)"),
        Arel.sql("COALESCE(SUM(CASE WHEN total_votes > 0 AND setting_avg IS NOT NULL THEN setting_avg * total_votes ELSE 0 END), 0)"),
        Arel.sql("COALESCE(SUM(CASE WHEN total_votes > 0 AND setting_avg IS NOT NULL THEN total_votes ELSE 0 END), 0)")
      )

    by_date = rows.each_with_object({}) do |row, h|
      date = row[0]
      total_votes = row[1].to_i
      reset_yes = row[2].to_i
      reset_no = row[3].to_i
      total_reset = reset_yes + reset_no
      weighted_sum = row[4].to_f
      weighted_count = row[5].to_i

      h[date] = {
        votes: total_votes,
        reset_rate: total_reset >= 1 ? (reset_yes.to_f / total_reset * 100).round(1) : nil,
        setting_avg: weighted_count > 0 ? (weighted_sum / weighted_count).round(1) : nil
      }
    end

    date_range.map do |date|
      data = by_date[date] || { votes: 0, reset_rate: nil, setting_avg: nil }
      { date: date }.merge(data)
    end
  end
end
