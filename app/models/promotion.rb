class Promotion < ApplicationRecord
  enum :category, {
    point_site: 0,
    credit_card: 1,
    securities: 2,
    vod: 3,
    other: 99
  }

  SLOT_KEYS = %w[
    home_hero
    home_zone_split
    shop_detail_top
    shop_detail_bottom
    machine_detail
    voter_status
    rankings_top
  ].freeze

  CATEGORY_LABELS = {
    "point_site"  => "ポイ活",
    "credit_card" => "クレジットカード",
    "securities"  => "証券・投資",
    "vod"         => "動画配信",
    "other"       => "その他"
  }.freeze

  validates :title,      presence: true, length: { maximum: 60 }
  validates :description, length: { maximum: 120 }, allow_blank: true
  validates :target_url, presence: true
  validate  :target_url_must_be_url_or_placeholder
  validates :category,   presence: true
  validates :priority,   numericality: { greater_than_or_equal_to: 0 }
  validate  :slot_keys_must_be_known

  scope :active,      -> { where(active: true) }
  scope :for_slot,    ->(key) { where("? = ANY(slot_keys)", key.to_s) }
  scope :prioritized, -> { order(priority: :desc, id: :asc) }

  def category_label
    CATEGORY_LABELS[category] || category
  end

  def increment_clicks!
    increment!(:clicks_count)
  end

  private

  def target_url_must_be_url_or_placeholder
    return if target_url.blank?
    return if target_url == "#"
    return if target_url =~ %r{\Ahttps?://}

    errors.add(:target_url, "は http(s):// で始まるURL、または '#'（プレースホルダー）にしてください")
  end

  def slot_keys_must_be_known
    if slot_keys.blank?
      errors.add(:slot_keys, "少なくとも1つ選択してください")
      return
    end

    unknown = slot_keys - SLOT_KEYS
    errors.add(:slot_keys, "未定義のスロット: #{unknown.join(', ')}") if unknown.any?
  end
end
