class Prefecture < ApplicationRecord
  has_many :shops, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
end
