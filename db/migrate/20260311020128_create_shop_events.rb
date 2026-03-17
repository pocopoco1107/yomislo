class CreateShopEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :shop_events do |t|
      t.references :shop, null: false, foreign_key: true
      t.date :event_date, null: false
      t.integer :event_type, null: false, default: 0
      t.string :title, null: false
      t.text :description
      t.string :source_url
      t.string :voter_token, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :shop_events, [ :shop_id, :event_date ]
    add_index :shop_events, :status
    add_index :shop_events, :voter_token
  end
end
