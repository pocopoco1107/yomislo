class MachineModel < ApplicationRecord
  enum :machine_type, { slot: 0, pachislot: 1 }
  enum :spec_type, { type_at: 0, type_art: 1, type_a_plus_at: 2, type_a: 3 }

  has_many :votes, dependent: :destroy
  has_many :vote_summaries, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  def to_param
    slug
  end
end
