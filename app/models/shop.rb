class Shop < ApplicationRecord
  belongs_to :prefecture
  has_many :shop_machine_models, dependent: :destroy
  has_many :machine_models, through: :shop_machine_models
  has_many :votes, dependent: :destroy
  has_many :vote_summaries, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :shop_reviews, dependent: :destroy
  has_many :shop_events, dependent: :destroy
  has_many :play_records, dependent: :destroy
  has_many :exchange_rate_reports, dependent: :destroy
  has_many :exchange_rate_summaries, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  scope :listed, -> { where(ptown_delisted_at: nil) }
  scope :delisted, -> { where.not(ptown_delisted_at: nil) }

  # 記録カレンダー・日付ページで遡れる下限。運用開始前の日付は記録が存在せず、
  # 際限なく過去へたどれるとクローラの無限クロール空間になるため範囲外として扱う。
  EARLIEST_RECORD_DATE = Date.new(2026, 1, 1)

  include PgSearch::Model
  pg_search_scope :search_by_name, against: :name, using: { tsearch: { prefix: true } }

  def to_param
    slug
  end

  def geocode_accurate?
    geocode_precision.to_i >= 2
  end

  def delisted?
    ptown_delisted_at.present?
  end
end
