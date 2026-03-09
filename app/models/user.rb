class User < ApplicationRecord
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  enum :role, { general: 0, admin: 1 }

  has_many :votes, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :reports, foreign_key: :reporter_id, dependent: :destroy

  validates :nickname, presence: true, uniqueness: true, length: { maximum: 20 }
  validates :trust_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
end
