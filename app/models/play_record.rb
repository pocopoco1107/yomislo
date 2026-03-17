class PlayRecord < ApplicationRecord
  VALID_TAGS = %w[ロングフリーズ 有利区間リセ 天井 朝一 設定変更 据え置き 高設定確定 万枚].freeze

  belongs_to :shop
  belongs_to :machine_model, optional: true

  validates :voter_token, presence: true
  validates :played_on, presence: true
  validates :result_amount, presence: true,
            numericality: { greater_than_or_equal_to: -999_999, less_than_or_equal_to: 999_999 }
  validates :investment, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 999_999 }, allow_nil: true
  validates :payout, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 9_999_999 }, allow_nil: true
  validates :memo, length: { maximum: 500 }
  validates :voter_token, uniqueness: { scope: [ :shop_id, :machine_model_id, :played_on ],
                                         message: "同店舗同機種同日の記録は1件までです" }
  validate :played_on_within_range
  validate :tags_valid

  after_commit :enqueue_summary_refresh, on: [ :create, :update, :destroy ],
               if: -> { is_public? || previous_changes.key?("is_public") }

  scope :public_records, -> { where(is_public: true) }
  scope :by_month, ->(date) { where(played_on: date.beginning_of_month..date.end_of_month) }

  def win?
    result_amount > 0
  end

  def lose?
    result_amount < 0
  end

  private

  def enqueue_summary_refresh
    RefreshPlayRecordSummaryJob.perform_later(id)
  end

  def played_on_within_range
    return if played_on.blank?
    if played_on > Date.current
      errors.add(:played_on, "は未来の日付にできません")
    elsif played_on < 90.days.ago.to_date
      errors.add(:played_on, "は過去90日以内のみ記録できます")
    end
  end

  def tags_valid
    return if tags.blank?
    invalid = tags - VALID_TAGS
    if invalid.any?
      errors.add(:tags, "に無効なタグがあります: #{invalid.join(', ')}")
    end
  end
end
