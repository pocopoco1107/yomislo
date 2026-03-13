# frozen_string_literal: true

class CleanupMachineModelsColumns < ActiveRecord::Migration[8.0]
  def change
    remove_index :machine_models, :pworld_machine_id, if_exists: true
    remove_column :machine_models, :pworld_machine_id, :integer
    remove_column :machine_models, :trophy_rules, :jsonb, default: {}
    remove_column :machine_models, :certification_number, :string
    remove_column :machine_models, :released_on, :date
    remove_column :machine_models, :spec_type, :integer, default: 0
    remove_column :machine_models, :machine_type, :integer, default: 0
    remove_column :shops, :holidays, :string
  end
end
