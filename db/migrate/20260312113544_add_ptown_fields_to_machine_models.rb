class AddPtownFieldsToMachineModels < ActiveRecord::Migration[8.0]
  def change
    add_column :machine_models, :certification_number, :string
    add_column :machine_models, :ptown_id, :integer
    add_index :machine_models, :ptown_id, unique: true, where: "ptown_id IS NOT NULL"
  end
end
