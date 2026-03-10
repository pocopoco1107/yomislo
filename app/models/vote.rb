class Vote < ApplicationRecord
  CONFIRMED_SETTING_TAGS = %w[偶数確 奇数確 2以上 3以上 4以上 5以上 6確].freeze

  belongs_to :user, optional: true
  belongs_to :shop
  belongs_to :machine_model

  validates :voted_on, presence: true
  validates :voter_token, presence: true
  validates :voter_token, uniqueness: { scope: [:shop_id, :machine_model_id, :voted_on], message: "は1日1店舗1機種につき1票です" }
  validates :reset_vote, inclusion: { in: [0, 1], allow_nil: true }
  validates :setting_vote, inclusion: { in: 1..6, allow_nil: true }
  validate :at_least_one_vote
  validate :voted_on_not_future
  validate :voted_on_not_too_old
  validate :confirmed_setting_tags_valid

  attr_reader :cached_vote_summary

  after_save :update_vote_summary
  after_destroy :update_vote_summary

  private

  def at_least_one_vote
    if reset_vote.nil? && setting_vote.nil? && confirmed_setting.blank?
      errors.add(:base, "リセット投票か設定投票のどちらかは必須です")
    end
  end

  def voted_on_not_future
    if voted_on.present? && voted_on > Date.current
      errors.add(:voted_on, "は未来の日付にできません")
    end
  end

  def voted_on_not_too_old
    if voted_on.present? && voted_on < Date.current - 1
      errors.add(:voted_on, "は前日までしか投票できません")
    end
  end

  def confirmed_setting_tags_valid
    return if confirmed_setting.blank?
    invalid_tags = confirmed_setting - CONFIRMED_SETTING_TAGS
    if invalid_tags.any?
      errors.add(:confirmed_setting, "に無効なタグが含まれています: #{invalid_tags.join(', ')}")
    end
  end

  def update_vote_summary
    @cached_vote_summary = VoteSummary.refresh_for(shop_id, machine_model_id, voted_on)
  end
end
