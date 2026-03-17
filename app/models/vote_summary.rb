class VoteSummary < ApplicationRecord
  belongs_to :shop
  belongs_to :machine_model

  validates :target_date, presence: true
  validates :shop_id, uniqueness: { scope: [ :machine_model_id, :target_date ] }

  def self.refresh_for(shop_id, machine_model_id, target_date)
    # Single query: load only the columns we need for aggregation
    vote_rows = Vote.where(shop_id: shop_id, machine_model_id: machine_model_id, voted_on: target_date)
                    .pluck(:reset_vote, :setting_vote, :confirmed_setting)

    # Use advisory lock to prevent race conditions on concurrent refreshes
    lock_key = [ shop_id, machine_model_id, target_date.to_s ].join("-").hash.abs % (2**31)
    transaction do
      connection.exec_query("SELECT pg_advisory_xact_lock($1)", "advisory_lock", [ lock_key ])

      summary = find_or_initialize_by(shop_id: shop_id, machine_model_id: machine_model_id, target_date: target_date)

      summary.total_votes = vote_rows.size

      # Aggregate in Ruby (1 SQL instead of 6+)
      reset_yes = 0
      reset_no = 0
      setting_sum = 0
      setting_count = 0
      distribution = Hash.new(0)
      tag_counts = Hash.new(0)

      vote_rows.each do |reset_vote, setting_vote, confirmed_tags|
        case reset_vote
        when 1 then reset_yes += 1
        when 0 then reset_no += 1
        end

        if setting_vote
          setting_sum += setting_vote
          setting_count += 1
          distribution[setting_vote] += 1
        end

        if confirmed_tags.present?
          confirmed_tags.each { |tag| tag_counts[tag] += 1 }
        end
      end

      summary.reset_yes_count = reset_yes
      summary.reset_no_count = reset_no

      if setting_count > 0
        summary.setting_avg = (setting_sum.to_f / setting_count).round(1)
        summary.setting_distribution = (1..6).each_with_object({}) { |i, h| h[i.to_s] = distribution[i] }
      else
        summary.setting_avg = nil
        summary.setting_distribution = {}
      end

      summary.confirmed_setting_counts = tag_counts.presence || {}

      summary.save!
      summary
    end
  end

  def reset_rate
    total_reset = reset_yes_count + reset_no_count
    return nil if total_reset.zero?
    (reset_yes_count.to_f / total_reset * 100).round(0)
  end

  def enough_data?
    total_votes >= 3
  end
end
