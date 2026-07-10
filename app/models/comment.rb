class Comment < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :commentable, polymorphic: true

  validates :body, presence: true, length: { maximum: 500 }
  validates :voter_token, presence: true
  validates :commenter_name, length: { maximum: 20 }, allow_blank: true
  # 星評価は任意（クチコミにコメント＋任意の星を一本化）
  validates :rating, inclusion: { in: 1..5 }, allow_nil: true

  has_many :reports, as: :reportable, dependent: :destroy

  scope :for_date, ->(date) { where(target_date: date) }
  scope :recent, -> { order(created_at: :desc) }

  def display_name
    commenter_name.presence || "名無し"
  end

  # 店舗のクチコミ平均評価（星が付いたコメントのみ対象）。県ページ・レコメンドで参照。
  def self.average_rating_for_shops(shop_ids)
    where(commentable_type: "Shop", commentable_id: shop_ids)
      .where.not(rating: nil)
      .group(:commentable_id)
      .average(:rating)
      .transform_values { |v| v.to_f.round(1) }
  end
end
