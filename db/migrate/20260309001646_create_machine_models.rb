class CreateMachineModels < ActiveRecord::Migration[8.0]
  def change
    create_table :machine_models do |t|
      t.string :name, null: false
      t.string :maker
      t.integer :machine_type, default: 0
      t.integer :spec_type, default: 0
      t.string :slug, null: false
      t.date :released_on

      t.timestamps
    end

    add_index :machine_models, :slug, unique: true
  end
end
