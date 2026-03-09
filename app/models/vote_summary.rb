class VoteSummary < ApplicationRecord
  belongs_to :shop
  belongs_to :machine_model

  validates :target_date, presence: true
  validates :shop_id, uniqueness: { scope: [:machine_model_id, :target_date] }

  def self.refresh_for(shop_id, machine_model_id, target_date)
    votes = Vote.where(shop_id: shop_id, machine_model_id: machine_model_id, voted_on: target_date)

    summary = find_or_initialize_by(shop_id: shop_id, machine_model_id: machine_model_id, target_date: target_date)

    reset_votes = votes.where.not(reset_vote: nil)
    setting_votes = votes.where.not(setting_vote: nil)

    summary.total_votes = votes.count
    summary.reset_yes_count = reset_votes.where(reset_vote: 1).count
    summary.reset_no_count = reset_votes.where(reset_vote: 0).count

    if setting_votes.exists?
      summary.setting_avg = setting_votes.average(:setting_vote).round(1)
      distribution = setting_votes.group(:setting_vote).count
      summary.setting_distribution = (1..6).each_with_object({}) { |i, h| h[i.to_s] = distribution[i] || 0 }
    else
      summary.setting_avg = nil
      summary.setting_distribution = {}
    end

    summary.save!
    summary
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
