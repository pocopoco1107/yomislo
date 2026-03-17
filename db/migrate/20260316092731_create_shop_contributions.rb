class CreateShopContributions < ActiveRecord::Migration[8.0]
  def change
    create_table :shop_contributions do |t|
      t.string :voter_token, null: false
      t.references :shop, null: false, foreign_key: true
      t.integer :contribution_type, default: 0, null: false
      t.string :value, null: false

      t.timestamps
    end

    add_index :shop_contributions, [ :voter_token, :shop_id, :contribution_type ], unique: true, name: "idx_shop_contributions_unique"
  end
end
