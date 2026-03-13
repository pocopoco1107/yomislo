class SnsReport < ApplicationRecord
  belongs_to :machine_model
  belongs_to :shop, optional: true

  enum :status, { pending: 0, approved: 1, rejected: 2 }
  enum :confidence, { unrated: 0, low: 1, medium: 2, high: 3 }, prefix: :confidence

  validates :source, presence: true, inclusion: { in: %w[rss google_cse manual twitter] }
  validates :raw_text, presence: true
  validates :source_url, uniqueness: true, allow_blank: true

  scope :recent, -> { order(created_at: :desc) }
  scope :unparsed, -> { where(structured_data: {}) }
  scope :for_machine, ->(machine_model_id) { where(machine_model_id: machine_model_id) }
  scope :by_source, ->(source) { where(source: source) }
end
