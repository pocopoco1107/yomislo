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

  include PgSearch::Model
  pg_search_scope :search_by_name, against: :name, using: { tsearch: { prefix: true } }

  def to_param
    slug
  end

  def geocode_accurate?
    geocode_precision.to_i >= 2
  end
end
