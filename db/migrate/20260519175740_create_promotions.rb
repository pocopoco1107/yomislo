class CreatePromotions < ActiveRecord::Migration[8.1]
  def change
    create_table :promotions do |t|
      t.string  :title,        null: false
      t.string  :description
      t.string  :image_url
      t.string  :target_url,   null: false
      t.integer :category,     null: false, default: 0
      t.text    :slot_keys,    array: true, null: false, default: []
      t.integer :priority,     null: false, default: 0
      t.boolean :active,       null: false, default: true
      t.integer :clicks_count, null: false, default: 0
      t.timestamps
    end

    add_index :promotions, :slot_keys, using: "gin"
    add_index :promotions, [ :active, :priority ]
  end
end
