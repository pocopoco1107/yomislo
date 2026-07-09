class CreateMachineModelRedirects < ActiveRecord::Migration[8.1]
  def change
    create_table :machine_model_redirects do |t|
      t.string :old_slug, null: false
      t.bigint :machine_model_id, null: false
      t.timestamps
    end
    add_index :machine_model_redirects, :old_slug, unique: true
    add_index :machine_model_redirects, :machine_model_id
    add_foreign_key :machine_model_redirects, :machine_models
  end
end
