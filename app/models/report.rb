class Report < ApplicationRecord
  belongs_to :reporter, class_name: "User", optional: true
  belongs_to :reportable, polymorphic: true

  enum :reason, { spam: 0, inappropriate: 1, fake_vote: 2, other: 3 }

  validates :reason, presence: true

  scope :unresolved, -> { where(resolved: false) }
end
