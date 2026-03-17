class CreateShopRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :shop_requests do |t|
      t.string :name, null: false
      t.references :prefecture, null: false, foreign_key: true
      t.string :address
      t.string :url
      t.text :note
      t.string :voter_token, null: false
      t.integer :status, default: 0, null: false
      t.text :admin_note

      t.timestamps
    end

    add_index :shop_requests, :status
    add_index :shop_requests, :voter_token
    add_index :shop_requests, [ :prefecture_id, :name, :status ], name: "index_shop_requests_on_pref_name_status"
  end
end
