class Comment < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :commentable, polymorphic: true

  validates :body, presence: true, length: { maximum: 500 }
  validates :voter_token, presence: true
  validates :commenter_name, length: { maximum: 20 }, allow_blank: true

  has_many :reports, as: :reportable, dependent: :destroy

  scope :for_date, ->(date) { where(target_date: date) }
  scope :recent, -> { order(created_at: :desc) }

  def display_name
    commenter_name.presence || "名無し"
  end
end
