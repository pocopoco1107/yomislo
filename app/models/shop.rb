class Shop < ApplicationRecord
  belongs_to :prefecture
  has_many :votes, dependent: :destroy
  has_many :vote_summaries, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  include PgSearch::Model
  pg_search_scope :search_by_name, against: :name, using: { tsearch: { prefix: true } }

  def to_param
    slug
  end
end
