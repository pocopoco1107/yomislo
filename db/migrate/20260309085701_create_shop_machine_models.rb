class CreateShopMachineModels < ActiveRecord::Migration[8.0]
  def change
    create_table :shop_machine_models do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :machine_model, null: false, foreign_key: true

      t.timestamps
    end

    add_index :shop_machine_models, [ :shop_id, :machine_model_id ], unique: true
  end
end
