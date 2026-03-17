class CreateShopReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :shop_reviews do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :voter_token, null: false
      t.integer :rating, null: false
      t.string :title
      t.text :body, null: false
      t.integer :category, default: 0, null: false
      t.string :reviewer_name, default: "名無し"

      t.timestamps
    end
    add_index :shop_reviews, :voter_token
    add_index :shop_reviews, [ :shop_id, :voter_token ], unique: true
    add_index :shop_reviews, [ :shop_id, :created_at ]
    add_index :shop_reviews, :category
  end
end
