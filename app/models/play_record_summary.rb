class PlayRecordSummary < ApplicationRecord
  enum :period_type, { monthly: 0, all_time: 1 }

  validates :scope_type, presence: true, inclusion: { in: %w[machine_model shop prefecture] }
  validates :scope_id, presence: true
  validates :period_key, presence: true
  validates :scope_type, uniqueness: { scope: [ :scope_id, :period_type, :period_key ] }

  # Only aggregate public records with reasonable amounts
  AGGREGATION_SCOPE = -> { PlayRecord.where(is_public: true).where("ABS(result_amount) <= 500000") }

  def self.refresh_for_machine_model!(machine_model_id, period_key: nil)
    refresh_scope!("machine_model", machine_model_id, period_key)
  end

  def self.refresh_for_shop!(shop_id, period_key: nil)
    refresh_scope!("shop", shop_id, period_key)
  end

  def self.refresh_for_prefecture!(prefecture_id, period_key: nil)
    refresh_scope!("prefecture", prefecture_id, period_key)
  end

  def self.refresh_all!
    # Monthly for current month
    month_key = Date.current.strftime("%Y-%m")

    # Machine models
    MachineModel.active.find_each do |mm|
      refresh_scope!("machine_model", mm.id, month_key)
      refresh_scope!("machine_model", mm.id, "all")
    end

    # Shops that have play records
    PlayRecord.where(is_public: true).distinct.pluck(:shop_id).each do |shop_id|
      refresh_scope!("shop", shop_id, month_key)
      refresh_scope!("shop", shop_id, "all")
    end

    # Prefectures
    Prefecture.find_each do |pref|
      refresh_scope!("prefecture", pref.id, month_key)
      refresh_scope!("prefecture", pref.id, "all")
    end
  end

  private

  def self.refresh_scope!(scope_type, scope_id, period_key)
    base = AGGREGATION_SCOPE.call

    records = case scope_type
    when "machine_model"
                base.where(machine_model_id: scope_id)
    when "shop"
                base.where(shop_id: scope_id)
    when "prefecture"
                base.joins(:shop).where(shops: { prefecture_id: scope_id })
    end

    if period_key && period_key != "all"
      date = Date.parse("#{period_key}-01")
      records = records.where(played_on: date.beginning_of_month..date.end_of_month)
      pt = :monthly
    else
      period_key = "all"
      pt = :all_time
    end

    stats = records.pluck(:result_amount, :played_on)

    summary = find_or_initialize_by(scope_type: scope_type, scope_id: scope_id, period_type: pt, period_key: period_key)

    if stats.empty?
      summary.assign_attributes(total_records: 0, total_result: 0, avg_result: 0,
                                 win_count: 0, lose_count: 0, win_rate: 0.0, weekday_stats: {})
    else
      amounts = stats.map(&:first)
      wins = amounts.count { |a| a > 0 }
      losses = amounts.count { |a| a < 0 }
      total = amounts.sum

      # Weekday stats: { "0" => { count: N, total: N, avg: N }, ... }  (0=Sun ... 6=Sat)
      by_wday = stats.group_by { |_, date| date.wday }
      wday_stats = (0..6).each_with_object({}) do |wday, h|
        entries = by_wday[wday] || []
        next if entries.empty?
        wday_amounts = entries.map(&:first)
        h[wday.to_s] = {
          count: entries.size,
          total: wday_amounts.sum,
          avg: (wday_amounts.sum.to_f / entries.size).round(0)
        }
      end

      summary.assign_attributes(
        total_records: stats.size,
        total_result: total,
        avg_result: (total.to_f / stats.size).round(0),
        win_count: wins,
        lose_count: losses,
        win_rate: ((wins.to_f / (wins + losses)) * 100).round(1),
        weekday_stats: wday_stats
      )
    end

    summary.save!
    summary
  end
end
