class RemoveCertificationNumberFromMachineModels < ActiveRecord::Migration[8.0]
  def change
    remove_column :machine_models, :certification_number, :string
  end
end
