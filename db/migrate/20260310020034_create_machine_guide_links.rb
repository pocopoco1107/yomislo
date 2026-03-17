class CreateMachineGuideLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :machine_guide_links do |t|
      t.references :machine_model, null: false, foreign_key: true
      t.string :url, null: false
      t.string :title
      t.string :source
      t.integer :link_type, default: 0, null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :machine_guide_links, [ :machine_model_id, :url ], unique: true
    add_index :machine_guide_links, :status
    add_index :machine_guide_links, :link_type
  end
end
