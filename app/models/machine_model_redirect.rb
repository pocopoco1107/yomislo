class MachineModelRedirect < ApplicationRecord
  belongs_to :machine_model
  validates :old_slug, presence: true, uniqueness: true
end
